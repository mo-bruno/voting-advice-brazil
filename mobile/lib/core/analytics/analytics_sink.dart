abstract class AnalyticsSink {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });
}

/// Optional capability for sinks that invalidate in-flight work when consent
/// changes. Sinks without consent state simply keep their current behavior.
abstract interface class ConsentBindableAnalyticsSink {
  AnalyticsSink captureConsentBoundSink();
}

extension AnalyticsSinkConsentBinding on AnalyticsSink {
  AnalyticsSink bindToCurrentConsent() {
    final sink = this;
    if (sink is ConsentBindableAnalyticsSink) {
      return (sink as ConsentBindableAnalyticsSink).captureConsentBoundSink();
    }
    return sink;
  }
}
