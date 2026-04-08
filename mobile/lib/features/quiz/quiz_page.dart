import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/layout/app_scaffold.dart';
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
      setState(() {});
    });
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
    final textTheme = Theme.of(context).textTheme;
    final thesis = controller.currentThesis;

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {},
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _ProgressIndicator(
                      current: controller.currentIndex + 1,
                      total: controller.totalTheses,
                    ),
                    const SizedBox(height: 32),
                    _ThesisCard(thesis: thesis),
                    const SizedBox(height: 32),
                    _ChoiceButton(
                      icon: Icons.thumb_up,
                      label: 'CONCORDO',
                      onPressed: () {
                        controller.answer(ThesisAnswer.agree);
                        if (controller.isLast) _onFinishQuiz();
                      },
                    ),
                    const SizedBox(height: 12),
                    _ChoiceButton(
                      icon: Icons.help_outline,
                      label: 'NEUTRO',
                      onPressed: () {
                        controller.answer(ThesisAnswer.neutral);
                        if (controller.isLast) _onFinishQuiz();
                      },
                    ),
                    const SizedBox(height: 12),
                    _ChoiceButton(
                      icon: Icons.thumb_down,
                      label: 'DISCORDO',
                      onPressed: () {
                        controller.answer(ThesisAnswer.disagree);
                        if (controller.isLast) _onFinishQuiz();
                      },
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        controller.skip();
                        if (controller.isLast) _onFinishQuiz();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PULAR ESTA QUESTÃO',
                            style: textTheme.labelMedium,
                          ),
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
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: AppTheme.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up_outlined, size: 20),
                  onPressed: () {},
                  color: AppTheme.onSurfaceVariant,
                ),
                const Spacer(),
                if (!controller.isFirst)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: controller.previous,
                    color: AppTheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ],
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
    return Column(
      children: [
        Text(
          '$current/$total',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            total > 10 ? 10 : total,
            (index) {
              final mappedIndex =
                  (index * total / (total > 10 ? 10 : total)).round();
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
            },
          ),
        ),
      ],
    );
  }
}

class _ThesisCard extends StatelessWidget {
  final Thesis thesis;

  const _ThesisCard({required this.thesis});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Text(
        thesis.title,
        style: Theme.of(context).textTheme.headlineLarge,
        textAlign: TextAlign.center,
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
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: const BorderSide(color: AppTheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}
