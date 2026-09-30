import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/community/post_detail_page.dart';
import 'package:guia_eleitoral/features/community/community_processing_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RemovedPostApi extends ApiClient {
  _RemovedPostApi() : super(baseUrl: 'https://example.test');

  @override
  Future<Map<String, dynamic>> getPost(
    String postId, {
    required String anonymousId,
  }) async =>
      {
        'post': {
          'id': postId,
          'author_alias': 'u/abc123def0',
          'is_mine': true,
          'content': '',
          'political_actor_id': null,
          'theme_slug': null,
          'score': 3,
          'created_at': '2026-09-09T12:00:00Z',
          'removed': true,
          'removed_by': 'moderation',
        },
        'comments': [
          {
            'id': 'c1',
            'post_id': postId,
            'author_alias': 'u/9876543210',
            'is_mine': false,
            'content': 'Comentário anterior preservado.',
            'created_at': '2026-09-09T12:01:00Z',
          },
        ],
      };
}

class _ActivePostApi extends ApiClient {
  _ActivePostApi() : super(baseUrl: 'https://example.test');

  @override
  Future<Map<String, dynamic>> getPost(
    String postId, {
    required String anonymousId,
  }) async =>
      {
        'post': {
          'id': postId,
          'author_alias': 'u/abc123def0',
          'is_mine': true,
          'content': 'Texto público',
          'political_actor_id': null,
          'theme_slug': null,
          'score': 0,
          'created_at': '2026-09-09T12:00:00Z',
          'removed': false,
          'removed_by': null,
        },
        'comments': [],
      };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'farol_politico_device_id': 'a3f9c21b-0000-4000-8000-000000000000',
    });
  });

  testWidgets('detalhe removido mostra lapide e desativa novas interacoes',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PostDetailPage(postId: 'p1', apiClient: _RemovedPostApi()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Removido pela moderação'), findsOneWidget);
    expect(find.text('Comentário anterior preservado.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets('comment notice precedes reachable send action at 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: const TextScaler.linear(2),
      ),
      child: MaterialApp(
        home: PostDetailPage(postId: 'p1', apiClient: _ActivePostApi()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CommunityProcessingNotice), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Uma opinião');
    await tester.pump();
    final send = find.byTooltip('Enviar comentário');
    expect(send, findsOneWidget);
    await tester.ensureVisible(send);
    await tester.pump();
    expect(send.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
