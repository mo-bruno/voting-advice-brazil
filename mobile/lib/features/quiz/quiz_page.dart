import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/thesis.dart';
import 'quiz_controller.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final QuizController controller = QuizController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.loadQuestions();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onFinishQuiz() {
    Navigator.pushNamed(context, '/weighting');
  }

  @override
  Widget build(BuildContext context) {
    final thesis = controller.currentThesis;

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/quiz-intro');
        },
      ),
      body: _buildBody(thesis),
    );
  }

  Widget _buildBody(Thesis? thesis) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return _StateMessage(
        title: 'Nao foi possivel carregar as perguntas.',
        message: controller.errorMessage!,
        actionLabel: 'TENTAR NOVAMENTE',
        onPressed: controller.loadQuestions,
      );
    }

    if (thesis == null) {
      return _StateMessage(
        title: 'Nenhuma pergunta encontrada.',
        message: 'Confira se o backend esta rodando e com dados carregados.',
        actionLabel: 'RECARREGAR',
        onPressed: controller.loadQuestions,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _ProgressIndicator(
              current: controller.currentIndex + 1,
              total: controller.totalTheses,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: !controller.isFirst
                    ? TextButton.icon(
                        onPressed: controller.previous,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text('VOLTAR', style: textTheme.labelMedium),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
            _ThesisCard(thesis: thesis),
            const SizedBox(height: 32),
            _ChoiceButton(
              icon: Icons.thumb_up,
              label: 'CONCORDO',
              onPressed: () {
                if (controller.answer(ThesisAnswer.agree)) _onFinishQuiz();
              },
            ),
            const SizedBox(height: 12),
            _ChoiceButton(
              icon: Icons.help_outline,
              label: 'NEUTRO',
              onPressed: () {
                if (controller.answer(ThesisAnswer.neutral)) _onFinishQuiz();
              },
            ),
            const SizedBox(height: 12),
            _ChoiceButton(
              icon: Icons.thumb_down,
              label: 'DISCORDO',
              onPressed: () {
                if (controller.answer(ThesisAnswer.disagree)) _onFinishQuiz();
              },
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                if (controller.skip()) _onFinishQuiz();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PULAR ESTA QUESTAO', style: textTheme.labelMedium),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
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

  TextStyle _textStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineLarge!;
    if (thesis.title.length > 150) {
      return base.copyWith(fontSize: 18, height: 1.25);
    }
    if (thesis.title.length > 95) {
      return base.copyWith(fontSize: 20, height: 1.25);
    }
    return base.copyWith(fontSize: 24, height: 1.2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 150,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            thesis.title,
            style: _textStyle(context),
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: const BorderSide(color: AppTheme.outlineVariant),
        ),
      ),
    );
  }
}
