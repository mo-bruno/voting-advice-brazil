class PrivacyConfig {
  const PrivacyConfig({
    required this.controllerName,
    required this.contactEmail,
  });

  final String controllerName;
  final String contactEmail;

  static const environment = PrivacyConfig(
    controllerName: String.fromEnvironment('PRIVACY_CONTROLLER_NAME'),
    contactEmail: String.fromEnvironment('PRIVACY_CONTACT_EMAIL'),
  );
}
