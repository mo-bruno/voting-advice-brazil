import 'package:flutter/foundation.dart';

import 'analytics_consent_controller.dart';
import 'analytics_operational_config.dart';
import 'analytics_sink.dart';
import 'consent_aware_analytics_sink.dart';
import 'firebase_analytics_runtime.dart';

void _reportGenericAnalyticsError(Object error) {
  if (kDebugMode) {
    debugPrint('Analytics operation failed (${error.runtimeType}).');
  }
}

class AnalyticsDependencies {
  AnalyticsDependencies._({required this.controller, required this.sink});

  static final instance = AnalyticsDependencies._production();

  factory AnalyticsDependencies._production() {
    const operationallyEnabled = AnalyticsOperationalConfig.enabled;
    final runtime = FirebaseAnalyticsRuntime(
      operationallyEnabled: operationallyEnabled,
      onError: _reportGenericAnalyticsError,
    );
    final controller = AnalyticsConsentController(
      store: SharedPreferencesAnalyticsConsentStore(),
      effects: runtime,
      onError: _reportGenericAnalyticsError,
    );
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: operationallyEnabled,
      onError: _reportGenericAnalyticsError,
    );
    return AnalyticsDependencies._(controller: controller, sink: sink);
  }

  @visibleForTesting
  factory AnalyticsDependencies.testOnly({
    required AnalyticsConsentController controller,
    required AnalyticsSink sink,
  }) = AnalyticsDependencies._;

  final AnalyticsConsentController controller;
  final AnalyticsSink sink;
}
