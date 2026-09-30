abstract final class AnalyticsOperationalConfig {
  static const enabled =
      bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: false);
}
