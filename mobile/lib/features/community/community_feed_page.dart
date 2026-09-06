import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import 'community_session.dart';
import 'create_post_page.dart';
import 'models/community_models.dart';
import 'post_detail_page.dart';
import 'widgets/post_card.dart';

enum _SortMode { quente, recente }

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key, this.apiClient});

  /// Injetavel para teste, seguindo o padrao das sessions: sem isto os estados
  /// de sucesso e de vazio nao sao verificaveis, porque em teste de widget toda
  /// chamada HTTP devolve 400.
  @visibleForTesting
  final ApiClient? apiClient;

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final _session = CommunitySession();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool _loading = true;
  bool _failed = false;
  bool _loadMoreFailed = false;
  String? _anonymousId;
  _SortMode _sort = _SortMode.quente;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
    await _loadPage(1);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _session.hasMore &&
        !_loadMoreFailed &&
        !_loading) {
      _loadPage(_session.currentPage + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_anonymousId == null) return;
    setState(() {
      _loading = true;
      if (page == 1) _failed = false;
      _loadMoreFailed = false;
    });
    try {
      final data = await _api.listPosts(
        anonymousId: _anonymousId!,
        page: page,
      );
      final posts = (data['posts'] as List)
          .map((p) => PostSummary.fromJson(p as Map<String, dynamic>))
          .toList();
      final hasNext = data['has_next'] as bool;
      if (page == 1) {
        _session.setFeed(posts, hasMore: hasNext, page: page);
      } else {
        _session.appendFeed(posts, hasMore: hasNext, page: page);
      }
    } catch (_) {
      if (!mounted) return;
      if (page == 1) {
        // Falha na primeira pagina: nao ha nada para mostrar, entao a tela
        // inteira vira estado de erro. Antes isto virava "feed vazio", que e
        // indistinguivel de uma comunidade sem posts.
        setState(() => _failed = true);
      } else {
        // Falha ao paginar: o que ja veio continua valendo. Sem este flag o
        // rodape da lista giraria para sempre, porque `hasMore` segue true.
        setState(() => _loadMoreFailed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Não foi possível carregar mais posts.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vote(String postId, int value) async {
    if (_anonymousId == null) return;
    try {
      final data =
          await _api.votePost(postId, value, anonymousId: _anonymousId!);
      final updated = PostSummary.fromJson(data);
      _session.updatePost(updated);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar seu voto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return AppScaffold(
      title: 'FÓRUM POLÍTICO',
      subtitle: 'discussão anônima',
      actions: [
        IconButton(
          icon: const Icon(
            Icons.search_rounded,
            color: AppTheme.onSurfaceVariant,
          ),
          onPressed: () {},
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
          if (created == true) _loadPage(1);
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: AppTheme.background,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          'POSTAR',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
      ),
      body: Column(
        children: [
          _buildSortBar(),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          Expanded(
            child: _loading && feed.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _failed && feed.isEmpty
                    ? _FeedMessage(
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppTheme.error,
                        title: 'Não foi possível carregar o fórum',
                        body: 'Verifique sua conexão e tente novamente.',
                        action: OutlinedButton(
                          onPressed: () => _loadPage(1),
                          child: const Text('TENTAR DE NOVO'),
                        ),
                      )
                    : feed.isEmpty
                        ? const _FeedMessage(
                            icon: Icons.forum_outlined,
                            iconColor: AppTheme.surfaceContainerHighest,
                            title: 'Nenhum post por aqui ainda',
                            body: 'Seja o primeiro a começar uma discussão.',
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadPage(1),
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount:
                                  feed.length + (_session.hasMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index == feed.length) {
                                  // Se a paginacao falhou, o rodape vira um botao em
                                  // vez de um spinner que nunca terminaria.
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _loadMoreFailed
                                          ? OutlinedButton(
                                              onPressed: () => _loadPage(
                                                  _session.currentPage + 1),
                                              child:
                                                  const Text('CARREGAR MAIS'),
                                            )
                                          : const CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final post = feed[index];
                                return PostCard(
                                  post: post,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PostDetailPage(postId: post.id),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  onVote: (value) => _vote(post.id, value),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _SortChip(
            label: '🔥  Quente',
            selected: _sort == _SortMode.quente,
            onTap: () {
              if (_sort != _SortMode.quente) {
                setState(() => _sort = _SortMode.quente);
                _loadPage(1);
              }
            },
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: '✨  Recente',
            selected: _sort == _SortMode.recente,
            onTap: () {
              if (_sort != _SortMode.recente) {
                setState(() => _sort = _SortMode.recente);
                _loadPage(1);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.background : AppTheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Mensagem centralizada de estado vazio ou de erro, no mesmo molde que a tela
/// de noticias usa em `news_states.dart`.
class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
