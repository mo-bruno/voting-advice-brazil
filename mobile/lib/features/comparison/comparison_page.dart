import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/api/api_client.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/link/link_opener.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/candidate_result.dart';
import '../../shared/models/thesis.dart';
import '../../shared/quiz_session.dart';
import '../../shared/widgets/candidate_logo.dart';

class ComparisonPage extends StatefulWidget {
  const ComparisonPage({
    super.key,
    this.session,
    this.analytics,
    this.openLink,
  });

  final QuizSession? session;
  final AnalyticsService? analytics;
  final LinkOpener? openLink;

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  late final QuizSession _session = widget.session ?? QuizSession.instance;
  final Set<String> _selectedCandidateIds = {};
  final Map<String, Map<int, CandidateJustification>> _justifications = {};
  bool _showComparison = false;
  bool _isLoadingJustifications = false;
  bool _comparisonOutdated = false;
  int _comparisonRequest = 0;
  int? _expandedThesisId;

  List<CandidateResult> get _results => [..._session.visibleResults]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<CandidateResult> get _selectedResults => _results
      .where((result) => _selectedCandidateIds.contains(result.candidateId))
      .toList();

  @override
  void initState() {
    super.initState();
    if (_results.isNotEmpty) {
      _selectedCandidateIds.add(_results.first.candidateId);
    }
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  void _handleBack() {
    if (_showComparison || _comparisonOutdated) {
      _comparisonRequest++;
      setState(() {
        _showComparison = false;
        _comparisonOutdated = false;
      });
      return;
    }
    Navigator.pop(context);
  }

  void _toggleCandidate(String candidateId) {
    var candidateAdded = false;
    var position = 0;
    setState(() {
      if (_selectedCandidateIds.contains(candidateId)) {
        _selectedCandidateIds.remove(candidateId);
      } else {
        if (_selectedCandidateIds.length >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Escolha no maximo 2 candidatos para comparar.'),
            ),
          );
          return;
        }
        _selectedCandidateIds.add(candidateId);
        candidateAdded = true;
        position = _selectedCandidateIds.length;
      }
    });
    if (candidateAdded) {
      _track(
        _analytics.comparisonCandidateAdded(
          candidateId: candidateId,
          position: position,
        ),
      );
    }
  }

  Future<void> _startComparison() async {
    _track(_analytics.comparisonOpened());
    final request = ++_comparisonRequest;
    final selected = List<CandidateResult>.of(_selectedResults);
    setState(() {
      _showComparison = true;
      _isLoadingJustifications = true;
      _comparisonOutdated = false;
      _justifications.clear();
    });

    try {
      final validated = <String, Map<int, CandidateJustification>>{};
      for (final result in selected) {
        _track(
          _analytics.candidatePositionsViewed(candidateId: result.candidateId),
        );
        final data = await _session.api.fetchCandidateJustifications(
          result.candidateId,
        );
        if (!mounted || request != _comparisonRequest) return;
        final byThesis = {for (final item in data) item.thesisId: item};
        final changed = result.matches.any((match) {
          final item = byThesis[match.thesisId];
          return item == null ||
              item.thesisText != match.thesisText ||
              item.position != match.candidatePosition ||
              item.analyticalPosition != match.candidateAnalysis;
        });
        if (changed) {
          setState(() => _comparisonOutdated = true);
          return;
        }
        validated[result.candidateId] = byThesis;
      }
      if (mounted && request == _comparisonRequest) {
        setState(() => _justifications.addAll(validated));
      }
    } catch (error) {
      if (mounted && request == _comparisonRequest) {
        if (error is ApiException && error.statusCode == 404) {
          setState(() => _comparisonOutdated = true);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    } finally {
      if (mounted && request == _comparisonRequest) {
        setState(() => _isLoadingJustifications = false);
      }
    }
  }

  Widget _outdatedComparison(TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A comparação precisa ser atualizada.',
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'As perguntas, posições ou candidaturas mudaram desde este resultado. Recalcule para consultar evidências compatíveis. Você também pode começar um novo quiz.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/party-selection'),
            child: const Text('RECALCULAR RESULTADO'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _session.resetQuiz();
              _session.markQuizStarted();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/quiz',
                (route) => route.isFirst,
              );
            },
            child: const Text('REFAZER QUIZ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'FAROL POLÍTICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBack,
      ),
      body: _results.isEmpty
          ? _emptyState(textTheme)
          : _comparisonOutdated
              ? _outdatedComparison(textTheme)
              : _showComparison
                  ? _comparisonView(textTheme)
                  : _selectionView(textTheme),
    );
  }

  Widget _emptyState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Calcule o resultado antes de comparar respostas.',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _selectionView(TextTheme textTheme) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text('ESCOLHA A\nCOMPARACAO', style: textTheme.displayMedium),
                  const SizedBox(height: 16),
                  Text(
                    'Selecione os candidatos que você quer comparar com suas respostas.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ..._results.map(
                    (result) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CandidateSelectionCard(
                        result: result,
                        isSelected: _selectedCandidateIds.contains(
                          result.candidateId,
                        ),
                        onTap: () => _toggleCandidate(result.candidateId),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _selectedCandidateIds.isEmpty ? null : _startComparison,
              child: const Text('COMPARAR RESPOSTAS'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _comparisonView(TextTheme textTheme) {
    final selected = _selectedResults;
    final matches = selected.first.matches;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('COMPARAÇÃO\nDE RESPOSTAS', style: textTheme.displayMedium),
            const SizedBox(height: 16),
            Text(
              'Toque em uma pergunta para ver a justificativa e a fonte. “±” indica uma posição condicional ou mista, que fica fora do cálculo. “?” indica ausência de evidência suficiente.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...selected.map(
              (result) => Text(
                '${result.name}: ${result.coverageLabel}.',
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoadingJustifications)
              const LinearProgressIndicator(minHeight: 2),
            _ComparisonHeader(selectedResults: selected),
            const SizedBox(height: 4),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matches.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppTheme.outlineVariant, height: 1),
              itemBuilder: (context, index) {
                final match = matches[index];
                return _ComparisonRow(
                  index: index + 1,
                  thesisId: match.thesisId,
                  thesisText: match.thesisText,
                  userAnswer: match.userAnswerEnum,
                  selectedResults: selected,
                  isExpanded: _expandedThesisId == match.thesisId,
                  justifications: _justifications,
                  isLoadingJustifications: _isLoadingJustifications,
                  openLink: widget.openLink ?? openExternalLink,
                  onTap: () {
                    setState(() {
                      _expandedThesisId = _expandedThesisId == match.thesisId
                          ? null
                          : match.thesisId;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CandidateSelectionCard extends StatelessWidget {
  final CandidateResult result;
  final bool isSelected;
  final VoidCallback onTap;

  const _CandidateSelectionCard({
    required this.result,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CandidateLogo(result: result, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${result.abbreviation} - ${result.affinityLabel}',
                    style: textTheme.bodySmall,
                  ),
                  Text(result.coverageLabel, style: textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonHeader extends StatelessWidget {
  final List<CandidateResult> selectedResults;

  const _ComparisonHeader({required this.selectedResults});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppTheme.surfaceContainer,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('TESE', style: textTheme.labelSmall)),
          SizedBox(
            width: 46,
            child: Text(
              'VOCÊ',
              style: textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
          ...selectedResults.map(
            (result) => SizedBox(
              width: 46,
              child: Tooltip(
                message: result.name,
                child: Column(
                  children: [
                    CandidateLogo(result: result, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      result.abbreviation,
                      style: textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final int index;
  final int thesisId;
  final String thesisText;
  final ThesisAnswer userAnswer;
  final List<CandidateResult> selectedResults;
  final bool isExpanded;
  final Map<String, Map<int, CandidateJustification>> justifications;
  final bool isLoadingJustifications;
  final LinkOpener openLink;
  final VoidCallback onTap;

  const _ComparisonRow({
    required this.index,
    required this.thesisId,
    required this.thesisText,
    required this.userAnswer,
    required this.selectedResults,
    required this.isExpanded,
    required this.justifications,
    required this.isLoadingJustifications,
    required this.openLink,
    required this.onTap,
  });

  ThesisMatch _candidateMatch(CandidateResult result) {
    return result.matches.firstWhere(
      (item) => item.thesisId == thesisId,
      orElse: () => ThesisMatch(
        thesisId: thesisId,
        thesisText: thesisText,
        themeId: 0,
        userAnswer: 'skip',
        candidatePosition: 'sem_posicao',
        matchType: 'skipped',
      ),
    );
  }

  Widget _buildIndicator(
    ThesisAnswer answer, {
    bool isUser = false,
    String? analyticalPosition,
  }) {
    IconData icon;
    Color color;
    String label;
    switch (answer) {
      case ThesisAnswer.agree:
        icon = Icons.check;
        color = AppTheme.secondary;
        label = 'Concorda';
        break;
      case ThesisAnswer.disagree:
        icon = Icons.close;
        color = AppTheme.error;
        label = 'Discorda';
        break;
      case ThesisAnswer.neutral:
        icon = Icons.remove;
        color = AppTheme.onSurfaceVariant;
        label = 'Neutro';
        break;
      default:
        if (!isUser && analyticalPosition == 'CONDICIONAL_OU_MISTA') {
          icon = Icons.call_split;
          color = AppTheme.primary;
          label = 'Posição condicional ou mista';
        } else {
          icon = Icons.help_outline;
          color = AppTheme.onSurfaceVariant;
          label = isUser ? 'Pergunta pulada' : 'Sem evidência suficiente';
        }
    }

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    '$index. ${thesisText.toUpperCase()}',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Center(
                    child: _buildIndicator(userAnswer, isUser: true),
                  ),
                ),
                ...selectedResults.map(
                  (result) {
                    final match = _candidateMatch(result);
                    return SizedBox(
                      width: 46,
                      child: Center(
                        child: _buildIndicator(
                          match.candidateAnswerEnum,
                          analyticalPosition: match.candidateAnalysis,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _JustificationPanel(
              thesisId: thesisId,
              selectedResults: selectedResults,
              justifications: justifications,
              isLoading: isLoadingJustifications,
              openLink: openLink,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
          ),
        ],
      ),
    );
  }
}

class _JustificationPanel extends StatelessWidget {
  final int thesisId;
  final List<CandidateResult> selectedResults;
  final Map<String, Map<int, CandidateJustification>> justifications;
  final bool isLoading;
  final LinkOpener openLink;

  const _JustificationPanel({
    required this.thesisId,
    required this.selectedResults,
    required this.justifications,
    required this.isLoading,
    required this.openLink,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JUSTIFICATIVAS', style: textTheme.labelSmall),
          const SizedBox(height: 10),
          ...selectedResults.map((result) {
            final item = justifications[result.candidateId]?[thesisId];
            final sourceUri = Uri.tryParse(item?.sourceUrl ?? '');
            final canOpenSource = sourceUri != null &&
                sourceUri.hasAuthority &&
                const ['http', 'https'].contains(sourceUri.scheme);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.name, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    item?.justification ??
                        (isLoading
                            ? 'Carregando justificativa…'
                            : 'Justificativa indisponível. Volte e tente abrir a comparação novamente.'),
                    style: textTheme.bodySmall,
                  ),
                  if (item?.quote?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Trecho do plano: “${item!.quote}”',
                      style: textTheme.bodySmall,
                    ),
                  ],
                  if (item?.sourceRef?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Referência: ${item!.sourceRef}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                  if (canOpenSource)
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('ABRIR FONTE OFICIAL'),
                      onPressed: () async {
                        var opened = false;
                        try {
                          opened = await openLink(sourceUri);
                        } catch (_) {
                          opened = false;
                        }
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Não foi possível abrir a fonte.'),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
