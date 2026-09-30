import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/create_post_page.dart';
import 'package:guia_eleitoral/features/community/models/community_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productionThemes = [
  ['economia_desenvolvimento', 'Economia e Desenvolvimento'],
  ['cidadania_direitos', 'Cidadania e Direitos'],
  ['estado_gestao', 'Estado e Gestão Pública'],
  ['bem_estar_social', 'Bem-Estar Social'],
  ['seguranca_publica', 'Segurança Pública'],
  ['soberania_relacoes_internacionais', 'Soberania e Relações Internacionais'],
  ['infraestrutura_territorio', 'Infraestrutura e Território'],
  ['meio_ambiente_clima', 'Meio Ambiente e Clima'],
  ['ciencia_tecnologia_inovacao', 'Ciência, Tecnologia e Inovação'],
  ['educacao_cultura_sociedade', 'Educação, Cultura e Sociedade'],
];

Map<String, Object?> _createdPost({String? theme}) => {
      'id': 'post-publicado',
      'author_alias': 'u/abc123def0',
      'is_mine': true,
      'content': 'Como melhorar a transparência dos gastos públicos?',
      'political_actor_id': null,
      'theme_slug': theme,
      'score': 0,
      'created_at': '2026-09-30T12:00:00Z',
      'removed': false,
      'removed_by': null,
    };

http.Response _response(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient _api(FutureOr<http.Response> Function(http.Request) write) =>
    ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/themes')) {
          return _response([
            for (var i = 0; i < _productionThemes.length; i++)
              {
                'id': i + 1,
                'slug': _productionThemes[i][0],
                'nome': _productionThemes[i][1],
                'area': 'social',
                'descricao': null,
                'icone_slug': null,
                'total_teses_aprovadas': 4,
              },
          ]);
        }
        return await write(request);
      }),
    );

Future<void> _mount(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: page,
  ));
  await tester.pumpAndSettle();
}

Future<void> _openEditor(
  WidgetTester tester,
  ApiClient api, {
  void Function(PostSummary?)? onResult,
  String? initialThemeSlug,
  Size size = const Size(390, 844),
  double keyboard = 0,
  double textScale = 1,
}) async {
  await _mount(
    tester,
    Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () async {
            final result = await Navigator.push<PostSummary>(
              context,
              MaterialPageRoute<PostSummary>(
                builder: (_) => CreatePostPage(
                  apiClient: api,
                  initialThemeSlug: initialThemeSlug,
                ),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('ABRIR EDITOR'),
        ),
      );
    }),
    size: size,
    keyboard: keyboard,
    textScale: textScale,
  );
  await tester.tap(find.text('ABRIR EDITOR'));
  await tester.pumpAndSettle();
}

