import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/link/link_opener.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/political_actor_session.dart';
import '../../core/shell/shell_drawer_scope.dart';
import 'news_session.dart';
import 'widgets/news_card.dart';
import 'widgets/news_states.dart';

const String _camaraNewsUrl = 'https://www.camara.leg.br/noticias';

class HomePage extends StatefulWidget {
  const HomePage({super.key, NewsSession? newsSession, LinkOpener? openLink})
      : _newsSession = newsSession,
        _openLink = openLink;

  final NewsSession? _newsSession;
  final LinkOpener? _openLink;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _politicalActorSession = PoliticalActorSession.instance;
  late final NewsSession _news = widget._newsSession ?? NewsSession.instance;
  late final LinkOpener _openLink = widget._openLink ?? openExternalLink;

  @override
  void initState() {
    super.initState();
    unawaited(_politicalActorSession.loadFollowedActor());
    unawaited(_news.load());
  }

  Future<void> _open(String url) async {
    final ok = await _openLink(Uri.parse(url));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a notícia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sem `drawer`: a gaveta e uma so e vive no Scaffold do MainShell.
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: AnimatedBuilder(
                  animation: _news,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(),
                      const SizedBox(height: 16),
                      const Text(
                        'Fique por dentro dos principais acontecimentos '
                        'políticos dos últimos dias.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.55,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      if (_news.periodLabel.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _PeriodLabel(label: _news.periodLabel),
                      ],
                      const SizedBox(height: 24),
                      ..._buildBody(),
                      const SizedBox(height: 24),
                      _SeeAllButton(onPressed: () => _open(_camaraNewsUrl)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    const divider = Divider(height: 1, color: AppTheme.outlineVariant);

    switch (_news.status) {
      case NewsStatus.idle:
      case NewsStatus.loading:
        return const [
          divider,
          NewsSkeleton(),
          divider,
          NewsSkeleton(),
          divider,
          NewsSkeleton(),
          divider,
        ];
      case NewsStatus.empty:
        return const [divider, NewsEmpty(), divider];
      case NewsStatus.error:
        return [
          divider,
          NewsError(onRetry: () => unawaited(_news.load())),
          divider,
        ];
      case NewsStatus.ready:
        final widgets = <Widget>[divider];
        for (final article in _news.articles) {
          widgets.add(
            NewsCard(article: article, onTap: () => _open(article.url)),
          );
          widgets.add(divider);
        }
        return widgets;
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppTheme.onSurface),
            tooltip: 'Abrir menu',
            // Fora do shell nao ha gaveta para abrir; o botao fica inerte em vez
            // de estourar. Na pratica esta tela e sempre a primeira aba.
            onPressed: ShellDrawerScope.maybeOf(context),
          ),
          const Expanded(
            child: Text(
              'FAROL POLÍTICO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTÍCIAS DA SEMANA',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.3,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 2, color: AppTheme.onSurface),
      ],
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  const _PeriodLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppTheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('VER TODAS AS NOTÍCIAS'),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}
