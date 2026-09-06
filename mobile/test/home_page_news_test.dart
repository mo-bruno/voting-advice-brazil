import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/home/home_page.dart';
import 'package:guia_eleitoral/features/home/news_session.dart';
import 'package:guia_eleitoral/features/home/widgets/news_card.dart';
import 'package:guia_eleitoral/features/home/widgets/news_states.dart';
import 'package:http/http.dart' as http;

const _payload = {
  'period_start': '2026-08-30',
  'period_end': '2026-09-06',
  'period_label': '30 DE AGO A 6 DE SET DE 2026',
  'total': 2,
  'articles': [
    {
      'id': 'a',
      'title': 'Primeira materia',
      'summary': 'Resumo um',
      'image_url': null,
      'theme_slug': 'eleicoes',
      'theme_label': 'ELEIÇÕES',
      'published_at': '2026-09-04T12:49:00Z',
      'reading_minutes': 2,
      'url': 'https://example.org/a',
    },
    {
      'id': 'b',
      'title': 'Segunda materia',
      'summary': 'Resumo dois',
      'image_url': null,
      'theme_slug': 'politica',
      'theme_label': 'POLÍTICA',
      'published_at': '2026-09-01T21:44:00Z',
      'reading_minutes': 3,
      'url': 'https://example.org/b',
    },
  ],
};

class _StubClient extends http.BaseClient {
  _StubClient(this.body, {this.status = 200});

  final Object body;
  final int status;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Stub que só responde quando o teste libera o `gate`.
class _GatedClient extends http.BaseClient {
  _GatedClient(this.body, this.gate);

  final Object body;
  final Future<void> gate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await gate;
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

ApiClient _api(Object body, {int status = 200}) => ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient(body, status: status),
    );

Widget _app(NewsSession session, {List<Uri>? opened}) {
  return MaterialApp(
    home: HomePage(
      newsSession: session,
      openLink: (uri) async {
        opened?.add(uri);
        return true;
      },
    ),
  );
}

void main() {
  testWidgets('mostra os cards quando ha noticias', (tester) async {
    await tester.pumpWidget(_app(NewsSession.testOnly(api: _api(_payload))));
    await tester.pumpAndSettle();

    expect(find.byType(NewsCard), findsNWidgets(2));
    expect(find.text('NOTÍCIAS DA SEMANA'), findsOneWidget);
    expect(find.text('30 DE AGO A 6 DE SET DE 2026'), findsOneWidget);
  });

  testWidgets('mostra o esqueleto enquanto carrega', (tester) async {
    // O stub comum resolve num microtask, o que faria a tela chegar em `ready`
    // antes do primeiro pump. Este segura a resposta até o teste liberar, então
    // o quadro de carregamento é observável de forma determinística.
    final gate = Completer<void>();
    final api = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _GatedClient(_payload, gate.future),
    );

    await tester.pumpWidget(_app(NewsSession.testOnly(api: api)));
    await tester.pump();

    expect(find.byType(NewsSkeleton), findsWidgets);
    expect(find.byType(NewsCard), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(NewsSkeleton), findsNothing);
    expect(find.byType(NewsCard), findsNWidgets(2));
  });

  testWidgets('mostra o estado vazio', (tester) async {
    final session = NewsSession.testOnly(
      api: _api({..._payload, 'total': 0, 'articles': <dynamic>[]}),
    );

    await tester.pumpWidget(_app(session));
    await tester.pumpAndSettle();

    expect(find.byType(NewsEmpty), findsOneWidget);
    expect(find.byType(NewsCard), findsNothing);
  });

  testWidgets('mostra o estado de erro', (tester) async {
    final session = NewsSession.testOnly(
      api: _api({'detail': 'boom'}, status: 500),
    );

    await tester.pumpWidget(_app(session));
    await tester.pumpAndSettle();

    expect(find.byType(NewsError), findsOneWidget);
  });

  testWidgets('tocar no card abre a url da materia', (tester) async {
    final opened = <Uri>[];

    await tester.pumpWidget(
      _app(NewsSession.testOnly(api: _api(_payload)), opened: opened),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NewsCard).first);
    await tester.pumpAndSettle();

    expect(opened.single, Uri.parse('https://example.org/a'));
  });

  testWidgets('card sem resumo nao quebra o layout', (tester) async {
    // Acontece de verdade: 1 em 13 artigos da Camara vem sem `description`.
    final payload = <String, dynamic>{
      'period_start': '2026-08-30',
      'period_end': '2026-09-06',
      'period_label': '30 DE AGO A 6 DE SET DE 2026',
      'total': 1,
      'articles': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a',
          'title': 'Materia sem resumo',
          'summary': '',
          'image_url': null,
          'theme_slug': 'economia',
          'theme_label': 'ECONOMIA',
          'published_at': '2026-09-04T21:06:00Z',
          'reading_minutes': 3,
          'url': 'https://example.org/sem-resumo',
        },
      ],
    };

    await tester.pumpWidget(_app(NewsSession.testOnly(api: _api(payload))));
    await tester.pumpAndSettle();

    expect(find.byType(NewsCard), findsOneWidget);
    expect(find.text('MATERIA SEM RESUMO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
