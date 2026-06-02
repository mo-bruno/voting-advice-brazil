import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';
import '../utils/community_utils.dart';

class PostCard extends StatelessWidget {
  final PostSummary post;
  final VoidCallback onTap;
  final void Function(int value)? onVote;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onVote,
  });

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
            _PostHeader(post: post),
            const SizedBox(height: 10),
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
            _PostActions(post: post, onVote: onVote, onCommentTap: onTap),
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
  final VoidCallback onCommentTap;

  const _PostActions({
    required this.post,
    this.onVote,
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
                onTap: () => onVote?.call(1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${post.score}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
              ),
              _VoteButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => onVote?.call(-1),
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
  final VoidCallback onTap;

  const _VoteButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 18, color: AppTheme.onSurfaceVariant),
      ),
    );
  }
}
