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

enum _SortMode {
  votados('score'),
  recentes('recent');

  const _SortMode(this.apiValue);

  /// O valor que o backend entende. Antes desta entrega o enum existia mas
  /// nunca chegava ao servidor: as abas eram decorativas.
  final String apiValue;
}

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

  /// Posts com voto em voo. Sem isto cada toque na seta disparava uma
  /// requisicao nova, concorrente com a anterior.
  final Set<String> _voting = {};
  String? _anonymousId;
  _SortMode _sort = _SortMode.votados;
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
        sort: _sort.apiValue,
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
    if (_anonymousId == null || _voting.contains(postId)) return;
    setState(() => _voting.add(postId));
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
    } finally {
      if (mounted) setState(() => _voting.remove(postId));
    }
  }

  Future<void> _reportPost(String postId) async {
    final id = _anonymousId;
    if (id == null) return;
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => const _ReportSheet(),
    );
    if (motivo == null) return;
    try {
      await _api.reportPost(postId, reason: motivo, anonymousId: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denúncia registrada. Obrigado.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a denúncia.')),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final id = _anonymousId;
    if (id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Apagar este post?'),
        content: const Text(
          'O texto some, mas os comentários das outras pessoas continuam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('APAGAR'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _api.deletePost(postId, anonymousId: id);
      await _loadPage(1);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível apagar o post.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return AppScaffold(
      title: 'FÓRUM POLÍTICO',
      subtitle: 'discussão anônima',
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
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: AppTheme.outlineVariant,
                              ),
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
                                  onReport: () => _reportPost(post.id),
                                  onDelete: () => _deletePost(post.id),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostPage()),
                  );
                  if (created == true) _loadPage(1);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, size: 17),
                    SizedBox(width: 10),
                    Text('ESCREVER UM POST'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SortTab(
            label: 'MAIS VOTADOS',
            selected: _sort == _SortMode.votados,
            onTap: () => _changeSort(_SortMode.votados),
          ),
          const SizedBox(width: 24),
          _SortTab(
            label: 'RECENTES',
            selected: _sort == _SortMode.recentes,
            onTap: () => _changeSort(_SortMode.recentes),
          ),
        ],
      ),
    );
  }

  void _changeSort(_SortMode modo) {
    if (_sort == modo) return;
    setState(() => _sort = modo);
    _loadPage(1);
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color:
                      selected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 2,
              color: selected ? AppTheme.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

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

class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  static const _motivos = <String, String>{
    'desinformacao': 'Desinformação',
    'discurso_de_odio': 'Discurso de ódio',
    'spam': 'Spam',
    'outro': 'Outro',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'POR QUE DENUNCIAR?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final e in _motivos.entries)
            ListTile(
              title: Text(
                e.value,
                style: const TextStyle(color: AppTheme.onSurface),
              ),
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      ),
    );
  }
}
