// lib/shared/widgets/drawer/quiz_affinity_tile.dart
//
// O primeiro colocado do ultimo quiz. Fica na gaveta porque e a resposta que a
// pessoa costuma querer reler — e o caminho de volta para a lista inteira.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../models/candidate_result.dart';
import 'drawer_section.dart';

class QuizAffinityTile extends StatelessWidget {
  const QuizAffinityTile({
    super.key,
    required this.top,
    required this.onOpenResults,
    required this.onStartQuiz,
  });

  final CandidateResult? top;
  final VoidCallback onOpenResults;
  final VoidCallback onStartQuiz;

  @override
  Widget build(BuildContext context) {
    final first = top;

    return InkWell(
      onTap: first == null ? null : onOpenResults,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DrawerSectionLabel('SUA MAIOR AFINIDADE'),
            const SizedBox(height: 12),
            if (first == null)
              _Empty(onStartQuiz: onStartQuiz)
            else
              _Affinity(result: first),
          ],
        ),
      ),
    );
  }
}

class _Affinity extends StatelessWidget {
  const _Affinity({required this.result});

  final CandidateResult result;

  /// Recortado em 0..100: a barra e uma proporcao, e um valor fora da faixa
  /// vindo da API viraria um retangulo maior que o proprio trilho.
  double get _fraction => (result.scorePercent / 100).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                result.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${result.scorePercent.round()}%',
              style: textTheme.headlineMedium,
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // A barra repete a porcentagem de proposito: o numero diz o valor, a
        // barra diz se 87% e muito, sem a pessoa precisar comparar de cabeca.
        SizedBox(
          height: 3,
          child: Row(
            children: [
              Expanded(
                flex: (_fraction * 1000).round(),
                child: Container(color: AppTheme.primary),
              ),
              Expanded(
                flex: 1000 - (_fraction * 1000).round(),
                child: Container(color: AppTheme.surfaceContainerHigh),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onStartQuiz});

  final VoidCallback onStartQuiz;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Você ainda não fez o quiz.',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        DrawerInlineAction(
          label: 'Descobrir minha afinidade',
          onTap: onStartQuiz,
        ),
      ],
    );
  }
}
