import 'models/community_models.dart';

class CommunitySession {
  static final CommunitySession _instance = CommunitySession._();
  factory CommunitySession() => _instance;
  CommunitySession._();

  List<PostSummary> _feed = [];
  int _currentPage = 1;
  bool _hasMore = true;

  List<PostSummary> get feed => List.unmodifiable(_feed);
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;

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
  }

  void updatePost(PostSummary updated) {
    _feed = _feed.map((p) => p.id == updated.id ? updated : p).toList();
  }
}
