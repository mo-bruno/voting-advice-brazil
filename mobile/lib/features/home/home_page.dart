import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/branding/farol_wordmark.dart';
import '../../core/link/link_opener.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/political_actor_session.dart';
import '../../core/shell/shell_drawer_scope.dart';
import 'news_session.dart';
import 'widgets/news_card.dart';
import 'widgets/news_states.dart';

const String _camaraNewsUrl = 'https://www.camara.leg.br/noticias';
const String _quizGuideUrl = 'https://fpolitico.com.br/eleicoes-2026/';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onStartQuiz,
    this.politicianFollowEnabled = false,
    PoliticalActorSession? politicalActorSession,
    NewsSession? newsSession,
    LinkOpener? openLink,
  })  : _politicalActorSession = politicalActorSession,
        _newsSession = newsSession,
        _openLink = openLink;

  final VoidCallback onStartQuiz;
  final bool politicianFollowEnabled;
  final PoliticalActorSession? _politicalActorSession;
  final NewsSession? _newsSession;
  final LinkOpener? _openLink;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PoliticalActorSession _politicalActorSession =
      widget._politicalActorSession ?? PoliticalActorSession.instance;
  late final NewsSession _news = widget._newsSession ?? NewsSession.instance;
  late final LinkOpener _openLink = widget._openLink ?? openExternalLink;

  @override
  void initState() {
    super.initState();
    if (widget.politicianFollowEnabled) {
      unawaited(_politicalActorSession.loadFollowedActor());
    }
    unawaited(_news.load());
  }

  Future<void> _open(String url, {bool isQuizGuide = false}) async {
    final ok = await _openLink(Uri.parse(url));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isQuizGuide
              ? 'Não foi possível abrir o guia do quiz.'
              : 'Não foi possível abrir a notícia.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = ResponsiveLayout.isDesktop(context);
    return Scaffold(
      // Sem `drawer`: a gaveta e uma so e vive no Scaffold do MainShell.
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            if (!desktop) const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, desktop ? 48 : 28, 24, 32),
                child: AnimatedBuilder(
                  animation: _news,
                  builder: (context, _) {
                    final news = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!desktop) ...[
                          _QuizInvitation(
                            onPressed: widget.onStartQuiz,
                            onLearnMore: () => unawaited(
                                _open(_quizGuideUrl, isQuizGuide: true)),
                          ),
                          const SizedBox(height: 40),
                        ],
                        const _SectionTitle(),
                        const SizedBox(height: 16),
                        Text(
                          'Fique por dentro dos principais acontecimentos '
                          'políticos dos últimos dias.',
                          style: TextStyle(
                            fontSize: desktop ? 16 : 12,
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
                    );
                    if (!desktop) return news;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: ResponsiveLayout.desktopContentWidth),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 64, child: news),
                            const SizedBox(width: 32),
                            Expanded(
                                flex: 36,
                                child: _QuizInvitation(
                                  onPressed: widget.onStartQuiz,
                                  onLearnMore: () => unawaited(
                                      _open(_quizGuideUrl, isQuizGuide: true)),
                                )),
                          ],
                        ),
                      ),
                    );
                  },
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

class _QuizInvitation extends StatelessWidget {
  const _QuizInvitation({required this.onPressed, required this.onLearnMore});

  final VoidCallback onPressed;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = ResponsiveLayout.isDesktop(context);

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(desktop ? 28 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.how_to_vote_outlined,
                size: desktop ? 40 : 30,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Faça seu quiz agora',
                style: theme.textTheme.headlineLarge
                    ?.copyWith(height: 1.08, fontSize: desktop ? 30 : 24),
              ),
              const SizedBox(height: 12),
              Text(
                'Descubra sua afinidade com as propostas para a eleição '
                'presidencial de 2026.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(height: 1.5, fontSize: desktop ? 18 : 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: const Text('Começar o quiz'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onLearnMore,
                child: const Text('Entenda as fontes e o resultado'),
              ),
            ],
          ),
        ),
      ),
    );
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
            child: Center(child: FarolWordmark(fontSize: 16)),
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
    final desktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTÍCIAS DA SEMANA',
          style: TextStyle(
            fontSize: desktop ? 40 : 28,
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
    final desktop = ResponsiveLayout.isDesktop(context);
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
              style: TextStyle(
                fontSize: desktop ? 16 : 12,
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
            Flexible(
              child: Text(
                'VER TODAS AS NOTÍCIAS',
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}
