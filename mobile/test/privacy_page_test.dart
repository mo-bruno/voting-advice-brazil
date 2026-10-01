import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/privacy/privacy_config.dart';
import 'package:guia_eleitoral/features/privacy/privacy_page.dart';

import 'helpers/analytics_test_support.dart';

class _Store implements AnalyticsConsentStore {
  _Store({this.value});

  String? value;
  bool failNextWrite = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write failed');
    }
    this.value = value;
  }
}

class _Effects implements AnalyticsConsentEffects {
  @override
  Future<void> updateConsent({required bool granted}) async {}
}

const _config = PrivacyConfig(
  controllerName: 'Responsável de Teste',
  contactEmail: 'privacidade@fpolitico.com.br',
);

Future<AnalyticsConsentController> _controller(_Store store) async {
  final controller = AnalyticsConsentController.testOnly(
    store: store,
    effects: _Effects(),
  );
  await controller.hydrate();
  return controller;
}

Future<void> _pumpPage(
  WidgetTester tester,
  AnalyticsConsentController controller, {
  Future<bool> Function(Uri)? openLink,
  bool analyticsEnabled = false,
  RecordingAnalyticsSink? sink,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: PrivacyPage(
      consentController: controller,
      config: _config,
      openLink: openLink,
      analyticsEnabled: analyticsEnabled,
      analytics: sink == null ? null : AnalyticsService(sink: sink),
    ),
  ));
}

