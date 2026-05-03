import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/candidate_result.dart';
import '../../shared/quiz_session.dart';
import '../../shared/widgets/candidate_logo.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final AnalyticsService _analytics = AnalyticsService();
  final QuizSession _session = QuizSession.instance;
  bool _hasTrackedResultsViewed = false;

  List<CandidateResult> get _results => _session.visibleResults;

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'ELEIÇÃO 2026',
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
    final topResult = _results.first;
    if (!_hasTrackedResultsViewed) {
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
            _TopResultCard(result: topResult),
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
            const SizedBox(height: 32),
            ...List.generate(_results.length - 1, (index) {
              final result = _results[index + 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _CandidateResultRow(result: result),
              );
            }),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Text(
                'O resultado é calculado pelo backend com base nas suas respostas e nas posições cadastradas para cada candidato.',
                style: textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('CONTINUAR'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final CandidateResult result;

  const _TopResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text('MAIOR AFINIDADE', style: textTheme.labelMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CandidateLogo(result: result, size: 48),
              const SizedBox(width: 16),
              Text(
                '${result.scorePercent.toStringAsFixed(1)}%',
                style: textTheme.displayMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.name,
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(result.abbreviation, style: textTheme.titleMedium),
        ],
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
                    '${result.scorePercent.toStringAsFixed(1)}%',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: result.scorePercent / 100,
                  minHeight: 4,
                  backgroundColor: AppTheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
