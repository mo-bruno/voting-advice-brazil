import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';

void main() {
  group('PostSummary.fromJson', () {
    test('post parses public author metadata without a credential', () {
      final json = {
        'id': 'abc',
        'author_alias': 'u/abc123def0',
        'is_mine': true,
        'content': 'Texto',
        'political_actor_id': null,
        'theme_slug': null,
        'score': 3,
        'created_at': '2026-05-30T10:00:00Z',
      };
      final post = PostSummary.fromJson(json);
      expect(post.id, 'abc');
      expect(post.score, 3);
      expect(post.authorAlias, 'u/abc123def0');
      expect(post.isMine, isTrue);
    });
  });

  group('PostDetail.fromJson', () {
    test('parses post and comments', () {
      final json = {
        'post': {
          'id': 'p1',
          'author_alias': 'u/abc123def0',
          'is_mine': false,
          'content': 'x',
          'political_actor_id': null,
          'theme_slug': null,
          'score': 0,
          'created_at': '2026-05-30T10:00:00Z',
        },
        'comments': [
          {
            'id': 'c1',
            'post_id': 'p1',
            'author_alias': 'u/def456abc0',
            'is_mine': true,
            'content': 'ótimo',
            'created_at': '2026-05-30T10:01:00Z',
          }
        ],
      };
      final detail = PostDetail.fromJson(json);
      expect(detail.post.id, 'p1');
      expect(detail.comments.length, 1);
      expect(detail.post.authorAlias, 'u/abc123def0');
      expect(detail.post.isMine, isFalse);
      expect(detail.comments.single.authorAlias, 'u/def456abc0');
      expect(detail.comments.single.isMine, isTrue);
    });
  });
}
