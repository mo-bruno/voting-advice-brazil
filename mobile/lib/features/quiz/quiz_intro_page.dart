import 'package:flutter/material.dart';

import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';

class QuizIntroPage extends StatelessWidget {
  const QuizIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'GUIA ELEITORAL',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        },
      ),
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
                    Text(
                      'COMO\nFUNCIONA',
                      style: textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Você vai responder a uma série de teses políticas. Para cada uma, escolha se concorda, discorda, fica neutro ou prefere pular.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
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
                onPressed: () {
                  Navigator.pushNamed(context, '/quiz');
                },
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
