import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/layout/responsive_layout.dart';
import '../../../shared/models/news_article.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final desktop = ResponsiveLayout.isDesktop(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(article: article),
            SizedBox(width: desktop ? 24 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ThemeChip(label: article.themeLabel),
                  const SizedBox(height: 8),
                  Text(
                    article.title.toUpperCase(),
                    maxLines: desktop ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: desktop ? 20 : 14,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                      color: AppTheme.primary,
                    ),
                  ),
                  // Nem toda matéria da Câmara traz `description` — medido em
                  // 1 de 13 artigos. Sem isto o bloco vazio deixaria um vão.
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.summary,
                      maxLines: desktop ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: desktop ? 16 : 12,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _CardMeta(article: article),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.imageUrl;
    final desktop = ResponsiveLayout.isDesktop(context);
    return Container(
      width: desktop ? 200 : 88,
      height: desktop ? 176 : 88,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: imageUrl == null
          ? _ThumbFallback(initial: article.themeInitial)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _ThumbFallback(initial: article.themeInitial),
            ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          color: AppTheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CardMeta extends StatelessWidget {
  const _CardMeta({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.8,
      color: AppTheme.onSurfaceVariant,
    );

    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 12,
          color: AppTheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            article.formattedDate,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 10, color: AppTheme.outlineVariant),
        const SizedBox(width: 8),
        const Icon(Icons.schedule, size: 12, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            article.readingLabel,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
