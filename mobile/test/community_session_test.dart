import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';

PostSummary _post(String id, int score) => PostSummary(
      id: id,
      anonymousId: 'a',
      content: 'x',
      score: score,
      createdAt: DateTime.now(),
    );

void main() {
  setUp(() => CommunitySession().invalidate());

  test('setFeed populates feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    expect(CommunitySession().feed.length, 1);
  });

  test('appendFeed adds to existing', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: true, page: 1);
    CommunitySession().appendFeed([_post('p2', 0)], hasMore: false, page: 2);
    expect(CommunitySession().feed.length, 2);
  });

  test('invalidate clears feed', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    CommunitySession().invalidate();
    expect(CommunitySession().feed, isEmpty);
  });

  test('updatePost replaces post', () {
    CommunitySession().setFeed([_post('p1', 0)], hasMore: false, page: 1);
    CommunitySession().updatePost(_post('p1', 5));
    expect(CommunitySession().feed.first.score, 5);
  });
}
