@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/analytics/analytics_dependencies.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/analytics/consent_aware_analytics_sink.dart';
import 'package:guia_eleitoral/core/analytics/firebase_analytics_runtime.dart';

class _Store implements AnalyticsConsentStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web pipeline initializes Firebase only after consent', () async {
    setupFirebaseCoreMocks();
    FirebasePlatform.instance = MethodChannelFirebase();
    final firebaseCalls = <String>[];
    final consentCalls = <bool?>[];
    final collectionCalls = <bool>[];
    FirebaseAnalyticsPlatform.instance = _RecordingAnalyticsPlatform(
      firebaseCalls,
      consentCalls,
      collectionCalls,
    );

    final bridgeCalls = <bool>[];
    void bridge(JSBoolean granted) => bridgeCalls.add(granted.toDart);
    globalContext.setProperty('farolSetAnalyticsConsent'.toJS, bridge.toJS);
    addTearDown(
      () => globalContext.delete('farolSetAnalyticsConsent'.toJS),
    );

    final initializationStarted = Completer<void>();
    final releaseInitialization = Completer<void>();
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async {
        initializationStarted.complete();
        await releaseInitialization.future;
        final app = await Firebase.initializeApp();
        return FirebaseAnalyticsSdkClient(
          FirebaseAnalytics.instanceFor(app: app),
        );
      },
    );
    final controller = AnalyticsConsentController.testOnly(
      store: _Store(),
      effects: runtime,
    );
    final dependencies = AnalyticsDependencies.testOnly(
      controller: controller,
      sink: ConsentAwareAnalyticsSink(
        controller: controller,
        runtime: runtime,
        operationallyEnabled: true,
      ),
    );
    final service = AnalyticsService(sink: dependencies.sink);
    await controller.hydrate();

    expect(Firebase.apps, isEmpty);
    await service.quizStarted();
    expect(firebaseCalls, isEmpty);
    expect(Firebase.apps, isEmpty);

    expect(await controller.grant(), isTrue);
    expect(Firebase.apps, isEmpty);
    final fromGrantA = service.quizStarted();
    await initializationStarted.future;

    expect(await controller.deny(), isTrue);
    expect(await controller.grant(), isTrue);
    releaseInitialization.complete();
    await fromGrantA;
    expect(firebaseCalls, isEmpty);

    await service.quizRestarted();
    expect(firebaseCalls, ['quiz_restarted']);
    expect(bridgeCalls, contains(true));
    expect(consentCalls.last, isTrue);
    expect(collectionCalls.last, isTrue);

    expect(await controller.deny(), isTrue);
    await service.quizStarted();
    expect(firebaseCalls, ['quiz_restarted']);
    expect(bridgeCalls.last, isFalse);
    expect(consentCalls.last, isFalse);
    expect(collectionCalls.last, isFalse);

    expect(await controller.grant(), isTrue);
    await service.quizStarted();
    expect(firebaseCalls, ['quiz_restarted', 'quiz_started']);
  });
}

class _RecordingAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  _RecordingAnalyticsPlatform(this.calls, this.consent, this.collection);

  final List<String> calls;
  final List<bool?> consent;
  final List<bool> collection;

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) {
    return this;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add(name);
  }

  @override
  Future<void> setConsent({
    bool? adStorageConsentGranted,
    bool? analyticsStorageConsentGranted,
    bool? adPersonalizationSignalsConsentGranted,
    bool? adUserDataConsentGranted,
    bool? functionalityStorageConsentGranted,
    bool? personalizationStorageConsentGranted,
    bool? securityStorageConsentGranted,
  }) async {
    consent.add(analyticsStorageConsentGranted);
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collection.add(enabled);
  }
}
