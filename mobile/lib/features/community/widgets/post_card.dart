import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';
import '../utils/community_utils.dart';
import 'post_vote_controls.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onVote,
    this.votePending = false,
    this.onDelete,
    this.onReport,
    this.detailed = false,
  });

  final PostSummary post;
  final VoidCallback onTap;
  final ValueChanged<int>? onVote;
  final bool votePending;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final hasActions = !post.removed &&
        (onReport != null || (onDelete != null && post.isMine));
    final contents = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: avatarColor(post.authorAlias),
              child: Text(avatarInitials(post.authorAlias),
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(post.authorAlias,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(timeAgo(post.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.onSurfaceVariant)),
                  if (post.isMine)
                    const Text('Você',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (hasActions)
              PopupMenuButton<String>(
                tooltip: 'Ações do post',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'report') onReport?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  if (onReport != null)
                    const PopupMenuItem(
                        value: 'report', child: Text('Denunciar')),
                  if (onDelete != null && post.isMine)
                    const PopupMenuItem(value: 'delete', child: Text('Apagar')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          post.removed ? post.tombstoneLabel : post.content,
          maxLines: detailed || post.removed ? null : 3,
          overflow: detailed || post.removed ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: detailed ? 16 : 15,
            height: 1.5,
            color:
                post.removed ? AppTheme.onSurfaceVariant : AppTheme.onSurface,
            fontStyle: post.removed ? FontStyle.italic : null,
          ),
        ),
        if (post.themeLabel != null && !post.removed) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.outlineVariant)),
            child: Text(post.themeLabel!,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.onSurfaceVariant)),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 16, color: AppTheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
              '${post.commentCount} comentário${post.commentCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.onSurfaceVariant),
            )),
          ],
        ),
        if (detailed) ...[
          const SizedBox(height: 8),
          PostVoteControls(post: post, pending: votePending, onVote: onVote),
        ],
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: detailed
          ? contents
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PostVoteControls(
                    post: post,
                    vertical: true,
                    pending: votePending,
                    onVote: onVote),
                const SizedBox(width: 12),
                Expanded(child: contents),
              ],
            ),
    );
    return detailed ? body : InkWell(onTap: onTap, child: body);
  }
}
