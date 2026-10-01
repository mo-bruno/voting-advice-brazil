import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/party.dart';
import '../../shared/quiz_session.dart';
import '../../shared/widgets/candidate_logo.dart';
import '../quiz/quiz_processing_notice.dart';

class PartySelectionPage extends StatefulWidget {
  const PartySelectionPage({super.key, this.session, this.analytics});

  final QuizSession? session;
  final AnalyticsService? analytics;

  @override
  State<PartySelectionPage> createState() => _PartySelectionPageState();
}

class _PartySelectionPageState extends State<PartySelectionPage> {
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  late final QuizSession _session = widget.session ?? QuizSession.instance;
  bool _allSelected = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadErrorMessage;
  ApiException? _submitError;
  String? _expandedPartyId;
  bool _abandonmentRecorded = false;
  bool _stageCompleted = false;
  late final bool _enteredAfterResults;

  List<Party> get _parties => _session.candidates;
  Set<String> get _selected => _session.selectedCandidateIds;

  @override
  void initState() {
    super.initState();
    _enteredAfterResults = _session.results.isNotEmpty;
    _track(_analytics.partySelectionViewed());
    _loadCandidates();
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  Future<void> _loadCandidates({
    bool force = false,
    AnalyticsTrigger trigger = AnalyticsTrigger.initial,
    AnalyticsService? analytics,
  }) async {
    final attemptAnalytics = analytics ?? _analytics.bindToCurrentConsent();
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? itemCount;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadErrorMessage = null;
      });
    }
    try {
      await _session.loadCandidates(force: force);
      _selected.retainAll(_parties.map((candidate) => candidate.id));
      if (!_parties.any((candidate) => candidate.id == _expandedPartyId)) {
        _expandedPartyId = null;
      }
      _allSelected = _selected.length == _parties.length && _parties.isNotEmpty;
      itemCount = _parties.length;
      outcome =
          _parties.isEmpty ? AnalyticsOutcome.empty : AnalyticsOutcome.success;
    } catch (error) {
      _loadErrorMessage = error.toString();
      failureType = classifyAnalyticsFailure(error);
    } finally {
      stopwatch.stop();
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.candidateLoad,
        outcome: outcome,
        trigger: trigger,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: itemCount,
      ));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recordAbandonment(
    AnalyticsAbandonReason reason, {
    AnalyticsService? analytics,
  }) {
    if (_abandonmentRecorded || _stageCompleted || _enteredAfterResults) {
      return;
    }
    _abandonmentRecorded = true;
    _track((analytics ?? _analytics).quizAbandoned(
      stage: AnalyticsQuizStage.candidateSelection,
      reason: reason,
      totalAnswered: _session.totalAnswered,
      totalSkipped: _session.totalSkipped,
      durationMs: _session.quizDurationMs(),
    ));
  }

  void _backToWeighting() {
    _recordAbandonment(AnalyticsAbandonReason.back);
    Navigator.pop(context);
  }

  void _toggleAll() {
    setState(() {
      _allSelected = !_allSelected;
      if (_allSelected) {
        _selected.addAll(_parties.map((p) => p.id));
      } else {
        _selected.clear();
      }
    });
  }

  void _toggleParty(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        _allSelected = false;
      } else {
        _selected.add(id);
        _allSelected = _selected.length == _parties.length;
      }
      _expandedPartyId = id;
    });
    _track(_analytics.partyToggled());
  }

  Future<void> _submitAndNavigate() async {
    if (_isSubmitting) return;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final stopwatch = Stopwatch()..start();
    if (!_session.canSubmit) {
      setState(
        () => _submitError = const ApiException(
          'Responda pelo menos 5 perguntas para calcular o resultado.',
          code: 'insufficient_answers',
        ),
      );
      stopwatch.stop();
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.resultsSubmit,
        outcome: AnalyticsOutcome.blocked,
        trigger: AnalyticsTrigger.submit,
        failureType: AnalyticsFailureType.client,
        durationMs: stopwatch.elapsedMilliseconds,
      ));
      return;
    }
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? resultCount;
    var shouldNavigate = false;
    try {
      await _session.submit();
      resultCount = _session.results.length;
      if (!mounted) {
        outcome = AnalyticsOutcome.stale;
        return;
      }
      final availableIds =
          _session.results.map((result) => result.candidateId).toSet();
      if (_selected.difference(availableIds).isNotEmpty) {
        outcome = AnalyticsOutcome.stale;
        _recordAbandonment(
          AnalyticsAbandonReason.recovery,
          analytics: attemptAnalytics,
        );
        _selected.retainAll(availableIds);
        _session.results = [];
        _session.candidates = [];
        _expandedPartyId = null;
        await _loadCandidates(
          force: true,
          trigger: AnalyticsTrigger.refresh,
          analytics: attemptAnalytics,
        );
        if (mounted) {
          setState(
            () => _submitError = const ApiException(
              'A lista de candidaturas foi atualizada. Revise sua seleção para calcular o resultado.',
              code: 'candidates_updated',
            ),
          );
        }
        return;
      }
      outcome = AnalyticsOutcome.success;
      _stageCompleted = true;
      _track(
        attemptAnalytics.partySelectionCompleted(
          countSelected: _selected.length,
        ),
      );
      shouldNavigate = true;
    } catch (error) {
      if (error is ApiException && error.code == 'invalid_thesis_ids') {
        outcome = AnalyticsOutcome.stale;
      } else {
        failureType = classifyAnalyticsFailure(error);
      }
      if (mounted) {
        setState(
          () => _submitError =
              error is ApiException ? error : ApiException(error.toString()),
        );
      }
    } finally {
      stopwatch.stop();
      _track(attemptAnalytics.operationResult(
        operation: AnalyticsOperation.resultsSubmit,
        outcome: outcome,
        trigger: AnalyticsTrigger.submit,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: resultCount,
      ));
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (shouldNavigate && mounted) Navigator.pushNamed(context, '/results');
  }

  void _restartQuiz() {
    _recordAbandonment(AnalyticsAbandonReason.restart);
    _track(_analytics.quizRestarted());
    _session.resetQuiz();
    _session.markQuizStarted();
    _track(_analytics.quizStarted());
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/quiz',
      (route) => route.isFirst,
    );
  }

  Widget _submissionError(TextTheme textTheme) {
    final error = _submitError!;
    final outdated = error.code == 'invalid_thesis_ids';
    final insufficient = error.code == 'insufficient_answers';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outdated
                ? 'As perguntas foram atualizadas. Refaça o quiz para comparar as candidaturas da edição atual.'
                : error.code == 'candidates_updated'
                    ? error.message
                    : 'Não foi possível calcular o resultado. ${error.message}',
            style: textTheme.bodyMedium,
          ),
          if (outdated || insufficient)
            TextButton(
              onPressed: outdated ? _restartQuiz : _backToWeighting,
              child: Text(outdated ? 'REFAZER QUIZ' : 'REVISAR RESPOSTAS'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _recordAbandonment(AnalyticsAbandonReason.back);
      },
      child: AppScaffold(
        title: 'FAROL POLÍTICO',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar à ponderação',
          onPressed: _backToWeighting,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(child: _buildBody(Theme.of(context).textTheme)),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * .55),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_submitError != null)
                          _submissionError(Theme.of(context).textTheme),
                        const QuizProcessingNotice(),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _selected.isNotEmpty &&
                                  !_isSubmitting &&
                                  _submitError?.code != 'invalid_thesis_ids'
                              ? _submitAndNavigate
                              : null,
                          child: Text(
                            _isSubmitting ? 'CALCULANDO...' : 'VER RESULTADOS',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_loadErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Não foi possível carregar os candidatos.',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _loadErrorMessage!,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _loadCandidates(
                  force: true,
                  trigger: AnalyticsTrigger.retry,
                ),
                child: const Text('TENTAR NOVAMENTE'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('ESCOLHA OS\nCANDIDATOS', style: textTheme.displayMedium),
            const SizedBox(height: 16),
            Text(
              'Selecione os candidatos que você deseja comparar com suas respostas.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _SelectAllButton(isSelected: _allSelected, onTap: _toggleAll),
            const SizedBox(height: 24),
            _PartyGrid(
              parties: _parties,
              selected: _selected,
              onToggle: _toggleParty,
            ),
            const SizedBox(height: 24),
            if (_expandedPartyId != null)
              _PartyDetailCard(
                party: _parties.firstWhere((p) => p.id == _expandedPartyId),
              ),
            if (_expandedPartyId == null && _selected.isNotEmpty)
              _PartyDetailCard(
                party: _parties.firstWhere((p) => _selected.contains(p.id)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SelectAllButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectAllButton({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceContainer,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? AppTheme.background : AppTheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SELECIONAR TODOS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppTheme.background : AppTheme.onSurface,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyGrid extends StatelessWidget {
  final List<Party> parties;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _PartyGrid({
    required this.parties,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: parties.map((party) {
        final isSelected = selected.contains(party.id);
        return GestureDetector(
          onTap: () => onToggle(party.id),
          child: Container(
            width: 104,
            height: 128,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.surfaceContainerHigh
                  : AppTheme.surfaceContainer,
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  CandidatePortrait(
                    photoUrl: party.photoUrl,
                    candidateName: party.name,
                    abbreviation: party.abbreviation,
                    logoAsset: party.logoAsset,
                    hasLogoAsset: party.hasLogoAsset,
                    size: 72,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      party.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PartyDetailCard extends StatelessWidget {
  final Party party;

  const _PartyDetailCard({required this.party});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${party.name.toUpperCase()} • ${party.abbreviation}',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(party.description, style: textTheme.bodyMedium),
          if (party.officialStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              'Situação no TSE: ${party.officialStatus}',
              style: textTheme.bodySmall,
            ),
          ],
          if (party.sourceSnapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Retrato dos dados: ${party.sourceSnapshot}',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
