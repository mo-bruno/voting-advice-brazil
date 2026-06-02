class PostSummary {
  final String id;
  final String anonymousId;
  final String content;
  final int? politicalActorId;
  final String? themeSlug;
  final int score;
  final DateTime createdAt;

  const PostSummary({
    required this.id,
    required this.anonymousId,
    required this.content,
    this.politicalActorId,
    this.themeSlug,
    required this.score,
    required this.createdAt,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) => PostSummary(
        id: json['id'] as String,
        anonymousId: json['anonymous_id'] as String,
        content: json['content'] as String,
        politicalActorId: json['political_actor_id'] as int?,
        themeSlug: json['theme_slug'] as String?,
        score: json['score'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PostComment {
  final String id;
  final String postId;
  final String anonymousId;
  final String content;
  final DateTime createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.anonymousId,
    required this.content,
    required this.createdAt,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        anonymousId: json['anonymous_id'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
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
