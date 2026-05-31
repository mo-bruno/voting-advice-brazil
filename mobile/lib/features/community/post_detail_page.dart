import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import 'community_session.dart';
import 'models/community_models.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  PostDetail? _detail;
  bool _loading = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
    final data = await ApiClient()
        .getPost(widget.postId, anonymousId: anonymousId);
    if (mounted) {
      setState(() {
        _detail = PostDetail.fromJson(data);
        _loading = false;
      });
    }
  }

  Future<void> _vote(int value) async {
    final anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
    final data = await ApiClient()
        .votePost(widget.postId, value, anonymousId: anonymousId);
    final updated = PostSummary.fromJson(data);
    CommunitySession().updatePost(updated);
    if (mounted) {
      setState(() {
        _detail = PostDetail(post: updated, comments: _detail!.comments);
      });
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
    final data = await ApiClient()
        .createComment(widget.postId, content, anonymousId: anonymousId);
    final comment = PostComment.fromJson(data);
    _commentController.clear();
    if (mounted) {
      setState(() {
        _detail = PostDetail(
          post: _detail!.post,
          comments: [..._detail!.comments, comment],
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final post = _detail!.post;
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  post.content,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up_outlined),
                      onPressed: () => _vote(1),
                    ),
                    Text('${post.score}'),
                    IconButton(
                      icon: const Icon(Icons.thumb_down_outlined),
                      onPressed: () => _vote(-1),
                    ),
                  ],
                ),
                const Divider(),
                ..._detail!.comments.map(
                  (c) => ListTile(
                    title: Text(c.content),
                    subtitle: Text(c.createdAt.toLocal().toString()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar comentário...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