void main() {
  testWidgets('retention copy distinguishes paused and active analytics',
      (tester) async {
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    expect(
        find.textContaining('A coleta de métricas está pausada nesta versão',
            skipOffstage: false),
        findsOneWidget);
    expect(
        find.textContaining('têm retenção configurada por 2 meses',
            skipOffstage: false),
        findsNothing);

    await _pumpPage(tester, controller, analyticsEnabled: true);
    expect(
        find.textContaining('têm retenção configurada por 2 meses',
            skipOffstage: false),
        findsOneWidget);
    expect(
        find.textContaining('A coleta de métricas está pausada nesta versão',
            skipOffstage: false),
        findsNothing);
    expect(
      find.textContaining(
        'tabelas históricas existentes podem não ter expiração',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'novas tabelas expiram em até 60 dias',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'ativação em produção só ocorre se a configuração',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('optional metrics copy states coverage and strict exclusions',
      (tester) async {
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller, analyticsEnabled: true);

    for (final phrase in [
      'consentimento é opcional e pode ser revogado',
      'telas genéricas, uso de funcionalidades e resultados e durações de operações',
      'página, referência, informações do navegador e dispositivo',
      'identificadores pseudônimos',
      'respostas do quiz, posições políticas, candidatos, partidos, ranking, afinidade, identificador funcional ou texto livre',
      'retenção configurada por 2 meses no GA4',
    ]) {
      expect(
        find.textContaining(phrase, skipOffstage: false),
        findsOneWidget,
        reason: phrase,
      );
    }
  });

  testWidgets('notice identifies controller and the key processing boundaries',
      (tester) async {
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    for (final title in [
      'PRIVACIDADE E DADOS',
      'Quem decide e como falar conosco',
      'Finalidades e bases legais',
      'Métricas opcionais',
      'Quiz e respostas políticas',
      'Identidades funcionais e comunidade',
      'Validação da área Acompanhar',
      'Compartilhamento do resultado',
      'Fornecedores e transferências',
      'Retenção e segurança',
      'Seus direitos',
    ]) {
      expect(find.text(title, skipOffstage: false), findsOneWidget);
    }
    for (final phrase in [
      'Responsável de Teste',
      'privacidade@fpolitico.com.br',
      'opinião política',
      'não armazenamos essas respostas',
      'Firebase Installation ID',
      'BigQuery',
      'NVIDIA NIM',
      'ImprovMX',
      '180 dias',
      'interface atual não oferece retirada direta',
      'Autoridade Nacional de Proteção de Dados',
    ]) {
      expect(find.textContaining(phrase, skipOffstage: false), findsWidgets);
    }
  });

  testWidgets('pending offers equally available accept and reject actions',
      (tester) async {
    final store = _Store();
    final controller = await _controller(store);
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    expect(find.text('ACEITAR MÉTRICAS'), findsOneWidget);
    expect(find.text('REJEITAR MÉTRICAS'), findsOneWidget);
    await tester.tap(find.text('REJEITAR MÉTRICAS'));
    await tester.pump();
    expect(store.value, 'denied');
    expect(find.text('Métricas rejeitadas'), findsOneWidget);
    await tester.tap(find.text('ACEITAR MÉTRICAS'));
    await tester.pump();
    expect(store.value, 'granted');
    expect(find.text('Métricas aceitas'), findsOneWidget);
    expect(find.text('REVOGAR MÉTRICAS'), findsOneWidget);
  });

  testWidgets('failed revocation warns and retry persists denial',
      (tester) async {
    final store = _Store(value: 'granted')..failNextWrite = true;
    final controller = await _controller(store);
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller);
    await tester.tap(find.text('REVOGAR MÉTRICAS'));
    await tester.pump();
    expect(controller.state, AnalyticsConsent.denied);
    expect(store.value, 'granted');
    expect(find.textContaining('não foi possível salvar a rejeição'),
        findsOneWidget);
    await tester.tap(find.text('TENTAR SALVAR REJEIÇÃO'));
    await tester.pump();
    expect(store.value, 'denied');
    expect(find.textContaining('não foi possível salvar a rejeição'),
        findsNothing);
    final fresh = await _controller(store);
    addTearDown(fresh.dispose);
    expect(fresh.state, AnalyticsConsent.denied);
  });

  testWidgets('public links use their exact destinations', (tester) async {
    final opened = <Uri>[];
    final sink = RecordingAnalyticsSink();
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller, openLink: (uri) async {
      opened.add(uri);
      return true;
    }, sink: sink);
    expect(sink.names, isNot(contains('screen_viewed')));
    await tester.ensureVisible(find.text('ENVIAR E-MAIL'));
    await tester.tap(find.text('ENVIAR E-MAIL'));
    await tester.pump();
    await tester.ensureVisible(find.text('SAIBA COMO O GOOGLE USA DADOS'));
    await tester.tap(find.text('SAIBA COMO O GOOGLE USA DADOS'));
    await tester.pump();
    expect(opened, [
      Uri(scheme: 'mailto', path: _config.contactEmail),
      Uri.parse(
          'https://policies.google.com/technologies/partner-sites?hl=pt-BR'),
    ]);
    expect(
      named(sink.calls, 'engagement_action').map((call) => call.parameters),
      [
        {
          'action': 'outbound_open',
          'surface': 'privacy',
          'target': 'privacy_email',
          'outcome': 'success',
        },
        {
          'action': 'outbound_open',
          'surface': 'privacy',
          'target': 'google_privacy',
          'outcome': 'success',
        },
      ],
    );
    final serialized =
        sink.calls.map((call) => '${call.name}:${call.parameters}').join('\n');
    expect(serialized, isNot(contains(_config.contactEmail)));
    expect(serialized, isNot(contains('policies.google.com')));
  });

  testWidgets('public links report failed outcomes after the opener finishes',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final controller = await _controller(_Store());
    final emailCompletion = Completer<bool>();
    addTearDown(controller.dispose);
    await _pumpPage(
      tester,
      controller,
      sink: sink,
      openLink: (uri) {
        if (uri.scheme == 'mailto') return emailCompletion.future;
        throw StateError('private opener detail');
      },
    );

    await tester.ensureVisible(find.text('ENVIAR E-MAIL'));
    await tester.tap(find.text('ENVIAR E-MAIL'));
    await tester.pump();
    expect(named(sink.calls, 'engagement_action'), isEmpty);

    emailCompletion.complete(false);
    await tester.pump();
    await tester.ensureVisible(find.text('SAIBA COMO O GOOGLE USA DADOS'));
    await tester.tap(find.text('SAIBA COMO O GOOGLE USA DADOS'));
    await tester.pump();

    expect(
      named(sink.calls, 'engagement_action').map((call) => call.parameters),
      [
        {
          'action': 'outbound_open',
          'surface': 'privacy',
          'target': 'privacy_email',
          'outcome': 'failed',
        },
        {
          'action': 'outbound_open',
          'surface': 'privacy',
          'target': 'google_privacy',
          'outcome': 'failed',
        },
      ],
    );
  });

  testWidgets('MyApp gives the privacy route its shared analytics service',
      (tester) async {
    final controller = await _controller(_Store());
    final analytics = AnalyticsService(sink: RecordingAnalyticsSink());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MyApp(
      analyticsConsent: controller,
      analytics: analytics,
      privacyConfig: _config,
      pageBuilders: [
        (_) => const Scaffold(body: Text('home')),
        (_) => const Scaffold(body: Text('follow')),
        (_) => const Scaffold(body: Text('quiz')),
        (_) => const Scaffold(body: Text('community')),
      ],
    ));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/privacidade');
    await tester.pumpAndSettle();

    final page = tester.widget<PrivacyPage>(find.byType(PrivacyPage));
    expect(page.analytics, same(analytics));
  });

  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets('notice remains scrollable at $size with 200% text',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await _controller(_Store());
      addTearDown(controller.dispose);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: PrivacyPage(consentController: controller, config: _config),
        ),
      ));
      await tester
          .ensureVisible(find.text('Seus direitos', skipOffstage: false));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
