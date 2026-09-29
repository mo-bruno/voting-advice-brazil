class FeatureFlags {
  const FeatureFlags({
    required this.iotEnabled,
    this.politicianFollowEnabled = false,
  });

  final bool iotEnabled;
  final bool politicianFollowEnabled;

  static const environment = FeatureFlags(
    iotEnabled: bool.fromEnvironment(
      'IOT_FEATURE_ENABLED',
      defaultValue: false,
    ),
    politicianFollowEnabled: bool.fromEnvironment(
      'POLITICIAN_FOLLOW_ENABLED',
      defaultValue: false,
    ),
  );
}
