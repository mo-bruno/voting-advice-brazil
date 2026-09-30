class PostSummary {
  final String id;
  final String authorAlias;
  final bool isMine;
  final String content;
  final int? politicalActorId;
  final String? themeSlug;
  final String? themeName;
  final int score;
  final int myVote;
  final int commentCount;
  final DateTime createdAt;
  final bool removed;
  final String? removedBy;

  const PostSummary({
    required this.id,
    required this.authorAlias,
    required this.isMine,
    required this.content,
    this.politicalActorId,
    this.themeSlug,
    this.themeName,
    required this.score,
    this.myVote = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.removed = false,
    this.removedBy,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) => PostSummary(
        id: json['id'] as String,
        authorAlias: json['author_alias'] as String,
        isMine: json['is_mine'] as bool,
        content: json['content'] as String,
        politicalActorId: json['political_actor_id'] as int?,
        themeSlug: json['theme_slug'] as String?,
        themeName: json['theme_name'] as String?,
        score: json['score'] as int,
        myVote: json['my_vote'] as int? ?? 0,
        commentCount: json['comment_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        removed: json['removed'] as bool? ?? false,
        removedBy: json['removed_by'] as String?,
      );

  /// Texto exibido no lugar do conteudo quando o post foi removido.
  String get tombstoneLabel => removedBy == 'moderation'
      ? 'Removido pela moderação'
      : 'Removido pelo autor';

  String? get themeLabel {
    if (themeName != null && themeName!.trim().isNotEmpty) return themeName;
    if (themeSlug == null || themeSlug!.isEmpty) return null;
    // Mantém legíveis respostas de versões anteriores da API.
    final label = themeSlug!.replaceAll('_', ' ').replaceAll('-', ' ');
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  PostSummary copyWith({int? commentCount}) => PostSummary(
        id: id,
        authorAlias: authorAlias,
        isMine: isMine,
        content: content,
        politicalActorId: politicalActorId,
        themeSlug: themeSlug,
        themeName: themeName,
        score: score,
        myVote: myVote,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt,
        removed: removed,
        removedBy: removedBy,
      );
}

class PostComment {
  final String id;
  final String postId;
  final String authorAlias;
  final bool isMine;
  final String content;
  final DateTime createdAt;
  final bool removed;
  final String? removedBy;

  const PostComment({
    required this.id,
    required this.postId,
    required this.authorAlias,
    required this.isMine,
    required this.content,
    required this.createdAt,
    this.removed = false,
    this.removedBy,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        authorAlias: json['author_alias'] as String,
        isMine: json['is_mine'] as bool,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        removed: json['removed'] as bool? ?? false,
        removedBy: json['removed_by'] as String?,
      );

  String get tombstoneLabel => removedBy == 'moderation'
      ? 'Comentário removido pela moderação'
      : 'Comentário removido pelo autor';
}

class PostDetail {
  final PostSummary post;
  final List<PostComment> comments;

  const PostDetail({required this.post, required this.comments});

  factory PostDetail.fromJson(Map<String, dynamic> json) => PostDetail(
        post: PostSummary.fromJson(json['post'] as Map<String, dynamic>),
        comments: (json['comments'] as List)
            .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
