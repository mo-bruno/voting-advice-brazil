import 'models/community_models.dart';

class CommunitySession {
  static final CommunitySession _instance = CommunitySession._();
  factory CommunitySession() => _instance;
  CommunitySession._();

  List<PostSummary> _feed = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final Map<String, int> _postRevisions = {};
  final Map<String, PostSummary> _updatedPosts = {};

  List<PostSummary> get feed => List.unmodifiable(_feed);
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  Map<String, int> get postRevisions => Map.unmodifiable(_postRevisions);
  PostSummary? updatedPost(String id) => _updatedPosts[id];

  void setFeed(List<PostSummary> posts,
      {required bool hasMore, required int page}) {
    _feed = posts;
    _hasMore = hasMore;
    _currentPage = page;
  }

  void appendFeed(List<PostSummary> posts,
      {required bool hasMore, required int page}) {
    _feed = [..._feed, ...posts];
    _hasMore = hasMore;
    _currentPage = page;
  }

  void invalidate() {
    _feed = [];
    _currentPage = 1;
    _hasMore = true;
    _postRevisions.clear();
    _updatedPosts.clear();
  }

  void updatePost(PostSummary updated) {
    _updatedPosts[updated.id] = updated;
    _postRevisions.update(updated.id, (revision) => revision + 1,
        ifAbsent: () => 1);
    _feed = _feed.map((p) => p.id == updated.id ? updated : p).toList();
  }
}
