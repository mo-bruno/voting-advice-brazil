import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import 'community_session.dart';
import 'create_post_page.dart';
import 'models/community_models.dart';
import 'post_detail_page.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final _session = CommunitySession();
  bool _loading = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    setState(() => _loading = true);
    final anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
    final data = await ApiClient().listPosts(
      anonymousId: anonymousId,
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

  @override
  Widget build(BuildContext context) {
    final feed = _session.feed;
    return Scaffold(
      appBar: AppBar(title: const Text('Comunidade')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
          if (created == true) _loadPage(1);
        },
        child: const Icon(Icons.edit),
      ),
      body: _loading && feed.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPage(1),
              child: ListView.separated(
                controller: _scrollController,
                itemCount: feed.length + (_session.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
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
                  return ListTile(
                    title: Text(
                      post.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Score: ${post.score}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailPage(postId: post.id),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
