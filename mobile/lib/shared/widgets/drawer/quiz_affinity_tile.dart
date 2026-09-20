import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'drawer_section.dart';

/// Atalho para a comparação documental, sem eleger uma candidatura.
class QuizAffinityTile extends StatelessWidget {
  const QuizAffinityTile({
    super.key,
    required this.hasResults,
    required this.onOpenResults,
    required this.onStartQuiz,
  });

  final bool hasResults;
  final VoidCallback onOpenResults;
  final VoidCallback onStartQuiz;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DrawerSectionLabel('COMPARAÇÃO DOS PLANOS'),
          const SizedBox(height: 12),
          Text(
            hasResults
                ? 'Consulte a afinidade documentada e a cobertura de cada candidatura.'
                : 'Você ainda não fez o quiz.',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          DrawerInlineAction(
            label: hasResults ? 'Ver resultados' : 'Descobrir minha afinidade',
            onTap: hasResults ? onOpenResults : onStartQuiz,
          ),
        ],
      ),
    );
  }
}
