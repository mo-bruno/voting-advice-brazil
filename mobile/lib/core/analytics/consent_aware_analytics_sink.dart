import 'analytics_consent_controller.dart';
import 'analytics_event_policy.dart';
import 'analytics_sink.dart';
import 'firebase_analytics_runtime.dart';

class ConsentAwareAnalyticsSink
    implements AnalyticsSink, ConsentBindableAnalyticsSink {
  ConsentAwareAnalyticsSink({
    required this.controller,
    required this.runtime,
    required this.operationallyEnabled,
    this.onError,
  });

  final AnalyticsConsentController controller;
  final AnalyticsRuntime runtime;
  final bool operationallyEnabled;
  final void Function(Object error)? onError;
  Future<void> _tail = Future<void>.value();

  bool _canSend(int revision) =>
      operationallyEnabled &&
      controller.isGranted &&
      controller.revision == revision;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    if (!operationallyEnabled || !controller.isGranted) {
      return Future<void>.value();
    }
    return _logEventAtRevision(
      name: name,
      parameters: parameters,
      revision: controller.revision,
    );
  }

  @override
  AnalyticsSink captureConsentBoundSink() {
    final revision = operationallyEnabled && controller.isGranted
        ? controller.revision
        : null;
    return _ConsentRevisionAnalyticsSink(this, revision);
  }

  Future<void> _logEventAtRevision({
    required String name,
    required Map<String, Object>? parameters,
    required int? revision,
  }) {
    if (revision == null || !_canSend(revision)) {
      return Future<void>.value();
    }
    final event = AnalyticsEventPolicy.sanitize(
      name: name,
      parameters: parameters,
    );
    if (event == null) return Future<void>.value();
    final task = _tail.then((_) => _deliver(event, revision));
    _tail = task.then<void>((_) {}, onError: (_) {});
    return task;
  }

  Future<void> _deliver(
    SanitizedAnalyticsEvent event,
    int revision,
  ) async {
    if (!_canSend(revision)) return;
    try {
      await runtime.initializeForGrantedConsent();
      if (!_canSend(revision)) return;
      await runtime.logEvent(event);
    } catch (_) {
      onError?.call(StateError('analytics event failed'));
    }
  }
}

final class _ConsentRevisionAnalyticsSink implements AnalyticsSink {
  const _ConsentRevisionAnalyticsSink(this._parent, this._revision);

  final ConsentAwareAnalyticsSink _parent;
  final int? _revision;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return _parent._logEventAtRevision(
      name: name,
      parameters: parameters,
      revision: _revision,
    );
  }
}
