import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/theme/app_theme.dart';
import 'community_session.dart';
import 'models/community_models.dart';
import 'utils/community_utils.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  PostDetail? _detail;
  bool _loading = true;
  bool _sendingComment = false;
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
    final data =
        await ApiClient().getPost(widget.postId, anonymousId: anonymousId);
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
    setState(() => _sendingComment = true);
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
        _sendingComment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final post = _detail!.post;
    final comments = _detail!.comments;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          '${comments.length} comentário${comments.length != 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _PostBody(post: post, onVote: _vote),
                const SizedBox(height: 8),
                if (comments.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'COMENTÁRIOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ...comments.map((c) => _CommentTile(comment: c)),
                const SizedBox(height: 80),
              ],
            ),
          ),
          _CommentInput(
            controller: _commentController,
            sending: _sendingComment,
            onSend: _addComment,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  final PostSummary post;
  final void Function(int value) onVote;

  const _PostBody({required this.post, required this.onVote});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surfaceContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(anonymousId: post.anonymousId, createdAt: post.createdAt),
          const SizedBox(height: 12),
          Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
          if (post.themeSlug != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.outlineVariant),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                post.themeSlug!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _VoteRow(score: post.score, onVote: onVote),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String anonymousId;
  final DateTime createdAt;

  const _AuthorRow({required this.anonymousId, required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: avatarColor(anonymousId),
          child: Text(
            avatarInitials(anonymousId),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shortUsername(anonymousId),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              timeAgo(createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VoteRow extends StatelessWidget {
  final int score;
  final void Function(int value) onVote;

  const _VoteRow({required this.score, required this.onVote});

  Color get _scoreColor {
    if (score > 0) return const Color(0xFFFF6314);
    if (score < 0) return const Color(0xFF7193FF);
    return AppTheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoteButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => onVote(1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor,
                  ),
                ),
              ),
              _VoteButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => onVote(-1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _VoteButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 20, color: AppTheme.onSurfaceVariant),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: avatarColor(comment.anonymousId),
                child: Text(
                  avatarInitials(comment.anonymousId),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                shortUsername(comment.anonymousId),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Text(
                  '·',
                  style:
                      TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
              Text(
                timeAgo(comment.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(comment.content, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onChanged;

  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Adicionar comentário...',
                  hintStyle: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onChanged: (_) => onChanged(),
                onSubmitted: (_) {
                  if (controller.text.trim().isNotEmpty && !sending) {
                    onSend();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            sending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: controller.text.trim().isEmpty
                        ? AppTheme.onSurfaceVariant
                        : AppTheme.primary,
                    onPressed:
                        controller.text.trim().isEmpty ? null : onSend,
                  ),
          ],
        ),
      ),
    );
  }
}
