abstract class AnalyticsSink {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });
}
