import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:guia_eleitoral/features/community/widgets/post_card.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _post(String id) => {
      'id': id,
      'anonymous_id': 'anon-1',
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

Widget _app(ApiClient api) => MaterialApp(
      theme: AppTheme.dark,
      home: CommunityFeedPage(apiClient: api),
    );

ApiClient _api(http.BaseClient client) =>
    ApiClient(baseUrl: 'https://api.test/api/v1', client: client);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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
    final stub = _StubClient({'posts': <dynamic>[], 'has_next': false});
    await tester.pumpWidget(_app(_api(stub)));
    await _settle(tester);

    expect(find.textContaining('Nenhum post'), findsOneWidget);
    expect(find.text('TENTAR DE NOVO'), findsNothing);
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
}
