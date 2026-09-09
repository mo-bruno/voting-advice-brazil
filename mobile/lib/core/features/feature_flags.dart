class FeatureFlags {
  const FeatureFlags({required this.iotEnabled});

  final bool iotEnabled;

  static const environment = FeatureFlags(
    iotEnabled: bool.fromEnvironment(
      'IOT_FEATURE_ENABLED',
      defaultValue: false,
    ),
  );
}
