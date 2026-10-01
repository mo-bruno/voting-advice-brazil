import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/analytics/analytics_event_policy.dart';
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

class _Runtime implements AnalyticsRuntime {
  final events = <SanitizedAnalyticsEvent>[];
  final consent = <bool>[];
  int initializationCalls = 0;
  Completer<void>? blockedInitialization;
  bool failInitialization = false;
  bool failFirstLog = false;
  Completer<void>? blockedFirstLog;
  final attemptedNames = <String>[];

  @override
  Future<void> initializeForGrantedConsent() async {
    initializationCalls++;
    if (failInitialization) throw StateError('init failed');
    await blockedInitialization?.future;
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) async {
    attemptedNames.add(event.name);
    if (blockedFirstLog != null && attemptedNames.length == 1) {
      await blockedFirstLog!.future;
    }
    if (failFirstLog && attemptedNames.length == 1) {
      throw StateError('first log failed');
    }
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
      'total_skipped': 1,
      'duration_ms': 5000,
      'candidate_id': '13',
    });
    expect(runtime.events.map((event) => event.name), ['quiz_completed']);
    expect(runtime.events.single.parameters, {
      'total_answered': 5,
      'total_skipped': 1,
      'duration_ms': 5000,
    });
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

  test('grant A event cannot cross deny and grant B', () async {
    final runtime = _Runtime()..blockedInitialization = Completer<void>();
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );

    final fromGrantA = sink.logEvent(name: 'quiz_started');
    await Future<void>.delayed(Duration.zero);
    await controller.deny();
    await controller.grant();
    runtime.blockedInitialization!.complete();
    await fromGrantA;
    await sink.logEvent(name: 'quiz_restarted');

    expect(runtime.events.map((event) => event.name), ['quiz_restarted']);
    expect(runtime.consent, [true, false, true]);
  });

  test('operation started in grant A cannot finish in grant B', () async {
    final runtime = _Runtime();
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    final analytics = AnalyticsService(sink: sink);

    final grantAOperation = analytics.bindToCurrentConsent();
    await controller.deny();
    await controller.grant();
    await grantAOperation.operationResult(
      operation: AnalyticsOperation.resultsSubmit,
      outcome: AnalyticsOutcome.success,
      trigger: AnalyticsTrigger.submit,
      itemCount: 5,
    );

    final grantBOperation = analytics.bindToCurrentConsent();
    await grantBOperation.operationResult(
      operation: AnalyticsOperation.resultsSubmit,
      outcome: AnalyticsOutcome.success,
      trigger: AnalyticsTrigger.submit,
      itemCount: 4,
    );

    expect(runtime.events, hasLength(1));
    expect(runtime.events.single.name, 'operation_result');
    expect(runtime.events.single.parameters?['item_count'], 4);
  });

  test('operation started without consent is not activated by a later grant',
      () async {
    final runtime = _Runtime();
    final controller = await _controller(runtime);
    final analytics = AnalyticsService(
      sink: ConsentAwareAnalyticsSink(
        controller: controller,
        runtime: runtime,
        operationallyEnabled: true,
      ),
    );

    final pendingOperation = analytics.bindToCurrentConsent();
    await controller.grant();
    await pendingOperation.quizStarted();

    expect(runtime.events, isEmpty);
  });

  test('events queued before deny are dropped after regrant', () async {
    final runtime = _Runtime()..blockedInitialization = Completer<void>();
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );

    final queued = <Future<void>>[
      sink.logEvent(name: 'quiz_started'),
      sink.logEvent(name: 'quiz_restarted'),
      sink.logEvent(name: 'quiz_intro_viewed'),
    ];
    await Future<void>.delayed(Duration.zero);
    await controller.deny();
    await controller.grant();
    runtime.blockedInitialization!.complete();
    await Future.wait(queued);
    await sink.logEvent(name: 'weighting_started');

    expect(runtime.events.map((event) => event.name), ['weighting_started']);
  });

  test('events are delivered in FIFO order', () async {
    final runtime = _Runtime()..blockedFirstLog = Completer<void>();
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );

    final pending = <Future<void>>[
      sink.logEvent(name: 'quiz_started'),
      sink.logEvent(name: 'quiz_restarted'),
      sink.logEvent(name: 'quiz_intro_viewed'),
    ];
    await Future<void>.delayed(Duration.zero);

    expect(runtime.attemptedNames, ['quiz_started']);
    runtime.blockedFirstLog!.complete();
    await Future.wait(pending);
    expect(runtime.events.map((event) => event.name), [
      'quiz_started',
      'quiz_restarted',
      'quiz_intro_viewed',
    ]);
  });

  test('one failed event does not poison the FIFO tail', () async {
    final errors = <Object>[];
    final runtime = _Runtime()..failFirstLog = true;
    final controller = await _controller(runtime);
    await controller.grant();
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
      onError: errors.add,
    );

    await Future.wait([
      sink.logEvent(name: 'quiz_started'),
      sink.logEvent(name: 'quiz_completed', parameters: {
        'total_answered': 10,
        'total_skipped': 2,
        'duration_ms': 20,
      }),
    ]);

    expect(runtime.attemptedNames, ['quiz_started', 'quiz_completed']);
    expect(runtime.events.map((event) => event.name), ['quiz_completed']);
    expect(errors, hasLength(1));
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
    await sink.logEvent(name: 'quiz_restarted');
    expect(runtime.events.map((event) => event.name), ['quiz_restarted']);
  });
}
