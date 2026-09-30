import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/features/privacy/analytics_consent_banner.dart';

class _Store implements AnalyticsConsentStore {
  String? value;
  bool failNext = false;
  final writes = <String>[];

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (failNext) {
      failNext = false;
      throw StateError('save failed');
    }
    this.value = value;
  }
}

class _Effects implements AnalyticsConsentEffects {
  @override
  Future<void> updateConsent({required bool granted}) async {}
}

Future<AnalyticsConsentController> _controller(_Store store) async {
  final controller = AnalyticsConsentController.testOnly(
    store: store,
    effects: _Effects(),
  );
  await controller.hydrate();
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  AnalyticsConsentController controller, {
  required VoidCallback onLearnMore,
  required VoidCallback onGrantFailure,
  required VoidCallback onDenialFailure,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AnalyticsConsentBanner(
        controller: controller,
        onLearnMore: onLearnMore,
        onGrantPersistenceFailure: onGrantFailure,
        onDenialPersistenceFailure: onDenialFailure,
      ),
    ),
  ));
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('banner fits $size at ${scale}x text', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = await _controller(_Store());
        addTearDown(controller.dispose);
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            home: Scaffold(
              body: AnalyticsConsentBanner(
                controller: controller,
                onLearnMore: () {},
                onGrantPersistenceFailure: () {},
                onDenialPersistenceFailure: () {},
              ),
            ),
          ),
        ));
        expect(find.text('REJEITAR MÉTRICAS'), findsOneWidget);
        expect(find.text('ACEITAR MÉTRICAS'), findsOneWidget);
        expect(find.text('SAIBA MAIS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final buttons = tester
            .widgetList<OutlinedButton>(
              find.byType(OutlinedButton),
            )
            .toList();
        expect(buttons, hasLength(2));
        expect(
            buttons.first.style?.minimumSize, buttons.last.style?.minimumSize);
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('learn more navigates without deciding', (tester) async {
    final store = _Store();
    final controller = await _controller(store);
    addTearDown(controller.dispose);
    var opened = 0;
    await _pump(tester, controller,
        onLearnMore: () => opened++,
        onGrantFailure: () {},
        onDenialFailure: () {});
    await tester.tap(find.text('SAIBA MAIS'));
    expect(opened, 1);
    expect(controller.state, AnalyticsConsent.pending);
    expect(store.writes, isEmpty);
  });

  testWidgets('accept and reject call their matching actions', (tester) async {
    final store = _Store();
    final controller = await _controller(store);
    addTearDown(controller.dispose);
    await _pump(tester, controller,
        onLearnMore: () {}, onGrantFailure: () {}, onDenialFailure: () {});
    await tester.tap(find.text('ACEITAR MÉTRICAS'));
    await tester.pump();
    expect(store.writes, ['granted']);
    expect(controller.state, AnalyticsConsent.granted);
    await tester.tap(find.text('REJEITAR MÉTRICAS'));
    await tester.pump();
    expect(store.writes, ['granted', 'denied']);
    expect(controller.state, AnalyticsConsent.denied);
  });

  testWidgets('save failures call the matching retry handler', (tester) async {
    final store = _Store()..failNext = true;
    final controller = await _controller(store);
    addTearDown(controller.dispose);
    var grantFailures = 0;
    var denialFailures = 0;
    await _pump(tester, controller,
        onLearnMore: () {},
        onGrantFailure: () => grantFailures++,
        onDenialFailure: () => denialFailures++);
    await tester.tap(find.text('ACEITAR MÉTRICAS'));
    await tester.pump();
    expect(grantFailures, 1);
    expect(denialFailures, 0);
    expect(controller.state, AnalyticsConsent.pending);
    store.failNext = true;
    await tester.tap(find.text('REJEITAR MÉTRICAS'));
    await tester.pump();
    expect(grantFailures, 1);
    expect(denialFailures, 1);
    expect(controller.state, AnalyticsConsent.denied);
  });
}
