import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/home/home_page.dart';
import 'package:guia_eleitoral/features/home/news_session.dart';
import 'package:guia_eleitoral/features/home/widgets/news_card.dart';
import 'package:guia_eleitoral/features/home/widgets/news_states.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';
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

Widget _app(
  NewsSession session, {
  List<Uri>? opened,
  VoidCallback? onStartQuiz,
  bool politicianFollowEnabled = false,
  PoliticalActorSession? politicalActorSession,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: HomePage(
      newsSession: session,
      politicianFollowEnabled: politicianFollowEnabled,
      politicalActorSession: politicalActorSession,
      onStartQuiz: onStartQuiz ?? () {},
      openLink: (uri) async {
        opened?.add(uri);
        return true;
      },
    ),
  );
}

void main() {
  testWidgets('news button fits a narrow phone and remains tappable',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <Uri>[];
    await tester.pumpWidget(_app(
      NewsSession.testOnly(api: _api(_payload)),
      opened: opened,
    ));
    await tester.pumpAndSettle();
    final button = find.text('VER TODAS AS NOTÍCIAS');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://www.camara.leg.br/noticias');
  });

  testWidgets('desktop places quiz alongside news and resizes to compact',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpWidget(_app(NewsSession.testOnly(api: _api(_payload))));
    await tester.pumpAndSettle();
    final invitation = find.text('Faça seu quiz agora');
    final news = find.text('NOTÍCIAS DA SEMANA');
    expect(tester.getTopLeft(invitation).dx,
        greaterThan(tester.getTopRight(news).dx));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(600, 1000);
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(invitation).dy, lessThan(tester.getTopLeft(news).dy));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('wide Android tablet keeps quiz above news', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1366, 1024);
    await tester.pumpWidget(_app(NewsSession.testOnly(api: _api(_payload))));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Faça seu quiz agora')).dy,
        lessThan(tester.getTopLeft(find.text('NOTÍCIAS DA SEMANA')).dy));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('não consulta acompanhamento quando a flag está desativada',
      (tester) async {
    final api = _FollowProbeApi();
    final actorSession = PoliticalActorSession.testOnly(
      api: api,
      deviceIdentityStore: _FixedIdentityStore(),
    );

    await tester.pumpWidget(
      _app(
        NewsSession.testOnly(api: _api(_payload)),
        politicianFollowEnabled: false,
        politicalActorSession: actorSession,
      ),
    );
    await tester.pumpAndSettle();

    expect(api.fetchFollowedCalls, 0);
  });

  testWidgets('mostra o convite para o quiz antes das noticias',
      (tester) async {
    await tester.pumpWidget(_app(NewsSession.testOnly(api: _api(_payload))));
    await tester.pumpAndSettle();

    final invitation = find.text('Faça seu quiz agora');
    final news = find.text('NOTÍCIAS DA SEMANA');

    expect(invitation, findsOneWidget);
    expect(
      find.text(
        'Descubra sua afinidade com as propostas para a eleição '
        'presidencial de 2026.',
      ),
      findsOneWidget,
    );
    expect(
        tester.getTopLeft(invitation).dy, lessThan(tester.getTopLeft(news).dy));
  });

  testWidgets('botao do convite inicia o quiz', (tester) async {
    var starts = 0;
    await tester.pumpWidget(
      _app(
        NewsSession.testOnly(api: _api(_payload)),
        onStartQuiz: () => starts++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar o quiz'));

    expect(starts, 1);
  });

  testWidgets('convite permite consultar a página pública e sua metodologia',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_app(
      NewsSession.testOnly(api: _api(_payload)),
      opened: opened,
    ));
    await tester.pumpAndSettle();

    final link = find.text('Entenda as fontes e o resultado');
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();

    expect(opened, [Uri.parse('https://fpolitico.com.br/eleicoes-2026/')]);
  });

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

    final firstCard = find.byType(NewsCard).first;
    await tester.ensureVisible(firstCard);
    await tester.pumpAndSettle();
    await tester.tap(firstCard);
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
    debugDefaultTargetPlatformOverride = null;
  });
}

class _FollowProbeApi extends ApiClient {
  _FollowProbeApi() : super(baseUrl: 'https://api.test/api/v1');

  int fetchFollowedCalls = 0;

  @override
  Future<PoliticalActor?> fetchFollowedPoliticalActor({
    required String anonymousId,
  }) async {
    fetchFollowedCalls++;
    return null;
  }
}

class _FixedIdentityStore extends DeviceIdentityStore {
  @override
  Future<String> getOrCreateDeviceId() async =>
      '550e8400-e29b-41d4-a716-446655440000';
}
