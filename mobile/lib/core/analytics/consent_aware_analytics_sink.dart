import 'analytics_consent_controller.dart';
import 'analytics_event_policy.dart';
import 'analytics_sink.dart';
import 'firebase_analytics_runtime.dart';

class ConsentAwareAnalyticsSink implements AnalyticsSink {
  const ConsentAwareAnalyticsSink({
    required this.controller,
    required this.runtime,
    required this.operationallyEnabled,
    this.onError,
  });

  final AnalyticsConsentController controller;
  final AnalyticsRuntime runtime;
  final bool operationallyEnabled;
  final void Function(Object error)? onError;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!operationallyEnabled || !controller.isGranted) return;
    final event = AnalyticsEventPolicy.sanitize(
      name: name,
      parameters: parameters,
    );
    if (event == null) return;
    try {
      await runtime.initializeForGrantedConsent();
      if (!controller.isGranted) {
        await runtime.updateConsent(granted: false);
        return;
      }
      await runtime.logEvent(event);
    } catch (_) {
      onError?.call(StateError('analytics event failed'));
    }
  }
}
