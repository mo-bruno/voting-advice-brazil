import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:guia_eleitoral/features/community/widgets/post_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/analytics_test_support.dart';

Map<String, dynamic> _post(String id) => {
      'id': id,
      'author_alias': 'u/abc123def0',
      'is_mine': false,
      'content': 'Conteudo do post $id',
      'political_actor_id': null,
      'theme_slug': null,
      'score': 3,
      'created_at': '2026-09-04T12:00:00Z',
    };

class _StubClient extends http.BaseClient {
  _StubClient(this.body, {this.status = 200});

  final Object body;
  final int status;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Widget _app(ApiClient api, {RecordingAnalyticsSink? sink}) => MaterialApp(
      theme: AppTheme.dark,
      home: CommunityFeedPage(
        apiClient: api,
        analytics: sink == null ? null : AnalyticsService(sink: sink),
      ),
    );

ApiClient _api(http.BaseClient client) =>
    ApiClient(baseUrl: 'https://api.test/api/v1', client: client);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

http.Response _response(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient _mockApi(
  FutureOr<http.Response> Function(http.Request request) handler,
) =>
    _api(MockClient((request) async => handler(request)));

List<RecordedAnalyticsCall> _feedOperations(RecordingAnalyticsSink sink) =>
    named(sink.calls, 'operation_result')
        .where(
          (call) => call.parameters?['operation'] == 'community_feed_load',
        )
        .toList();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // A session e singleton e guarda o feed entre testes.
    CommunitySession().invalidate();
  });

  testWidgets('falha na primeira pagina mostra erro com retry', (tester) async {
    final stub = _StubClient({'detail': 'boom'}, status: 500);
    await tester.pumpWidget(_app(_api(stub)));
    await _settle(tester);

    // Antes desta correcao a falha virava "feed vazio": sem mensagem, sem
    // como tentar de novo, indistinguivel de uma comunidade sem posts.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Não foi possível'), findsOneWidget);
    expect(find.text('TENTAR DE NOVO'), findsOneWidget);
  });

  testWidgets('tentar de novo refaz a chamada', (tester) async {
    final stub = _StubClient({'detail': 'boom'}, status: 500);
    await tester.pumpWidget(_app(_api(stub)));
    await _settle(tester);
    final antes = stub.calls;

    await tester.tap(find.text('TENTAR DE NOVO'));
    await _settle(tester);

    expect(stub.calls, greaterThan(antes));
  });

  testWidgets('feed vazio e distinguivel de erro', (tester) async {
    final sink = RecordingAnalyticsSink();
    final stub = _StubClient({'posts': <dynamic>[], 'has_next': false});
    await tester.pumpWidget(_app(_api(stub), sink: sink));
    await _settle(tester);

    expect(find.textContaining('Nenhum post'), findsOneWidget);
    expect(find.text('TENTAR DE NOVO'), findsNothing);
    expect(
      _feedOperations(sink).single.parameters,
      allOf(
        containsPair('operation', 'community_feed_load'),
        containsPair('outcome', 'empty'),
        containsPair('trigger', 'initial'),
        containsPair('item_count', 0),
      ),
    );
  });

  testWidgets('feed com posts renderiza os cards', (tester) async {
    final stub = _StubClient({
      'posts': [_post('a'), _post('b')],
      'has_next': false,
    });
    await tester.pumpWidget(_app(_api(stub)));
    await _settle(tester);

    expect(find.byType(PostCard), findsNWidgets(2));
    expect(find.textContaining('Não foi possível'), findsNothing);
    expect(find.textContaining('Nenhum post'), findsNothing);
  });

  testWidgets('retry e paginação preservam o gatilho de cada tentativa',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    var firstPageCalls = 0;
    final api = _mockApi((request) {
      final page = request.url.queryParameters['page'];
      if (page == '1' && firstPageCalls++ == 0) {
        return _response({'detail': 'falha privada'}, 500);
      }
      if (page == '1') {
        return _response({
          'posts': [for (var i = 0; i < 10; i++) _post('p$i')],
          'has_next': true,
        });
      }
      return _response({
        'posts': [_post('pagina-2')],
        'has_next': false,
      });
    });

    await tester.pumpWidget(_app(api, sink: sink));
    await _settle(tester);
    await tester.tap(find.text('TENTAR DE NOVO'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    final operations = _feedOperations(sink);
    expect(
      operations.map((call) => call.parameters!['trigger']),
      ['initial', 'retry', 'pagination'],
    );
    expect(
      operations.map((call) => call.parameters!['outcome']),
      ['failed', 'success', 'success'],
    );
    expect(operations.last.parameters!['item_count'], 1);
  });

  testWidgets('refresh que supera carga antiga emite stale exatamente uma vez',
      (tester) async {
    final old = Completer<http.Response>();
    final sink = RecordingAnalyticsSink();
    final api = _mockApi((request) {
      if (request.url.queryParameters['sort'] == 'score') return old.future;
      return _response({
        'posts': [_post('recente')],
        'has_next': false,
      });
    });

    await tester.pumpWidget(_app(api, sink: sink));
    await _settle(tester);
    await tester.tap(find.text('RECENTES'));
    await _settle(tester);
    old.complete(_response({
      'posts': [_post('antigo')],
      'has_next': false,
    }));
    await tester.pumpAndSettle();

    final operations = _feedOperations(sink);
    expect(
      operations.map((call) => call.parameters!['outcome']),
      ['success', 'stale'],
    );
    expect(
      operations.where((call) => call.parameters!['outcome'] == 'stale'),
      hasLength(1),
    );
    expect(operations.last.parameters, isNot(contains('failure_type')));
  });

  testWidgets('carga pendente termina como stale depois do unmount',
      (tester) async {
    final pending = Completer<http.Response>();
    final sink = RecordingAnalyticsSink();
    final api = _mockApi((_) => pending.future);

    await tester.pumpWidget(_app(api, sink: sink));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(_response({
      'posts': [_post('ignorado')],
      'has_next': false,
    }));
    await tester.pump();

    final operation = _feedOperations(sink).single;
    expect(
      operation.parameters,
      allOf(
        containsPair('operation', 'community_feed_load'),
        containsPair('outcome', 'stale'),
        containsPair('trigger', 'initial'),
      ),
    );
  });
}
