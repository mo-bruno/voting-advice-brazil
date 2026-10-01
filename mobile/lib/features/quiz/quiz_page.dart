import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/features/feature_flags.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/thesis.dart';
import 'quiz_controller.dart';
import '../../shared/iot_device_session.dart';
import 'thesis_explanation_panel.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    this.iotEnabled,
    this.controller,
    this.iotSession,
  });

  /// Quando ausente, usa a flag de compilação da aplicação.
  final bool? iotEnabled;

  @visibleForTesting
  final QuizController? controller;

  @visibleForTesting
  final IotDeviceSession? iotSession;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final QuizController controller = widget.controller ?? QuizController();
  final _questionScroll = ScrollController();
  int? _visibleThesisId;
  bool _abandonmentRecorded = false;
  bool _questionsCompleted = false;
  late final bool _enteredAfterResults;

  @override
  void initState() {
    super.initState();
    _enteredAfterResults = controller.session.results.isNotEmpty;
    controller.addListener(_onQuestionChanged);
    controller.loadQuestions();
  }

  void _onQuestionChanged() {
    if (!mounted) return;
    final id = controller.currentThesis?.id;
    if (_visibleThesisId != id) {
      _visibleThesisId = id;
      if (_questionScroll.hasClients) _questionScroll.jumpTo(0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onQuestionChanged);
    controller.dispose();
    _questionScroll.dispose();
    super.dispose();
  }

  Future<void> _onFinishQuiz() async {
    _questionsCompleted = true;
    await Navigator.pushNamed(context, '/weighting');
    if (mounted && controller.session.results.isEmpty) {
      _questionsCompleted = false;
    }
  }

  void _recordAbandonment() {
    if (_abandonmentRecorded || _questionsCompleted || _enteredAfterResults) {
      return;
    }
    _abandonmentRecorded = true;
    final session = controller.session;
    unawaited(
      controller.analytics
          .quizAbandoned(
            stage: AnalyticsQuizStage.questions,
            reason: AnalyticsAbandonReason.back,
            totalAnswered: session.totalAnswered,
            totalSkipped: session.totalSkipped,
            durationMs: session.quizDurationMs(),
          )
          .catchError((_) {}),
    );
  }

  void _exitQuiz() {
    _recordAbandonment();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  String _getAnswerValue(ThesisAnswer answer) {
    switch (answer) {
      case ThesisAnswer.agree:
        return 'agree';
      case ThesisAnswer.neutral:
        return 'neutral';
      case ThesisAnswer.disagree:
        return 'disagree';
      case ThesisAnswer.skipped:
        return 'skip';
      case ThesisAnswer.unanswered:
        return 'skip';
    }
  }

  void _handleAnswer(ThesisAnswer value) {
    final iotEnabled = widget.iotEnabled ?? FeatureFlags.environment.iotEnabled;
    if (iotEnabled) {
      unawaited(
        (widget.iotSession ?? IotDeviceSession.instance).sendQuizPulse(
          answer: _getAnswerValue(value),
          current: controller.currentIndex + 1,
          total: controller.totalTheses,
        ),
      );
    }
    controller.answer(value).then((finished) {
      if (finished && mounted) unawaited(_onFinishQuiz());
    });
  }

  @override
  Widget build(BuildContext context) {
    final thesis = controller.currentThesis;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _recordAbandonment();
      },
      child: AppScaffold(
        title: 'FAROL POLÍTICO',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Sair do quiz',
          onPressed: () {
            // Desempilha ate o shell em vez de empilhar /quiz-intro: aquela rota
            // monta a QuizIntroPage FORA do shell, sem barra inferior, e como ela
            // e uma tela-aba mostra o hamburguer no lugar da seta — o usuario
            // ficava sem barra e sem volta.
            //
            // Aqui e `popUntil` e nao o `pushNamedAndRemoveUntil` que a
            // ResultsPage usa: sair do quiz e voltar de onde se veio, e o shell
            // ja esta na aba certa. Recria-lo jogaria fora as telas que ele
            // mantem vivas de proposito (ver MainShell._pages).
            _exitQuiz();
          },
        ),
        body: _buildBody(thesis),
      ),
    );
  }

  Widget _buildBody(Thesis? thesis) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return _StateMessage(
        title: 'Não foi possível carregar as perguntas.',
        message: controller.errorMessage!,
        actionLabel: 'TENTAR NOVAMENTE',
        onPressed: () => controller.loadQuestions(
          force: true,
          trigger: AnalyticsTrigger.retry,
        ),
      );
    }

    if (thesis == null) {
      return _StateMessage(
        title: 'Nenhuma pergunta encontrada.',
        message: 'Confira se o backend está rodando e com dados carregados.',
        actionLabel: 'RECARREGAR',
        onPressed: () => controller.loadQuestions(
          force: true,
          trigger: AnalyticsTrigger.retry,
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, viewport) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _questionScroll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProgressIndicator(
                          current: controller.currentIndex + 1,
                          total: controller.totalTheses,
                        ),
                        if (!controller.isFirst)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: controller.previous,
                              icon: const Icon(Icons.arrow_back, size: 18),
                              label:
                                  Text('VOLTAR', style: textTheme.labelMedium),
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48)),
                            ),
                          )
                        else
                          const SizedBox(height: 24),
                        _ThesisCard(thesis: thesis),
                        if (thesis.explanation != null) ...[
                          const SizedBox(height: 16),
                          ThesisExplanationPanel(
                            key: ValueKey(thesis.id),
                            explanation: thesis.explanation!,
                            analytics: controller.analytics,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // A short landscape viewport or very large text can scroll the
          // answer area itself, without covering the question or clipping it.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: viewport.maxHeight * 0.5),
            child: SingleChildScrollView(
              primary: false,
              child: _AnswerBar(
                onAnswer: _handleAnswer,
                onSkip: () {
                  controller.skip().then((finished) {
                    if (finished && mounted) unawaited(_onFinishQuiz());
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _StateMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final visibleDots = total > 10 ? 10 : total;
    return Column(
      children: [
        Text('$current/$total', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(visibleDots, (index) {
            final mappedIndex = (index * total / visibleDots).round();
            final isActive = mappedIndex < current;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppTheme.primary
                    : AppTheme.surfaceContainerHighest,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ThesisCard extends StatelessWidget {
  final Thesis thesis;

  const _ThesisCard({required this.thesis});

  TextStyle _textStyle(BuildContext context, {required bool compact}) {
    final base = Theme.of(context).textTheme.headlineLarge!;
    if (thesis.title.length > 150) {
      return base.copyWith(fontSize: 17, height: 1.25);
    }
    if (thesis.title.length > 95 || compact) {
      return base.copyWith(fontSize: 19, height: 1.25);
    }
    return base.copyWith(fontSize: 24, height: 1.2);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 312;
      return SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 32, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                thesis.title,
                style: _textStyle(context, compact: compact),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: 12),
          side: const BorderSide(color: AppTheme.outlineVariant),
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(height: 8),
                  Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppTheme.primary)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Flexible(child: Text(label)),
                ],
              ),
      ),
    );
  }
}

class _AnswerBar extends StatelessWidget {
  final ValueChanged<ThesisAnswer> onAnswer;
  final VoidCallback onSkip;

  const _AnswerBar({required this.onAnswer, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: LayoutBuilder(
              builder: (context, available) => Padding(
                padding: EdgeInsets.fromLTRB(available.maxWidth < 360 ? 16 : 24,
                    16, available.maxWidth < 360 ? 16 : 24, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final label = TextPainter(
                      text: TextSpan(
                          text: 'CONCORDO', style: textTheme.labelMedium),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout();
                    final compact =
                        (constraints.maxWidth - 16) / 3 >= label.width + 10;
                    label.dispose();
                    final choices = [
                      _ChoiceButton(
                          icon: Icons.thumb_up,
                          label: 'CONCORDO',
                          compact: compact,
                          onPressed: () => onAnswer(ThesisAnswer.agree)),
                      _ChoiceButton(
                          icon: Icons.help_outline,
                          label: 'NEUTRO',
                          compact: compact,
                          onPressed: () => onAnswer(ThesisAnswer.neutral)),
                      _ChoiceButton(
                          icon: Icons.thumb_down,
                          label: 'DISCORDO',
                          compact: compact,
                          onPressed: () => onAnswer(ThesisAnswer.disagree)),
                    ];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (compact)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: choices[0]),
                              const SizedBox(width: 8),
                              Expanded(child: choices[1]),
                              const SizedBox(width: 8),
                              Expanded(child: choices[2]),
                            ],
                          )
                        else
                          ...choices.expand(
                              (choice) => [choice, const SizedBox(height: 8)]),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48)),
                          child: Text('PULAR ESTA QUESTÃO',
                              style: textTheme.labelMedium,
                              textAlign: TextAlign.center),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
