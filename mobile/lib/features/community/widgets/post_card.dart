import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';
import '../utils/community_utils.dart';

class PostCard extends StatelessWidget {
  final PostSummary post;
  final VoidCallback onTap;
  final void Function(int value)? onVote;

  /// Enquanto o voto esta em voo as setas ficam inertes e esmaecidas: sem isso
  /// cada toque disparava uma requisicao nova, e nada indicava que a anterior
  /// ainda estava rodando.
  final bool votePending;

  /// Usado para decidir se o post e do proprio dispositivo — e portanto se a
  /// acao de apagar aparece.
  final String? currentAnonymousId;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onVote,
    this.votePending = false,
    this.currentAnonymousId,
    this.onDelete,
    this.onReport,
  });

  bool get _isMine =>
      currentAnonymousId != null && post.anonymousId == currentAnonymousId;

  bool get _hasActions =>
      !post.removed && (onReport != null || (onDelete != null && _isMine));

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppTheme.surfaceContainer,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _PostHeader(post: post)),
                if (_hasActions)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
                    color: AppTheme.surfaceContainerHigh,
                    onSelected: (v) {
                      if (v == 'report') onReport?.call();
                      if (v == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onReport != null)
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Denunciar'),
                        ),
                      if (onDelete != null && _isMine)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Apagar'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (post.removed)
              Text(
                post.tombstoneLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (post.themeSlug != null) ...[
              const SizedBox(height: 8),
              _ThemeTag(slug: post.themeSlug!),
            ],
            const SizedBox(height: 10),
            _PostActions(
              post: post,
              onVote: onVote,
              votePending: votePending,
              onCommentTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final PostSummary post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: avatarColor(post.anonymousId),
          child: Text(
            avatarInitials(post.anonymousId),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          shortUsername(post.anonymousId),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '·',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        Text(
          timeAgo(post.createdAt),
          style:
              const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ThemeTag extends StatelessWidget {
  final String slug;
  const _ThemeTag({required this.slug});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineVariant),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        slug.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final PostSummary post;
  final void Function(int value)? onVote;
  final bool votePending;
  final VoidCallback onCommentTap;

  const _PostActions({
    required this.post,
    this.onVote,
    this.votePending = false,
    required this.onCommentTap,
  });

  Color get _scoreColor {
    if (post.score > 0) return const Color(0xFFFF6314);
    if (post.score < 0) return const Color(0xFF7193FF);
    return AppTheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoteButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: votePending ? null : () => onVote?.call(1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${post.score}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        votePending ? AppTheme.onSurfaceVariant : _scoreColor,
                  ),
                ),
              ),
              _VoteButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: votePending ? null : () => onVote?.call(-1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onCommentTap,
          borderRadius: BorderRadius.circular(2),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;

  /// Nulo desabilita o botao — e assim que o estado de voto pendente aparece.
  final VoidCallback? onTap;

  const _VoteButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? AppTheme.surfaceContainerHighest
              : AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
