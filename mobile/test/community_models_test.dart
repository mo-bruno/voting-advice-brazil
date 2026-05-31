import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';

void main() {
  group('PostSummary.fromJson', () {
    test('parses all fields', () {
      final json = {
        'id': 'abc',
        'anonymous_id': 'anon-1',
        'content': 'Texto',
        'political_actor_id': null,
        'theme_slug': null,
        'score': 3,
        'created_at': '2026-05-30T10:00:00Z',
      };
      final post = PostSummary.fromJson(json);
      expect(post.id, 'abc');
      expect(post.score, 3);
    });
  });

  group('PostDetail.fromJson', () {
    test('parses post and comments', () {
      final json = {
        'post': {
          'id': 'p1',
          'anonymous_id': 'a',
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
            'anonymous_id': 'a',
            'content': 'ótimo',
            'created_at': '2026-05-30T10:01:00Z',
          }
        ],
      };
      final detail = PostDetail.fromJson(json);
      expect(detail.post.id, 'p1');
      expect(detail.comments.length, 1);
    });
  });
}
