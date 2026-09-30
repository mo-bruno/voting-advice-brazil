import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';

class PostVoteControls extends StatelessWidget {
  const PostVoteControls({
    super.key,
    required this.post,
    this.onVote,
    this.pending = false,
    this.vertical = false,
  });

  final PostSummary post;
  final ValueChanged<int>? onVote;
  final bool pending;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final score = Semantics(
      label: 'Pontuação: ${post.score}',
      child: ExcludeSemantics(
        child: Text('${post.score}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ),
    );
    if (post.removed) return SizedBox(width: 48, child: Center(child: score));
    Widget button(int value, IconData icon) {
      final selected = post.myVote == value;
      return Semantics(
        selected: selected,
        child: IconButton(
          tooltip: selected
              ? 'Retirar voto ${value == 1 ? 'positivo' : 'negativo'}'
              : value == 1
                  ? 'Votar a favor'
                  : 'Votar contra',
          onPressed: pending || onVote == null
              ? null
              : () => onVote!(selected ? 0 : value),
          icon: Icon(icon),
          color: selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: selected ? AppTheme.surfaceContainerHigh : null,
          ),
        ),
      );
    }

    final children = [
      button(1, Icons.keyboard_arrow_up_rounded),
      score,
      button(-1, Icons.keyboard_arrow_down_rounded),
    ];
    return vertical
        ? SizedBox(
            width: 48,
            child: Column(mainAxisSize: MainAxisSize.min, children: children))
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
