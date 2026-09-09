import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/create_post_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _tema(int id, String slug, String nome) => {
      'id': id,
      'slug': slug,
      'nome': nome,
      'area': 'social',
      'descricao': null,
      'icone_slug': null,
      'total_teses_aprovadas': 4,
    };

class _StubClient extends http.BaseClient {
  final List<Map<String, dynamic>> posted = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/themes')) {
      final body = jsonEncode([
        _tema(1, 'economia', 'Economia'),
        _tema(2, 'saude', 'Saúde'),
      ]);
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final raw = await (request as http.Request).finalize().bytesToString();
    posted.add(jsonDecode(raw) as Map<String, dynamic>);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{}')),
      201,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

Future<void> _pump(WidgetTester tester, _StubClient client) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: CreatePostPage(
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
  });

  testWidgets('explica o alias publico sem exibir o identificador privado',
      (tester) async {
    await _pump(tester, _StubClient());

    expect(find.text('Publicação anônima'), findsOneWidget);
    expect(find.textContaining('apelido público'), findsOneWidget);
    expect(find.textContaining('u/'), findsNothing);
  });

  testWidgets('avisa sobre a verificacao automatica', (tester) async {
    await _pump(tester, _StubClient());

    expect(find.textContaining('verificação automática'), findsOneWidget);
  });

  testWidgets('lista os temas vindos da api', (tester) async {
    await _pump(tester, _StubClient());

    expect(find.text('ECONOMIA'), findsOneWidget);
    expect(find.text('SAÚDE'), findsOneWidget);
  });

  testWidgets('tema selecionado vai no corpo da publicacao', (tester) async {
    final client = _StubClient();
    await _pump(tester, client);

    await tester.enterText(find.byType(TextField), 'Um post sobre economia');
    await tester.tap(find.text('ECONOMIA'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.posted.single['theme_slug'], 'economia');
  });

  testWidgets('sem tema selecionado nao envia theme_slug', (tester) async {
    final client = _StubClient();
    await _pump(tester, client);

    await tester.enterText(find.byType(TextField), 'Um post sem tema');
    // O botao so habilita depois do setState do onChanged.
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.posted.single.containsKey('theme_slug'), isFalse);
  });
}
