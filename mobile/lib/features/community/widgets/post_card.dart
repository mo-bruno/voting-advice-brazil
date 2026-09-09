import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/community_models.dart';
import '../utils/community_utils.dart';

/// Um post na lista.
///
/// A anatomia segue o desenho aprovado: sem preenchimento de card, separado dos
/// vizinhos por regua fina, com a coluna de voto a esquerda — a pontuacao e o
/// criterio de ordenacao do feed, entao precisa ser escaneavel na vertical.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.onVote,
    this.votePending = false,
    this.onDelete,
    this.onReport,
  });

  final PostSummary post;
  final VoidCallback onTap;
  final void Function(int value)? onVote;

  /// Enquanto o voto esta em voo as setas ficam inertes: sem isso cada toque
  /// disparava uma requisicao nova, concorrente com a anterior.
  final bool votePending;

  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  bool get _hasActions =>
      !post.removed && (onReport != null || (onDelete != null && post.isMine));

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VoteRail(
              score: post.score,
              enabled: !post.removed,
              pending: votePending,
              onVote: onVote,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(post: post, showMenu: _hasActions, card: this),
                  const SizedBox(height: 10),
                  if (post.removed)
                    Text(
                      post.tombstoneLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      post.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  if (post.themeSlug != null && !post.removed) ...[
                    const SizedBox(height: 10),
                    _ThemeTag(slug: post.themeSlug!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteRail extends StatelessWidget {
  const _VoteRail({
    required this.score,
    required this.enabled,
    required this.pending,
    this.onVote,
  });

  final int score;
  final bool enabled;
  final bool pending;
  final void Function(int value)? onVote;

  @override
  Widget build(BuildContext context) {
    // Post removido mantem o numero — a pontuacao que teve continua sendo um
    // fato — mas perde as setas: votar nele nao faz sentido.
    if (!enabled) {
      return SizedBox(
        width: 40,
        child: Center(
          child: Text(
            '$score',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.surfaceContainerHighest,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 40,
      child: Column(
        children: [
          _Arrow(
            icon: Icons.keyboard_arrow_up_rounded,
            onTap: pending ? null : () => onVote?.call(1),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: pending ? AppTheme.onSurfaceVariant : AppTheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          _Arrow(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: pending ? null : () => onVote?.call(-1),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      // A area de toque e maior que o icone: na coluna as setas ficam proximas
      // uma da outra, e o icone sozinho seria alvo pequeno demais.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? AppTheme.surfaceContainerHighest
              : AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.showMenu,
    required this.card,
  });

  final PostSummary post;
  final bool showMenu;
  final PostCard card;

  @override
  Widget build(BuildContext context) {
    const meta = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: post.removed
                ? AppTheme.surfaceContainerHigh
                : avatarColor(post.authorAlias),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            avatarInitials(post.authorAlias),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(post.authorAlias, style: meta),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '·',
            style: TextStyle(color: AppTheme.surfaceContainerHighest),
          ),
        ),
        Text(timeAgo(post.createdAt), style: meta),
        const Spacer(),
        if (showMenu)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 18,
              color: AppTheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
            color: AppTheme.surfaceContainerHigh,
            onSelected: (v) {
              if (v == 'report') card.onReport?.call();
              if (v == 'delete') card.onDelete?.call();
            },
            itemBuilder: (_) => [
              if (card.onReport != null)
                const PopupMenuItem(value: 'report', child: Text('Denunciar')),
              if (card.onDelete != null && post.isMine)
                const PopupMenuItem(value: 'delete', child: Text('Apagar')),
            ],
          ),
      ],
    );
  }
}

class _ThemeTag extends StatelessWidget {
  const _ThemeTag({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Text(
        slug.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
