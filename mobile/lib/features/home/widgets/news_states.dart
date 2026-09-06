import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Esqueleto com as mesmas dimensões do card real, para a lista não pular
/// quando os dados chegarem.
class NewsSkeleton extends StatelessWidget {
  const NewsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Block(width: 88, height: 88),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: 74, height: 20),
                SizedBox(height: 9),
                _Block(width: double.infinity, height: 13),
                SizedBox(height: 9),
                _Block(width: 180, height: 13),
                SizedBox(height: 9),
                _Block(width: double.infinity, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.surfaceContainer,
    );
  }
}

class NewsEmpty extends StatelessWidget {
  const NewsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NewsMessage(
      icon: Icons.article_outlined,
      iconColor: AppTheme.surfaceContainerHighest,
      title: 'Nenhuma notícia nos últimos 7 dias',
      body: 'A Câmara não publicou matérias nos temas acompanhados neste '
          'período. Volte em alguns dias.',
    );
  }
}

class NewsError extends StatelessWidget {
  const NewsError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _NewsMessage(
      icon: Icons.warning_amber_rounded,
      iconColor: AppTheme.error,
      title: 'Não foi possível carregar as notícias',
      body: 'Verifique sua conexão e tente novamente.',
      action: OutlinedButton(
        onPressed: onRetry,
        child: const Text('TENTAR DE NOVO'),
      ),
    );
  }
}

class _NewsMessage extends StatelessWidget {
  const _NewsMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 44, color: iconColor),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}
