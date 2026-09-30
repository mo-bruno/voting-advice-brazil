import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/analytics/analytics_event_policy.dart';
import 'package:guia_eleitoral/core/analytics/consent_aware_analytics_sink.dart';
import 'package:guia_eleitoral/core/analytics/firebase_analytics_runtime.dart';

class _Store implements AnalyticsConsentStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _Runtime implements AnalyticsRuntime {
  final events = <SanitizedAnalyticsEvent>[];
  final consent = <bool>[];
  int initializationCalls = 0;
  Completer<void>? blockedInitialization;
  bool failInitialization = false;

  @override
  Future<void> initializeForGrantedConsent() async {
    initializationCalls++;
    if (failInitialization) throw StateError('init failed');
    await blockedInitialization?.future;
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) async {
    events.add(event);
  }

  @override
  Future<void> updateConsent({required bool granted}) async {
    consent.add(granted);
  }
}

Future<AnalyticsConsentController> _controller(_Runtime runtime) async {
  final controller = AnalyticsConsentController.testOnly(
    store: _Store(),
    effects: runtime,
  );
  await controller.hydrate();
  return controller;
}

void main() {
  test('pending and denied discard without initializing runtime', () async {
    final runtime = _Runtime();
    final controller = await _controller(runtime);
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    await sink.logEvent(name: 'quiz_started');
    await controller.deny();
    await sink.logEvent(name: 'quiz_started');
    expect(runtime.initializationCalls, 0);
    expect(runtime.events, isEmpty);
  });

  test('kill switch and unknown events never initialize the runtime', () async {
    final runtime = _Runtime();
    final controller = await _controller(runtime);
    await controller.grant();
    final disabled = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: false,
    );
    await disabled.logEvent(name: 'quiz_started');
    final enabled = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    await enabled.logEvent(name: 'political_preference');
    expect(runtime.initializationCalls, 0);
    expect(runtime.events, isEmpty);
  });

  test('discarded events are not replayed after grant', () async {
    final runtime = _Runtime();
    final controller = await _controller(runtime);
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    await sink.logEvent(name: 'quiz_started');
    await controller.grant();
    await sink.logEvent(name: 'quiz_completed', parameters: {
      'total_answered': 5,
      'candidate_id': '13',
    });
    expect(runtime.events.map((event) => event.name), ['quiz_completed']);
    expect(runtime.events.single.parameters, {'total_answered': 5});
  });

  test('revocation during initialization drops the waiting event', () async {
    final runtime = _Runtime()..blockedInitialization = Completer<void>();
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    final pending = sink.logEvent(name: 'quiz_started');
    await Future<void>.delayed(Duration.zero);
    await controller.deny();
    runtime.blockedInitialization!.complete();
    await pending;
    expect(runtime.events, isEmpty);
    expect(runtime.consent.last, isFalse);
  });

  test('initialization failure is contained without replay', () async {
    final errors = <Object>[];
    final runtime = _Runtime()..failInitialization = true;
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
      onError: errors.add,
    );
    await sink.logEvent(name: 'quiz_started');
    expect(runtime.events, isEmpty);
    expect(errors, hasLength(1));
    runtime.failInitialization = false;
    await sink.logEvent(name: 'quiz_completed');
    expect(runtime.events.map((event) => event.name), ['quiz_completed']);
  });
}
