class PrivacyConfig {
  const PrivacyConfig({
    required this.controllerName,
    required this.contactEmail,
  });

  final String controllerName;
  final String contactEmail;

  List<String> get validationErrors {
    final errors = <String>[];
    final tokens = controllerName
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((token) => token.isNotEmpty)
        .toList();
    const placeholders = {
      'exemplo',
      'example',
      'teste',
      'test',
      'todo',
      'tbd',
      'placeholder',
    };
    final compact = tokens.join();
    if (tokens.isEmpty ||
        tokens.any(placeholders.contains) ||
        compact == 'farolpolítico' ||
        compact == 'farolpolitico') {
      errors.add('controllerName');
    }
    final email = contactEmail.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email.toLowerCase().contains('example')) {
      errors.add('contactEmail');
    }
    return errors;
  }

  static const environment = PrivacyConfig(
    controllerName: String.fromEnvironment('PRIVACY_CONTROLLER_NAME'),
    contactEmail: String.fromEnvironment('PRIVACY_CONTACT_EMAIL'),
  );
}
