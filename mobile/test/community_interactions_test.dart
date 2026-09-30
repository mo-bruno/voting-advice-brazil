import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:guia_eleitoral/features/community/post_detail_page.dart';
import 'package:guia_eleitoral/features/community/widgets/post_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> post(String id,
        {int score = 3, int vote = 0, int count = 0, String? theme}) =>
    {
      'id': id,
      'author_alias': 'u/abc123def0',
      'is_mine': true,
      'content': 'Debate sobre transparência dos gastos públicos: $id',
      'score': score,
      'my_vote': vote,
      'comment_count': count,
      'theme_slug': theme,
      'theme_name':
          theme == null ? null : 'Soberania e Relações Internacionais',
      'political_actor_id': null,
      'removed': false,
      'removed_by': null,
      'created_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    };

Map<String, dynamic> comment({bool mine = true, bool removed = false}) => {
      'id': 'c1',
      'post_id': 'p1',
      'author_alias': 'u/abc123def0',
      'is_mine': mine,
      'content': removed ? '' : 'Precisamos acompanhar os gastos públicos.',
      'removed': removed,
      'removed_by': removed ? 'author' : null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

http.Response response(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
ApiClient api(FutureOr<http.Response> Function(http.Request) handler,
        {Duration timeout = const Duration(seconds: 45)}) =>
    ApiClient(
      baseUrl: 'https://api.test/api/v1',
      communityWriteTimeout: timeout,
      client: MockClient((r) async => handler(r)),
    );

Future<void> mount(WidgetTester tester, Widget page,
    {Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    builder: (context, child) => MediaQuery(
      data:
          MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: page,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommunitySession().invalidate();
  });

  testWidgets('resposta antiga de ordenacao nao substitui a aba selecionada',
      (tester) async {
    final score = Completer<http.Response>();
    final recent = Completer<http.Response>();
    await mount(
        tester,
        CommunityFeedPage(
            apiClient: api((r) => r.url.queryParameters['sort'] == 'score'
                ? score.future
                : recent.future)));
    await tester.tap(find.text('RECENTES'));
    await tester.pump();
    recent.complete(response({
      'posts': [post('recente')],
      'has_next': false
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    score.complete(response({
      'posts': [post('antigo')],
      'has_next': false
    }));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('recente'), findsOneWidget);
    expect(find.textContaining('antigo'), findsNothing);
  });

  testWidgets('voto em andamento desabilita visualmente as setas do feed',
      (tester) async {
    final vote = Completer<http.Response>();
    await mount(
        tester,
        CommunityFeedPage(
            apiClient: api((r) => r.url.path.endsWith('/votes')
                ? vote.future
                : response({
                    'posts': [post('p1')],
                    'has_next': false
                  }))));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    expect(tester.widget<PostCard>(find.byType(PostCard)).votePending, isTrue);
    vote.complete(response(post('p1', score: 4, vote: 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('tocar no proprio voto novamente envia zero para desfazer',
      (tester) async {
    final values = <int>[];
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.method == 'GET') {
        return response({
          'posts': [post('p1', vote: 1)],
          'has_next': false
        });
      }
      values.add((jsonDecode(r.body) as Map)['value'] as int);
      return response(post('p1', score: 2));
    })));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(values, [0]);
  });

  testWidgets('card mostra nome legivel do tema e quantidade de comentarios',
      (tester) async {
    await mount(
        tester,
        CommunityFeedPage(
            apiClient: api((r) => response({
                  'posts': [
                    post('p1',
                        count: 2, theme: 'soberania_relacoes_internacionais')
                  ],
                  'has_next': false
                }))));
    expect(find.text('Soberania e Relações Internacionais'), findsOneWidget);
    expect(find.text('2 comentários'), findsOneWidget);
    expect(find.text('SOBERANIA_RELACOES_INTERNACIONAIS'), findsNothing);
  });

  testWidgets('feed cabe em celular estreito com texto ampliado',
      (tester) async {
    await mount(
        tester,
        CommunityFeedPage(
            apiClient: api((r) => response({
                  'posts': [
                    post('p1', theme: 'soberania_relacoes_internacionais')
                  ],
                  'has_next': false
                }))),
        size: const Size(320, 568),
        scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('ESCREVER UM POST'), findsOneWidget);
  });

  testWidgets('filtrar por tema envia o slug e preserva filtro ao ordenar',
      (tester) async {
    final listings = <Uri>[];
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.url.path.endsWith('/themes')) {
        return response([
          {
            'id': 1,
            'slug': 'saude',
            'nome': 'Saúde',
            'area': 'social',
            'descricao': null,
            'icone_slug': null,
            'total_teses_aprovadas': 1
          },
        ]);
      }
      listings.add(r.url);
      return response({'posts': [], 'has_next': false});
    })));
    await tester.tap(find.byTooltip('Filtrar por tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saúde'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RECENTES'));
    await tester.pumpAndSettle();
    expect(listings.last.queryParameters['theme_slug'], 'saude');
    expect(listings.last.queryParameters['sort'], 'recent');
  });

  testWidgets('comentario respeita 300 caracteres antes de enviar',
      (tester) async {
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient:
                api((r) => response({'post': post('p1'), 'comments': []}))));
    await tester.enterText(find.byType(TextField), 'x' * 301);
    await tester.pump();
    expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        300);
    expect(find.text('300/300'), findsOneWidget);
  });

  testWidgets('comentario rejeitado mostra motivo e preserva o rascunho',
      (tester) async {
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) => r.method == 'GET'
                ? response({'post': post('p1'), 'comments': []})
                : response({'detail': 'Revise o ataque pessoal no comentário.'},
                    422))));
    await tester.enterText(find.byType(TextField), 'Texto do comentário');
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Revise o ataque pessoal no comentário.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Texto do comentário');
  });

  testWidgets('respostas simultaneas de voto e comentario preservam ambos',
      (tester) async {
    final vote = Completer<http.Response>();
    final send = Completer<http.Response>();
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) {
              if (r.method == 'GET') {
                return response({'post': post('p1'), 'comments': []});
              }
              return r.url.path.endsWith('/votes') ? vote.future : send.future;
            })));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    await tester.enterText(
        find.byType(TextField), 'Precisamos acompanhar os gastos públicos.');
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    vote.complete(response(post('p1', score: 4, vote: 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    send.complete(response(comment(), 201));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('4'), findsOneWidget);
    expect(
        find.text('Precisamos acompanhar os gastos públicos.'), findsOneWidget);
  });

  testWidgets('autor pode apagar comentario mantendo a lapide', (tester) async {
    var removed = false;
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) {
              if (r.method == 'DELETE') {
                removed = true;
                return http.Response('', 204);
              }
              return response({
                'post': post('p1', count: 1),
                'comments': [comment(removed: removed)]
              });
            })));
    await tester.tap(find.byTooltip('Ações do comentário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('APAGAR'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(find.text('Comentário removido pelo autor'), findsOneWidget);
    expect(
        find.text('Precisamos acompanhar os gastos públicos.'), findsNothing);
  });

  Future<void> openDetail(WidgetTester tester, ApiClient client,
      {Size size = const Size(390, 844),
      double scale = 1,
      double keyboard = 0}) async {
    await mount(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PostDetailPage(
                                postId: 'p1', apiClient: client))),
                    child: const Text('ABRIR DISCUSSÃO')))),
        size: size,
        scale: scale,
        keyboard: keyboard);
    await tester.tap(find.text('ABRIR DISCUSSÃO'));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('descarte de comentario cabe com teclado e fonte $scale',
        (tester) async {
      await openDetail(
          tester, api((r) => response({'post': post('p1'), 'comments': []})),
          size: const Size(320, 568), scale: scale, keyboard: 300);
      await tester.enterText(
          find.byType(TextField), 'Rascunho que não pode sumir');
      await tester.pump();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Descartar comentário?'), findsOneWidget);
      await tester.tap(find.text('CONTINUAR ESCREVENDO'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Rascunho que não pode sumir');
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DESCARTAR'));
      await tester.pumpAndSettle();
      expect(find.text('ABRIR DISCUSSÃO'), findsOneWidget);
    });
  }

  testWidgets(
      'comentario em analise bloqueia duplicata e saida ate o resultado',
      (tester) async {
    final send = Completer<http.Response>();
    var sends = 0;
    await openDetail(tester, api((r) {
      if (r.method == 'GET') {
        return response({'post': post('p1'), 'comments': []});
      }
      sends++;
      return send.future;
    }));
    await tester.enterText(
        find.byType(TextField), 'Precisamos acompanhar os gastos públicos.');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Enviar comentário'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar comentário'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.byTooltip('Enviar comentário'), findsNothing);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pump();
    expect(find.byType(PostDetailPage), findsOneWidget);
    expect(sends, 1);
    send.complete(response(comment(), 201));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('ABRIR DISCUSSÃO'), findsOneWidget);
  });

  testWidgets(
      'comentario de outra pessoa permite denuncia e nao permite apagar',
      (tester) async {
    final reports = <http.Request>[];
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) {
              if (r.method == 'POST') {
                reports.add(r);
                return http.Response('', 204);
              }
              return response({
                'post': post('p1', count: 1),
                'comments': [comment(mine: false)]
              });
            })));
    await tester.tap(find.byTooltip('Ações do comentário'));
    await tester.pumpAndSettle();
    expect(find.text('Apagar'), findsNothing);
    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discurso de ódio'));
    await tester.pumpAndSettle();
    expect(reports.single.url.path,
        '/api/v1/community/posts/p1/comments/c1/reports');
    expect(jsonDecode(reports.single.body)['reason'], 'discurso_de_odio');
    expect(reports.single.headers['x-farol-anonymous-id'], isNotEmpty);
    expect(find.text('Denúncia registrada. Obrigado.'), findsOneWidget);
  });

  testWidgets('post removido preserva comentarios mas oculta voto e editor',
      (tester) async {
    final removed = post('p1', count: 1)
      ..addAll({'removed': true, 'removed_by': 'moderation', 'content': ''});
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) => response({
                  'post': removed,
                  'comments': [comment()]
                }))));
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    expect(find.text('Removido pela moderação'), findsOneWidget);
    expect(
        find.text('Precisamos acompanhar os gastos públicos.'), findsOneWidget);
  });

  testWidgets('pagina antiga de outro filtro nao reaparece na lista',
      (tester) async {
    final next = Completer<http.Response>();
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.url.queryParameters['sort'] == 'recent') {
        return response({
          'posts': [post('recente')],
          'has_next': false
        });
      }
      if (r.url.queryParameters['page'] == '2') return next.future;
      return response({
        'posts': [post('primeiro')],
        'has_next': true
      });
    })));
    await tester.tap(find.text('CARREGAR MAIS'));
    await tester.pump();
    await tester.tap(find.text('RECENTES'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    next.complete(response({
      'posts': [post('antigo-pagina2')],
      'has_next': false
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('recente'), findsOneWidget);
    expect(find.textContaining('antigo-pagina2'), findsNothing);
  });

  testWidgets('publicacao aprovada abre a discussao e aparece em recentes',
      (tester) async {
    var created = false;
    final sorts = <String?>[];
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.url.path.endsWith('/themes')) return response([]);
      if (r.method == 'POST') {
        created = true;
        return response(post('novo'), 201);
      }
      if (r.url.path.endsWith('/posts/novo')) {
        return response({'post': post('novo'), 'comments': []});
      }
      sorts.add(r.url.queryParameters['sort']);
      return response({
        'posts': created ? [post('novo')] : [],
        'has_next': false
      });
    })));
    await tester.tap(find.text('ESCREVER UM POST'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'Quero debater transparência dos gastos públicos.');
    await tester.pump();
    await tester.ensureVisible(find.text('PUBLICAR'));
    await tester.pump();
    await tester.tap(find.text('PUBLICAR'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailPage), findsOneWidget);
    expect(find.textContaining('novo'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFeedPage), findsOneWidget);
    expect(find.textContaining('novo'), findsOneWidget);
    expect(sorts.last, 'recent');
  });

  testWidgets('atualizacao antiga do feed preserva um voto ja concluido',
      (tester) async {
    final refresh = Completer<http.Response>();
    var loads = 0;
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.method == 'POST') return response(post('p1', score: 4, vote: 1));
      return ++loads == 1
          ? response({
              'posts': [post('p1')],
              'has_next': false
            })
          : refresh.future;
    })));
    final refreshState =
        tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
    refreshState.show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(loads, 2);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Retirar voto positivo'), findsOneWidget);
    refresh.complete(response({
      'posts': [post('p1')],
      'has_next': false
    }));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirar voto positivo'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
      'atualizacao com comentario persistido nao duplica resposta de envio',
      (tester) async {
    final send = Completer<http.Response>();
    var loads = 0;
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) {
              if (r.method == 'POST') return send.future;
              loads++;
              return response({
                'post': post('p1', count: loads == 1 ? 0 : 1),
                'comments': loads == 1 ? [] : [comment()]
              });
            })));
    await tester.enterText(
        find.byType(TextField), 'Precisamos acompanhar os gastos públicos.');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Enviar comentário'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar comentário'));
    await tester.pump();
    final refreshState =
        tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
    refreshState.show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(loads, 2);
    send.complete(response(comment(), 201));
    await tester.pumpAndSettle();
    expect(
        find.text('Precisamos acompanhar os gastos públicos.'), findsOneWidget);
    expect(find.text('1 COMENTÁRIO'), findsOneWidget);
  });
  testWidgets(
      'limite de comentario com bandeira coincide com API sem partir emoji',
      (tester) async {
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient:
                api((r) => response({'post': post('p1'), 'comments': []}))));
    await tester.enterText(find.byType(TextField), '🇧🇷' * 151);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '🇧🇷' * 150);
    expect(find.text('300/300'), findsOneWidget);
  });
  testWidgets('voto concluido durante troca de ordenacao permanece selecionado',
      (tester) async {
    final vote = Completer<http.Response>();
    final recent = Completer<http.Response>();
    await mount(tester, CommunityFeedPage(apiClient: api((r) {
      if (r.method == 'POST') return vote.future;
      return r.url.queryParameters['sort'] == 'recent'
          ? recent.future
          : response({
              'posts': [post('p1')],
              'has_next': false
            });
    })));
    await tester.tap(find.byTooltip('Votar a favor'));
    await tester.pump();
    await tester.tap(find.text('RECENTES'));
    await tester.pump();
    vote.complete(response(post('p1', score: 4, vote: 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    recent.complete(response({
      'posts': [post('p1')],
      'has_next': false
    }));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirar voto positivo'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('resposta de comentario atrasada preserva lapide ja atualizada',
      (tester) async {
    final send = Completer<http.Response>();
    var loads = 0;
    await mount(
        tester,
        PostDetailPage(
            postId: 'p1',
            apiClient: api((r) {
              if (r.method == 'POST') return send.future;
              loads++;
              return response({
                'post': post('p1', count: loads == 1 ? 0 : 1),
                'comments': loads == 1 ? [] : [comment(removed: true)]
              });
            })));
    await tester.enterText(
        find.byType(TextField), 'Precisamos acompanhar os gastos públicos.');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Enviar comentário'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar comentário'));
    await tester.pump();
    tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    send.complete(response(comment(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Comentário removido pelo autor'), findsOneWidget);
    expect(
        find.text('Precisamos acompanhar os gastos públicos.'), findsNothing);
  });

  testWidgets('timeout libera editor e navegacao mantendo rascunho',
      (tester) async {
    final send = Completer<http.Response>();
    await openDetail(
        tester,
        api(
            (r) => r.method == 'GET'
                ? response({'post': post('p1'), 'comments': []})
                : send.future,
            timeout: const Duration(milliseconds: 100)));
    await tester.enterText(find.byType(TextField), 'Meu rascunho');
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Enviar comentário'));
    await tester.pump();
    await tester.tap(find.byTooltip('Enviar comentário'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Meu rascunho');
    expect(
        find.textContaining('Verifique a discussão antes de tentar novamente.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar comentário?'), findsOneWidget);
  });
}
