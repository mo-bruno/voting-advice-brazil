import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/theme/app_theme.dart';
import 'community_session.dart';
import 'create_post_page.dart';
import 'models/community_models.dart';
import 'post_detail_page.dart';
import 'widgets/post_card.dart';

enum _SortMode { quente, recente }

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final _session = CommunitySession();
  bool _loading = true;
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
        !_loading) {
      _loadPage(_session.currentPage + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_anonymousId == null) return;
    setState(() => _loading = true);
    final data = await ApiClient().listPosts(
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
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _vote(String postId, int value) async {
    if (_anonymousId == null) return;
    final data = await ApiClient()
        .votePost(postId, value, anonymousId: _anonymousId!);
    final updated = PostSummary.fromJson(data);
    _session.updatePost(updated);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fórum Político',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            Text(
              'discussão anônima',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
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
                : RefreshIndicator(
                    onRefresh: () => _loadPage(1),
                    child: ListView.separated(
                      controller: _scrollController,
                      itemCount: feed.length + (_session.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == feed.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
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
                                builder: (_) => PostDetailPage(postId: post.id),
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
