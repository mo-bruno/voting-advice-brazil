import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingClient extends http.BaseClient {
  final List<Uri> uris = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    uris.add(request.url);
    final body = jsonEncode({'posts': <dynamic>[], 'has_next': false});
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Future<void> _pump(WidgetTester tester, _RecordingClient client) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: CommunityFeedPage(
      apiClient: ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    CommunitySession().invalidate();
  });

  testWidgets('nao ha icone de busca inerte', (tester) async {
    await _pump(tester, _RecordingClient());

    // O icone existia com onPressed vazio. Controle que nao faz nada sai.
    expect(find.byIcon(Icons.search_rounded), findsNothing);
  });

  testWidgets('mostra as duas abas de ordenacao', (tester) async {
    await _pump(tester, _RecordingClient());

    expect(find.text('MAIS VOTADOS'), findsOneWidget);
    expect(find.text('RECENTES'), findsOneWidget);
  });

  testWidgets('trocar de aba refaz a busca com o sort correspondente',
      (tester) async {
    final client = _RecordingClient();
    await _pump(tester, client);
    final antes = client.uris.length;

    await tester.tap(find.text('RECENTES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.uris.length, greaterThan(antes));
    expect(client.uris.last.queryParameters['sort'], 'recent');
  });

  testWidgets('a primeira carga pede a ordenacao por pontuacao',
      (tester) async {
    final client = _RecordingClient();
    await _pump(tester, client);

    expect(client.uris.first.queryParameters['sort'], 'score');
  });

  testWidgets('o botao de publicar e ancorado, nao flutuante', (tester) async {
    await _pump(tester, _RecordingClient());

    // O FAB cobria o ultimo card e disputa o canto com a barra de navegacao.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('ESCREVER UM POST'), findsOneWidget);
  });
}