Future<void> _publish(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.ensureVisible(find.text('PUBLICAR'));
  await tester.pump();
  await tester.tap(find.text('PUBLICAR'));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final scenario in [
    ('320x568', const Size(320, 568), 0.0, 1.0),
    ('360x640', const Size(360, 640), 0.0, 1.0),
    ('390x844', const Size(390, 844), 0.0, 1.0),
    ('360x640 teclado', const Size(360, 640), 300.0, 1.0),
    ('390x844 teclado', const Size(390, 844), 320.0, 1.0),
    ('320x568 texto ampliado', const Size(320, 568), 0.0, 1.3),
    ('390x844 texto 2x e teclado', const Size(390, 844), 320.0, 2.0),
  ]) {
    testWidgets('editor utilizável com dez temas em ${scenario.$1}',
        (tester) async {
      await _mount(
        tester,
        CreatePostPage(apiClient: _api((_) => _response(_createdPost(), 201))),
        size: scenario.$2,
        keyboard: scenario.$3,
        textScale: scenario.$4,
      );

      expect(tester.takeException(), isNull);
      final field = find.byType(TextField);
      expect(tester.getSize(field).height, greaterThanOrEqualTo(140));
      await tester.ensureVisible(field);
      await tester.enterText(
          field, 'Debate sobre políticas públicas brasileiras.');
      await tester.pumpAndSettle();
      final fieldRect = tester.getRect(field);
      final available = Rect.fromLTWH(
        0,
        56,
        scenario.$2.width,
        scenario.$2.height - scenario.$3 - 56,
      );
      expect(fieldRect.intersect(available).height, greaterThanOrEqualTo(100));
      await tester.ensureVisible(find.text('PUBLICAR'));
      await tester.pump();
      expect(find.text('PUBLICAR').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Sem tema'));
      await tester.tap(find.text('Sem tema'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Educação, Cultura e Sociedade'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Educação, Cultura e Sociedade').hitTestable(),
          findsOneWidget);
      await tester.tap(find.text('Educação, Cultura e Sociedade'));
      await tester.pumpAndSettle();
      expect(find.text('Tema da publicação'), findsNothing);
      expect(find.text('Educação, Cultura e Sociedade'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scenario in [
    (422, 'O texto não trata de política brasileira.', 'política brasileira'),
    (429, 'Too many publications.', 'Aguarde'),
    (503, 'Provider unavailable.', 'temporariamente indisponível'),
  ]) {
    testWidgets(
        'erro ${scenario.$1} explica o próximo passo e mantém o rascunho',
        (tester) async {
      await _mount(
        tester,
        CreatePostPage(
          apiClient:
              _api((_) => _response({'detail': scenario.$2}, scenario.$1)),
        ),
      );
      const draft = 'Como melhorar a transparência dos gastos públicos?';
      await _publish(tester, draft);
      await tester.pumpAndSettle();

      expect(
        scenario.$1 == 422
            ? find.text(scenario.$2)
            : find.textContaining(scenario.$3),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          draft);
      expect(
          tester
              .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'PUBLICAR'))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('publicar fica desabilitado para texto apenas em branco',
      (tester) async {
    await _mount(
      tester,
      CreatePostPage(apiClient: _api((_) => _response(_createdPost(), 201))),
    );
    await tester.enterText(find.byType(TextField), '   \n  ');
    await tester.pump();

    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'PUBLICAR'))
            .onPressed,
        isNull);
  });

  testWidgets('envio indica análise e bloqueia mudanças e publicação repetida',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    await _openEditor(tester, _api((_) {
      requests++;
      return pending.future;
    }));
    await tester.enterText(
        find.byType(TextField), 'Debate sobre educação pública.');
    await tester.pump();
    // Dois toques antes de a UI reconstruir não podem enviar dois posts.
    await tester.ensureVisible(find.text('PUBLICAR'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.tap(find.text('PUBLICAR'));
    await tester.pump();

    expect(requests, 1);
    expect(find.textContaining('análise'), findsWidgets);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    pending.complete(_response(_createdPost(), 201));
    await tester.pumpAndSettle();
    expect(find.text('ABRIR EDITOR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar durante análise mantém a tela até o resultado',
      (tester) async {
    final pending = Completer<http.Response>();
    await _openEditor(tester, _api((_) => pending.future));
    await _publish(tester, 'Debate sobre educação pública.');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(find.byType(CreatePostPage), findsOneWidget);
    expect(find.textContaining('Aguarde'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CreatePostPage), findsOneWidget);
    pending.complete(_response({'detail': 'Provider unavailable.'}, 503));
    await tester.pumpAndSettle();
    expect(find.textContaining('temporariamente indisponível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar pede confirmação e permite manter ou descartar rascunho',
      (tester) async {
    var writes = 0;
    await _openEditor(tester, _api((_) {
      writes++;
      return _response(_createdPost(), 201);
    }));
    await tester.enterText(
        find.byType(TextField), 'Debate sobre educação pública.');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.textContaining('Descartar'), findsWidgets);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Debate sobre educação pública.');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('ABRIR EDITOR'), findsOneWidget);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resposta 201 volta com o post publicado e o texto enviado',
      (tester) async {
    PostSummary? result;
    Map<String, dynamic>? payload;
    await _openEditor(tester, _api((request) {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _response(_createdPost(), 201);
    }), onResult: (post) => result = post);
    await _publish(
        tester, '  Como melhorar a transparência dos gastos públicos?  ');
    await tester.pumpAndSettle();

    expect(payload?['content'],
        'Como melhorar a transparência dos gastos públicos?');
    expect(result?.id, 'post-publicado');
    expect(result?.authorAlias, 'u/abc123def0');
    expect(result?.isMine, isTrue);
    expect(find.text('ABRIR EDITOR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resposta tardia depois de remover a tela não atualiza estado',
      (tester) async {
    final pending = Completer<http.Response>();
    await _openEditor(tester, _api((_) => pending.future));
    await _publish(tester, 'Debate sobre educação pública.');
    await tester.pumpWidget(
        MaterialApp(key: UniqueKey(), home: const Text('OUTRA TELA')));
    pending.complete(_response({'detail': 'Provider unavailable.'}, 503));
    await tester.pumpAndSettle();

    expect(find.text('OUTRA TELA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tema inicial carregado aparece pelo nome e vai na publicação',
      (tester) async {
    Map<String, dynamic>? payload;
    PostSummary? result;
    await _openEditor(
      tester,
      _api((request) {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return _response(
            _createdPost(theme: 'educacao_cultura_sociedade'), 201);
      }),
      initialThemeSlug: 'educacao_cultura_sociedade',
      onResult: (post) => result = post,
    );
    expect(find.text('Educação, Cultura e Sociedade'), findsOneWidget);
    await _publish(tester, 'Como melhorar a educação pública brasileira?');
    await tester.pumpAndSettle();

    expect(payload?['theme_slug'], 'educacao_cultura_sociedade');
    expect(result?.themeSlug, 'educacao_cultura_sociedade');
    expect(tester.takeException(), isNull);
  });

  testWidgets('tema inicial inexistente não vai na publicação', (tester) async {
    Map<String, dynamic>? payload;
    await _openEditor(
      tester,
      _api((request) {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return _response(_createdPost(), 201);
      }),
      initialThemeSlug: 'tema_obsoleto',
    );
    expect(find.text('Sem tema'), findsOneWidget);
    await _publish(tester, 'Como melhorar a educação pública brasileira?');
    await tester.pumpAndSettle();

    expect(payload?.containsKey('theme_slug'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('análise continua visível depois de rolar com teclado aberto',
      (tester) async {
    final pending = Completer<http.Response>();
    await _mount(
      tester,
      CreatePostPage(apiClient: _api((_) => pending.future)),
      size: const Size(360, 640),
      keyboard: 300,
    );
    await tester.enterText(
        find.byType(TextField), 'Debate sobre educação pública.');
    await tester.pump();
    await tester.ensureVisible(find.text('Sem tema'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('PUBLICAR'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator).hitTestable(), findsWidgets);
    pending.complete(_response({'detail': 'Provider unavailable.'}, 503));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'limite de 500 caracteres mantém o texto enviado dentro do contrato',
      (tester) async {
    Map<String, dynamic>? payload;
    await _openEditor(tester, _api((request) {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return _response({..._createdPost(), 'content': 'a' * 500}, 201);
    }));
    await _publish(tester, 'a' * 501);
    await tester.pumpAndSettle();

    expect(payload?['content'], 'a' * 500);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    ('320x568 texto 1.3x', const Size(320, 568), 300.0, 1.3),
    ('390x844 texto 2x', const Size(390, 844), 320.0, 2.0),
  ]) {
    testWidgets('confirmar descarte é acessível com teclado em ${scenario.$1}',
        (tester) async {
      await _openEditor(
        tester,
        _api((_) => _response(_createdPost(), 201)),
        size: scenario.$2,
        keyboard: scenario.$3,
        textScale: scenario.$4,
      );
      await tester.enterText(
          find.byType(TextField), 'Debate sobre educação pública.');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Continuar editando').hitTestable(), findsOneWidget);
      expect(find.text('Descartar').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('emoji conta como um caractere da API e nao bloqueia post valido',
      (tester) async {
    String? sent;
    await _openEditor(tester, _api((request) {
      sent = (jsonDecode(request.body) as Map)['content'] as String;
      return _response(_createdPost(), 201);
    }));
    await tester.enterText(find.byType(TextField), '😀' * 400);
    await tester.pump();
    expect(find.text('400/500'), findsOneWidget);
    await tester.ensureVisible(find.text('PUBLICAR'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pumpAndSettle();
    expect(sent, '😀' * 400);
  });
}
