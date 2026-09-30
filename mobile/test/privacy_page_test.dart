import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/privacy/privacy_config.dart';
import 'package:guia_eleitoral/features/privacy/privacy_page.dart';

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
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: PrivacyPage(
      consentController: controller,
      config: _config,
      openLink: openLink,
    ),
  ));
}

void main() {
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
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pumpPage(tester, controller, openLink: (uri) async {
      opened.add(uri);
      return true;
    });
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
