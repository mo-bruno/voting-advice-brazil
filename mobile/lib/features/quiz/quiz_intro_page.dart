import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/thesis.dart';
import '../../shared/quiz_session.dart';
import 'quiz_processing_notice.dart';

class QuizIntroPage extends StatefulWidget {
  const QuizIntroPage({super.key, this.analytics});

  /// Injetavel para teste, seguindo o padrao que o QuizController ja usa:
  /// sem isto a tela chama o Firebase no initState e nao monta em teste.
  final AnalyticsService? analytics;

  @override
  State<QuizIntroPage> createState() => _QuizIntroPageState();
}

class _QuizIntroPageState extends State<QuizIntroPage> {
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();

  @override
  void initState() {
    super.initState();
    _track(_analytics.quizIntroViewed());
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  AnalyticsQuizStage _currentStage(QuizSession session) {
    if (session.candidates.isNotEmpty ||
        session.selectedCandidateIds.isNotEmpty) {
      return AnalyticsQuizStage.candidateSelection;
    }
    final questionsFinished = session.theses.isNotEmpty &&
        session.theses.every(
          (thesis) => thesis.answer != ThesisAnswer.unanswered,
        );
    return questionsFinished
        ? AnalyticsQuizStage.weighting
        : AnalyticsQuizStage.questions;
  }

  /// Comecar e o momento de descartar o teste anterior. Antes isso vivia no
  /// botao da tela de resultados, que precisava limpar tudo so para navegar;
  /// agora o resultado sobrevive a navegacao e so sai de cena quando outro
  /// quiz comeca de fato.
  void _startQuiz() {
    final session = QuizSession.instance;
    if (session.hasStartedFlow) {
      if (session.results.isEmpty) {
        _track(_analytics.quizAbandoned(
          stage: _currentStage(session),
          reason: AnalyticsAbandonReason.restart,
          totalAnswered: session.totalAnswered,
          totalSkipped: session.totalSkipped,
          durationMs: session.quizDurationMs(),
        ));
      }
      _track(_analytics.quizRestarted());
      // Antes de `markQuizStarted`: `resetQuiz` zera `quizStartedAt`, e na
      // ordem inversa a duracao do quiz sairia sem inicio.
      session.resetQuiz();
    }
    session.markQuizStarted();
    _track(_analytics.quizStarted());
    Navigator.pushNamed(context, '/quiz');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'FAROL POLÍTICO',
      // Sem `leading`: o AppScaffold da o hamburguer dentro do shell e a seta
      // de voltar se esta tela for empilhada — que foi como ela virou um beco
      // sem saida uma vez (ver `_defaultLeading`).
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Text('COMO\nFUNCIONA', style: textTheme.displayMedium),
                    const SizedBox(height: 16),
                    Text('PRESIDÊNCIA 2026', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Esta edição está em fase beta. O questionário reúne 20 teses construídas e validadas contra os 13 planos oficiais. Uma candidatura só entra no ranking quando o plano e as suas respostas oferecem base comparável suficiente; as demais continuam disponíveis para consulta. O resultado não é uma recomendação de voto.',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Você vai responder a uma série de teses políticas. Para cada uma, escolha se concorda, discorda, fica neutro ou prefere pular.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Responda pelo menos ${QuizSession.minimumAnswers} perguntas para calcular o resultado. A comparação considera apenas posições documentadas nos planos oficiais; ausência de evidência não significa discordância.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const QuizProcessingNotice(),
                    const SizedBox(height: 24),
                    const _TutorialStep(
                      icon: Icons.check,
                      title: 'Concordo',
                      text: 'Use quando a frase representa sua opinião.',
                    ),
                    const SizedBox(height: 12),
                    const _TutorialStep(
                      icon: Icons.remove,
                      title: 'Neutro',
                      text:
                          'Use quando você não tem posição forte sobre o tema.',
                    ),
                    const SizedBox(height: 12),
                    const _TutorialStep(
                      icon: Icons.close,
                      title: 'Discordo',
                      text: 'Use quando você pensa o contrário da frase.',
                    ),
                    const SizedBox(height: 12),
                    const _TutorialStep(
                      icon: Icons.skip_next,
                      title: 'Pular',
                      text: 'Perguntas puladas não entram no cálculo.',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startQuiz,
                child: const Text('COMEÇAR PERGUNTAS'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
