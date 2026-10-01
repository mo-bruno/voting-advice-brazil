import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
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
    theme: AppTheme.dark,
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
            theme: AppTheme.dark,
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
        final reject = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'REJEITAR MÉTRICAS'),
        );
        final accept = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'ACEITAR MÉTRICAS'),
        );
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(
          reject.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(0, 48),
        );
        expect(
          accept.style?.minimumSize?.resolve(<WidgetState>{}),
          const Size(0, 48),
        );
        final rejectPosition = tester.getTopLeft(
          find.widgetWithText(OutlinedButton, 'REJEITAR MÉTRICAS'),
        );
        final acceptPosition = tester.getTopLeft(
          find.widgetWithText(ElevatedButton, 'ACEITAR MÉTRICAS'),
        );
        expect(
          rejectPosition.dy < acceptPosition.dy ||
              (rejectPosition.dy == acceptPosition.dy &&
                  rejectPosition.dx < acceptPosition.dx),
          isTrue,
          reason: 'Reject must precede accept in visual reading order.',
        );
        final semantics = tester.ensureSemantics();
        try {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('reject precedes accept in keyboard and semantics order',
      (tester) async {
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller,
      onLearnMore: () {},
      onGrantFailure: () {},
      onDenialFailure: () {},
    );

    final semantics = tester.ensureSemantics();
    try {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(
          find.widgetWithText(OutlinedButton, 'REJEITAR MÉTRICAS'),
        ),
        matchesSemantics(
          label: 'Rejeitar métricas opcionais\nREJEITAR MÉTRICAS',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(
          find.widgetWithText(ElevatedButton, 'ACEITAR MÉTRICAS'),
        ),
        matchesSemantics(
          label: 'Aceitar métricas opcionais\nACEITAR MÉTRICAS',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

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

  testWidgets('consent copy is concise and provider-neutral', (tester) async {
    final controller = await _controller(_Store());
    addTearDown(controller.dispose);
    await _pump(
      tester,
      controller,
      onLearnMore: () {},
      onGrantFailure: () {},
      onDenialFailure: () {},
    );

    expect(
      find.text(
        'Se você aceitar, enviamos somente métricas de uso e desempenho. '
        'Não enviamos respostas do quiz, preferências políticas ou textos e '
        'não usamos publicidade.',
      ),
      findsOneWidget,
    );
    for (final provider in [
      'Google Analytics',
      'Firebase',
      'GA4',
      'BigQuery',
    ]) {
      expect(find.textContaining(provider), findsNothing, reason: provider);
    }
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
