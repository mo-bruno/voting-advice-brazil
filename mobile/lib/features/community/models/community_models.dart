class PostSummary {
  final String id;
  final String anonymousId;
  final String content;
  final int? politicalActorId;
  final String? themeSlug;
  final int score;
  final bool hasImage;
  final DateTime createdAt;

  const PostSummary({
    required this.id,
    required this.anonymousId,
    required this.content,
    this.politicalActorId,
    this.themeSlug,
    required this.score,
    required this.hasImage,
    required this.createdAt,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) => PostSummary(
        id: json['id'] as String,
        anonymousId: json['anonymous_id'] as String,
        content: json['content'] as String,
        politicalActorId: json['political_actor_id'] as int?,
        themeSlug: json['theme_slug'] as String?,
        score: json['score'] as int,
        hasImage: json['has_image'] as bool? ?? false,
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

  PostComment copyWith({String? content}) => PostComment(
        id: id,
        postId: postId,
        anonymousId: anonymousId,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}

class PostDetail {
  final PostSummary post;
  final String? imageData;
  final List<PostComment> comments;

  const PostDetail({
    required this.post,
    this.imageData,
    required this.comments,
  });

  factory PostDetail.fromJson(Map<String, dynamic> json) {
    final postJson = json['post'] as Map<String, dynamic>;
    return PostDetail(
      post: PostSummary.fromJson(postJson),
      imageData: postJson['image_data'] as String?,
      comments: (json['comments'] as List)
          .map((c) => PostComment.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
