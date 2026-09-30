import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_navigation.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/shell/main_shell.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/candidate_result.dart';
import '../../shared/quiz_session.dart';
import '../../shared/widgets/candidate_logo.dart';
import 'sharing/result_share_data.dart';
import 'sharing/result_share_page.dart';

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

  List<CandidateResult> get _results =>
      [..._session.visibleResults]..sort((a, b) {
          if (a.rankingEligible != b.rankingEligible) {
            return a.rankingEligible ? -1 : 1;
          }
          if (a.rankingEligible) {
            final byRank = a.rank.compareTo(b.rank);
            if (byRank != 0) return byRank;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
        onPressed: () => Navigator.pop(context),
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
    final shareableResults =
        _results.where((result) => result.rankingEligible).toList();
    final outsideRanking =
        _results.where((result) => !result.rankingEligible).toList();
    if (!_hasTrackedResultsViewed && _session.topAffinityResults.isNotEmpty) {
      _hasTrackedResultsViewed = true;
      _track(_analytics.resultsViewed());
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
            if (shareableResults.isEmpty) ...[
              Text(
                'Não houve base suficiente para formar um ranking com as candidaturas selecionadas.',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
            ],
            if (shareableResults.isNotEmpty) ...[
              Text('MEU RANKING DE AFINIDADE · BETA',
                  style: textTheme.labelMedium),
              const SizedBox(height: 16),
              ...shareableResults.map((result) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CandidateResultRow(result: result),
                );
              }),
            ],
            if (outsideRanking.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('FORA DO RANKING DESTA EDIÇÃO BETA',
                  style: textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(
                'Os planos continuam disponíveis para consulta. A ausência no ranking indica apenas que esta edição não encontrou base comparável suficiente.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...outsideRanking.map((result) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CandidateResultRow(result: result),
                );
              }),
            ],
            const SizedBox(height: 16),
            if (shareableResults.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: resultShareRoute),
                      builder: (_) => ResultSharePage(
                        data: ResultShareData(results: shareableResults),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: const Text('Compartilhar resultado'),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                'O Farol Político está em fase beta. Este resultado compara somente posições documentadas nos planos oficiais e não é uma recomendação de voto.',
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
              Text(
                result.name,
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                result.affinityLabel,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(result.abbreviation, style: textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(result.coverageLabel, style: textTheme.bodySmall),
              if (!result.rankingEligible) ...[
                const SizedBox(height: 4),
                Text(result.rankingExplanation, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
