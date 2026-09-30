import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'analytics_consent_bridge.dart';
import 'analytics_consent_controller.dart';
import 'analytics_event_policy.dart';
import 'analytics_operational_config.dart';

abstract interface class AnalyticsRuntime implements AnalyticsConsentEffects {
  Future<void> initializeForGrantedConsent();
  Future<void> logEvent(SanitizedAnalyticsEvent event);
}

abstract interface class AnalyticsSdkClient {
  Future<void> applyConsent({required bool granted});
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> logEvent(SanitizedAnalyticsEvent event);
}

class FirebaseAnalyticsSdkClient implements AnalyticsSdkClient {
  const FirebaseAnalyticsSdkClient(this.analytics);

  final FirebaseAnalytics analytics;

  @override
  Future<void> applyConsent({required bool granted}) {
    return analytics.setConsent(
      analyticsStorageConsentGranted: granted,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) {
    return analytics.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) {
    return analytics.logEvent(name: event.name, parameters: event.parameters);
  }
}

class FirebaseAnalyticsRuntime implements AnalyticsRuntime {
  FirebaseAnalyticsRuntime({
    bool operationallyEnabled = AnalyticsOperationalConfig.enabled,
    bool Function()? isSupportedPlatform,
    Future<AnalyticsSdkClient> Function()? initializeClient,
    bool Function({required bool granted})? setWebConsent,
    void Function(Object error)? onError,
  })  : _operationallyEnabled = operationallyEnabled,
        _isSupportedPlatform = isSupportedPlatform ?? _defaultSupportedPlatform,
        _initializeClient = initializeClient ?? _defaultInitializeClient,
        _setWebConsent = setWebConsent ?? setWebAnalyticsConsent,
        _onError = onError;

  final bool _operationallyEnabled;
  final bool Function() _isSupportedPlatform;
  final Future<AnalyticsSdkClient> Function() _initializeClient;
  final bool Function({required bool granted}) _setWebConsent;
  final void Function(Object error)? _onError;

  AnalyticsSdkClient? _sdkClient;
  Future<void>? _initialization;
  Future<void> _effectsTail = Future<void>.value();
  bool _eventReady = false;
  bool _latestEffectiveGrant = false;
  bool _webConsentReady = false;
  int _revision = 0;

  static bool _defaultSupportedPlatform() =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static Future<AnalyticsSdkClient> _defaultInitializeClient() async {
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          )
        : Firebase.app();
    return FirebaseAnalyticsSdkClient(FirebaseAnalytics.instanceFor(app: app));
  }

  @override
  Future<void> updateConsent({required bool granted}) {
    final effective = _operationallyEnabled && granted;
    ++_revision;
    _latestEffectiveGrant = effective;
    _eventReady = false;
    final bridgeReady = _updateWebConsent(effective);
    final task = _effectsTail.then((_) async {
      final client = _sdkClient;
      if (client != null) {
        try {
          await _applyLatestRequestedConsent(client);
        } catch (_) {
          await _rollback(client);
          _report();
          throw StateError('analytics consent update failed');
        }
      }
      if (!bridgeReady) throw StateError('analytics consent bridge failed');
    });
    _effectsTail = task.then<void>((_) {}, onError: (Object error) {});
    return task;
  }

  @override
  Future<void> initializeForGrantedConsent() {
    if (!_operationallyEnabled || !_isSupportedPlatform()) {
      return Future<void>.value();
    }
    if (!_latestEffectiveGrant) return Future<void>.value();
    if (_sdkClient != null && _eventReady && _webConsentReady) {
      return Future<void>.value();
    }
    final pending = _initialization;
    if (pending != null) return pending;
    late final Future<void> created;
    created = _prepare().whenComplete(() {
      if (identical(_initialization, created)) _initialization = null;
    });
    _initialization = created;
    return created;
  }

  Future<void> _prepare() async {
    if (!_updateWebConsent(_latestEffectiveGrant)) {
      final client = _sdkClient;
      if (client != null) await _rollback(client);
      throw StateError('analytics consent bridge failed');
    }
    try {
      final candidate = _sdkClient ?? await _initializeClient();
      _sdkClient = candidate;
      final task = _effectsTail.then(
        (_) => _applyLatestRequestedConsent(candidate),
      );
      _effectsTail = task.then<void>((_) {}, onError: (Object error) {});
      await task;
    } catch (_) {
      _eventReady = false;
      final client = _sdkClient;
      if (client != null) await _rollback(client);
      _report();
      throw StateError('analytics preparation failed');
    }
  }

  bool _updateWebConsent(bool granted) {
    bool succeeded;
    try {
      succeeded = _setWebConsent(granted: granted);
    } catch (_) {
      succeeded = false;
    }
    _webConsentReady = succeeded;
    if (!succeeded) {
      _eventReady = false;
      _report();
    }
    return succeeded;
  }

  Future<void> _applyLatestRequestedConsent(AnalyticsSdkClient client) async {
    while (true) {
      final revision = _revision;
      final grant = _latestEffectiveGrant && _webConsentReady;
      if (grant) {
        await client.applyConsent(granted: true);
        if (revision != _revision) continue;
        await client.setCollectionEnabled(true);
        if (revision != _revision) continue;
        _eventReady = true;
        return;
      }
      _eventReady = false;
      Object? failure;
      try {
        await client.applyConsent(granted: false);
      } catch (error) {
        failure = error;
      }
      try {
        await client.setCollectionEnabled(false);
      } catch (error) {
        failure ??= error;
      }
      if (revision != _revision) continue;
      if (failure != null) throw StateError('analytics denial failed');
      return;
    }
  }

  Future<void> _rollback(AnalyticsSdkClient client) async {
    _eventReady = false;
    _updateWebConsent(false);
    try {
      await client.applyConsent(granted: false);
    } catch (_) {
      _report();
    }
    try {
      await client.setCollectionEnabled(false);
    } catch (_) {
      _report();
    }
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) async {
    if (!_operationallyEnabled ||
        !_latestEffectiveGrant ||
        !_webConsentReady ||
        !_eventReady) {
      return;
    }
    final sanitized = AnalyticsEventPolicy.sanitize(
      name: event.name,
      parameters: event.parameters,
    );
    final client = _sdkClient;
    if (sanitized == null || client == null) return;
    await client.logEvent(sanitized);
  }

  void _report() {
    _onError?.call(StateError('analytics operation failed'));
  }
}
