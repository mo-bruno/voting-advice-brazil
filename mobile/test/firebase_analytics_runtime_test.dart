import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_event_policy.dart';
import 'package:guia_eleitoral/core/analytics/firebase_analytics_runtime.dart';

class _Client implements AnalyticsSdkClient {
  final consent = <bool>[];
  final collection = <bool>[];
  final events = <SanitizedAnalyticsEvent>[];
  Completer<void>? blockedGrant;
  bool failGrant = false;
  bool failEnable = false;

  @override
  Future<void> applyConsent({required bool granted}) async {
    consent.add(granted);
    if (granted) {
      await blockedGrant?.future;
      if (failGrant) throw StateError('grant failed');
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collection.add(enabled);
    if (enabled && failEnable) throw StateError('enable failed');
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) async {
    events.add(event);
  }
}

void main() {
  test('concurrent initialization constructs one client', () async {
    final client = _Client();
    final release = Completer<void>();
    var calls = 0;
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async {
        calls++;
        await release.future;
        return client;
      },
      setWebConsent: ({required granted}) => true,
    );
    await runtime.updateConsent(granted: true);
    final first = runtime.initializeForGrantedConsent();
    final second = runtime.initializeForGrantedConsent();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    release.complete();
    await Future.wait([first, second]);
    expect(client.consent.last, isTrue);
    expect(client.collection.last, isTrue);
  });

  test('revocation during construction leaves new client denied', () async {
    final client = _Client();
    final release = Completer<void>();
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async {
        await release.future;
        return client;
      },
      setWebConsent: ({required granted}) => true,
    );
    await runtime.updateConsent(granted: true);
    final initializing = runtime.initializeForGrantedConsent();
    await runtime.updateConsent(granted: false);
    release.complete();
    await initializing;
    await runtime.logEvent(SanitizedAnalyticsEvent(name: 'quiz_started'));
    expect(client.consent.last, isFalse);
    expect(client.collection.last, isFalse);
    expect(client.events, isEmpty);
  });

  test('stale grant effect cannot re-enable after denial', () async {
    final client = _Client();
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async => client,
      setWebConsent: ({required granted}) => true,
    );
    await runtime.updateConsent(granted: true);
    await runtime.initializeForGrantedConsent();
    client.blockedGrant = Completer<void>();
    final grant = runtime.updateConsent(granted: true);
    await Future<void>.delayed(Duration.zero);
    final deny = runtime.updateConsent(granted: false);
    client.blockedGrant!.complete();
    await Future.wait([grant, deny]);
    expect(client.consent.last, isFalse);
    expect(client.collection.last, isFalse);
  });

  test('missing bridge prevents construction and a later event retries',
      () async {
    final client = _Client();
    var bridgeReady = false;
    var calls = 0;
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async {
        calls++;
        return client;
      },
      setWebConsent: ({required granted}) => bridgeReady,
    );
    await expectLater(runtime.updateConsent(granted: true), throwsStateError);
    await expectLater(runtime.initializeForGrantedConsent(), throwsStateError);
    expect(calls, 0);
    bridgeReady = true;
    await runtime.initializeForGrantedConsent();
    expect(calls, 1);
  });

  for (final failure in ['grant', 'enable']) {
    test('$failure preparation failure rolls back and retries', () async {
      final client = _Client();
      final runtime = FirebaseAnalyticsRuntime(
        operationallyEnabled: true,
        isSupportedPlatform: () => true,
        initializeClient: () async => client,
        setWebConsent: ({required granted}) => true,
      );
      await runtime.updateConsent(granted: true);
      if (failure == 'grant') {
        client.failGrant = true;
      } else {
        client.failEnable = true;
      }
      await expectLater(
          runtime.initializeForGrantedConsent(), throwsStateError);
      expect(client.consent.last, isFalse);
      expect(client.collection.last, isFalse);
      await runtime.logEvent(SanitizedAnalyticsEvent(name: 'quiz_started'));
      expect(client.events, isEmpty);
      client.failGrant = false;
      client.failEnable = false;
      await runtime.initializeForGrantedConsent();
      await runtime.logEvent(SanitizedAnalyticsEvent(name: 'quiz_restarted'));
      expect(client.events.map((event) => event.name), ['quiz_restarted']);
    });
  }

  test('construction failure retries without replaying the first event',
      () async {
    final client = _Client();
    var fail = true;
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async {
        if (fail) throw StateError('construction failed');
        return client;
      },
      setWebConsent: ({required granted}) => true,
    );
    await runtime.updateConsent(granted: true);
    await expectLater(runtime.initializeForGrantedConsent(), throwsStateError);
    fail = false;
    await runtime.initializeForGrantedConsent();
    await runtime.logEvent(SanitizedAnalyticsEvent(name: 'quiz_restarted'));
    expect(client.events.map((event) => event.name), ['quiz_restarted']);
  });

  test('runtime resanitizes direct events and drops unknown names', () async {
    final client = _Client();
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async => client,
      setWebConsent: ({required granted}) => true,
    );
    await runtime.updateConsent(granted: true);
    await runtime.initializeForGrantedConsent();
    await runtime.logEvent(SanitizedAnalyticsEvent(
      name: 'quiz_completed',
      parameters: {
        'total_answered': 5,
        'total_skipped': 1,
        'duration_ms': 5000,
        'candidate_id': '13',
        'stance': 'agree',
        'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
      },
    ));
    await runtime.logEvent(SanitizedAnalyticsEvent(name: 'political_affinity'));
    expect(client.events, hasLength(1));
    expect(client.events.single.parameters, {
      'total_answered': 5,
      'total_skipped': 1,
      'duration_ms': 5000,
    });
  });

  test('failed bridge on reacceptance keeps existing client denied', () async {
    final client = _Client();
    var bridgeReady = true;
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: true,
      isSupportedPlatform: () => true,
      initializeClient: () async => client,
      setWebConsent: ({required granted}) => bridgeReady,
    );
    await runtime.updateConsent(granted: true);
    await runtime.initializeForGrantedConsent();
    await runtime.updateConsent(granted: false);
    bridgeReady = false;
    await expectLater(runtime.updateConsent(granted: true), throwsStateError);
    await expectLater(runtime.initializeForGrantedConsent(), throwsStateError);
    expect(client.consent.last, isFalse);
    expect(client.collection.last, isFalse);
    bridgeReady = true;
    await runtime.initializeForGrantedConsent();
    expect(client.consent.last, isTrue);
    expect(client.collection.last, isTrue);
  });
}
