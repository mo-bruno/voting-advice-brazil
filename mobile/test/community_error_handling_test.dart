import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/post_detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/analytics_test_support.dart';

Map<String, dynamic> _post() => {
      'id': 'p1',
      'author_alias': 'u/abc123def0',
      'is_mine': false,
      'content': 'Conteúdo público',
      'political_actor_id': null,
      'theme_slug': null,
      'score': 3,
      'created_at': '2026-09-04T12:00:00Z',
    };

http.Response _response(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient _api(Future<http.Response> Function(http.Request request) handler) =>
    ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: MockClient(handler),
    );

List<RecordedAnalyticsCall> _detailOperations(RecordingAnalyticsSink sink) =>
    named(sink.calls, 'operation_result')
        .where(
          (call) => call.parameters?['operation'] == 'community_post_load',
        )
        .toList();

/// A feature de comunidade chamava a API sem tratar falha em quatro pontos.
/// Em teste de widget o HttpClient devolve 400, o que reproduz exatamente a
/// falha de rede que o usuario veria com o backend fora do ar.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('detalhe do post mostra erro em vez de girar para sempre',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDetailPage(postId: 'qualquer'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Antes: `_loading` nunca virava false e a tela girava indefinidamente.
    // Adicionar so um `finally` seria pior — o build faz `_detail!.post` e
    // passaria a crashar. Por isso o estado de erro tem de existir.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Não foi possível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe do post permite tentar de novo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDetailPage(postId: 'qualquer'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TENTAR DE NOVO'), findsOneWidget);

    await tester.tap(find.text('TENTAR DE NOVO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('feed da comunidade nao estoura quando a api falha',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const CommunityFeedPage(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe distingue carga inicial, retry e refresh',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    var calls = 0;
    final client = _api((_) async {
      calls++;
      if (calls == 1) return _response({'detail': 'privado'}, 500);
      return _response({'post': _post(), 'comments': <dynamic>[]});
    });
    await tester.pumpWidget(MaterialApp(
      home: PostDetailPage(
        postId: 'p1',
        apiClient: client,
        analytics: AnalyticsService(sink: sink),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('TENTAR DE NOVO'));
    await tester.pumpAndSettle();
    tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pumpAndSettle();

    final operations = _detailOperations(sink);
    expect(
      operations.map((call) => call.parameters!['trigger']),
      ['initial', 'retry', 'refresh'],
    );
    expect(
      operations.map((call) => call.parameters!['outcome']),
      ['failed', 'success', 'success'],
    );
    expect(operations[1].parameters!['item_count'], 0);
  });
}
