import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/shell/main_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/candidate_result.dart';
import '../../shared/quiz_session.dart';
import '../../shared/widgets/candidate_logo.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, this.analytics});

  final AnalyticsService? analytics;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  final QuizSession _session = QuizSession.instance;
  bool _hasTrackedResultsViewed = false;

  List<CandidateResult> get _results => [..._session.visibleResults]
    ..sort((a, b) {
      if (a.hasComparableEvidence != b.hasComparableEvidence) {
        return a.hasComparableEvidence ? -1 : 1;
      }
      final byScore = b.scorePercent.compareTo(a.scorePercent);
      return byScore != 0
          ? byScore
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  /// Sair da tela nao descarta mais o teste. Este botao ja foi "REFAZER QUIZ" e
  /// chamava `resetQuiz()` para poder navegar — quem so queria sair da tela
  /// perdia o resultado junto. O descarte mudou para a QuizIntroPage, onde ele
  /// significa alguma coisa: comecar outro quiz.
  ///
  /// `pushNamedAndRemoveUntil` e nao `popUntil` porque so ele escolhe a aba de
  /// destino, e o pedido e voltar ao Inicio — nao a aba de onde se veio.
  void _backToHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
      arguments: MainShellTab.inicio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'FAROL POLÍTICO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/party-selection');
        },
      ),
      body: _results.isEmpty ? _emptyState(context) : _content(textTheme),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nenhum resultado calculado ainda.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/quiz'),
              child: const Text('FAZER O QUIZ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(TextTheme textTheme) {
    final leaders = _session.topAffinityResults;
    final topResult = leaders.isEmpty ? null : leaders.first;
    if (!_hasTrackedResultsViewed && topResult != null) {
      _hasTrackedResultsViewed = true;
      _track(
        _analytics.resultsViewed(
          topCandidateId: topResult.candidateId,
          topScorePercent: topResult.scorePercent,
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
            Row(
              children: [
                Container(width: 4, height: 40, color: AppTheme.primary),
                const SizedBox(width: 12),
                Text('SEU\nRESULTADO', style: textTheme.headlineLarge),
              ],
            ),
            const SizedBox(height: 32),
            if (!_results.any((result) => result.hasComparableEvidence)) ...[
              Text(
                'Não foi possível calcular a afinidade com as candidaturas selecionadas.',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
            ],
            Text('AFINIDADE COM SUAS RESPOSTAS',
                style: textTheme.labelMedium),
            const SizedBox(height: 16),
            ..._results.map((result) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _CandidateResultRow(result: result),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/comparison');
                },
                child: const Text('COMPARAR RESPOSTAS'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/political-actors');
                },
                child: const Text('ACOMPANHAR POLITICOS'),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Text(
                'Este resultado compara posições documentadas nos planos oficiais. Ele não é uma recomendação de voto.',
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _backToHome,
                child: const Text('VOLTAR AO INÍCIO'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CandidateResultRow extends StatelessWidget {
  final CandidateResult result;

  const _CandidateResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        CandidateLogo(result: result, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      result.name,
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.hasComparableEvidence ? result.affinityLabel : '—',
                    semanticsLabel: result.hasComparableEvidence
                        ? null
                        : 'Afinidade indisponível',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(result.abbreviation, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
