import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/create_post_page.dart';
import 'package:guia_eleitoral/features/community/community_processing_notice.dart';
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
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('explica o alias publico sem exibir o identificador privado',
      (tester) async {
    await _pump(tester, _StubClient());

    expect(find.text('Publicação sob alias pseudônimo'), findsOneWidget);
    expect(find.textContaining('alias público estável'), findsOneWidget);
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
    await tester.ensureVisible(find.text('PUBLICAR'));
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
    await tester.ensureVisible(find.text('PUBLICAR'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(client.posted.single.containsKey('theme_slug'), isFalse);
  });

  testWidgets('notice directly precedes reachable publication action at 200%',
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
        theme: AppTheme.dark,
        home: CreatePostPage(
          apiClient: ApiClient(
            baseUrl: 'https://api.test/api/v1',
            client: _StubClient(),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'Uma opinião política');
    await tester.pump();
    final notice = find.byType(CommunityProcessingNotice);
    final button = find.widgetWithText(ElevatedButton, 'PUBLICAR');
    expect(notice, findsOneWidget);
    expect(button, findsOneWidget);
    expect(find.widgetWithText(TextButton, 'PUBLICAR'), findsNothing);
    final containingColumns = find
        .ancestor(of: notice, matching: find.byType(Column))
        .evaluate()
        .map((element) => element.widget)
        .whereType<Column>();
    expect(
      containingColumns.any((column) {
        final index = column.children.indexWhere(
          (child) => child is CommunityProcessingNotice,
        );
        return index >= 0 &&
            index + 2 < column.children.length &&
            column.children[index + 1] is SizedBox &&
            column.children[index + 2] is ElevatedButton;
      }),
      isTrue,
    );
    await tester.ensureVisible(button);
    await tester.pump();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
