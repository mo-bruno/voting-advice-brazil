import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';
import '../utils/community_utils.dart';

class CommentTile extends StatelessWidget {
  const CommentTile(
      {super.key,
      required this.comment,
      required this.onDelete,
      required this.onReport});
  final PostComment comment;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                radius: 12,
                backgroundColor: avatarColor(comment.authorAlias),
                child: Text(avatarInitials(comment.authorAlias),
                    style: const TextStyle(fontSize: 10, color: Colors.white))),
            const SizedBox(width: 8),
            Expanded(
                child: Wrap(spacing: 8, runSpacing: 2, children: [
              Text(comment.authorAlias,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(timeAgo(comment.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.onSurfaceVariant)),
              if (comment.isMine)
                const Text('Você',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceVariant)),
            ])),
            if (!comment.removed)
              PopupMenuButton<String>(
                tooltip: 'Ações do comentário',
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  } else {
                    onReport();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'report', child: Text('Denunciar')),
                  if (comment.isMine)
                    const PopupMenuItem(value: 'delete', child: Text('Apagar')),
                ],
              ),
          ]),
          const SizedBox(height: 8),
          Text(comment.removed ? comment.tombstoneLabel : comment.content,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: comment.removed
                      ? AppTheme.onSurfaceVariant
                      : AppTheme.onSurface,
                  fontStyle: comment.removed ? FontStyle.italic : null)),
        ]),
      );
}
