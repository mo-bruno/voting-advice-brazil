import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/privacy/privacy_config.dart';

void main() {
  test('public privacy identity validation is token-bounded', () {
    expect(
      const PrivacyConfig(
        controllerName: 'Pessoa Controladora',
        contactEmail: 'privacidade@fpolitico.com.br',
      ).validationErrors,
      isEmpty,
    );
    expect(
      const PrivacyConfig(controllerName: '', contactEmail: '')
          .validationErrors,
      containsAll(['controllerName', 'contactEmail']),
    );
    expect(
      const PrivacyConfig(
        controllerName: 'Nome de Exemplo',
        contactEmail: 'privacy@example.com',
      ).validationErrors,
      containsAll(['controllerName', 'contactEmail']),
    );
    for (final name in [
      'Farol Político',
      'Farol-Político',
      'Nome de Exemplo,',
      'Nome (Teste)',
      'Teste',
      'test',
      'TODO',
      'TBD',
      'placeholder',
    ]) {
      expect(
        PrivacyConfig(
          controllerName: name,
          contactEmail: 'privacidade@fpolitico.com.br',
        ).validationErrors,
        contains('controllerName'),
        reason: name,
      );
    }
    expect(
      const PrivacyConfig(
        controllerName: 'Giovanni Testa',
        contactEmail: 'privacidade@fpolitico.com.br',
      ).validationErrors,
      isEmpty,
    );
  });

  test('release and smoke builds include all privacy definitions', () {
    final deploy =
        File('../.github/workflows/deploy-web.yml').readAsStringSync();
    final ci = File('../.github/workflows/ci.yml').readAsStringSync();
    for (final workflow in [deploy, ci]) {
      expect(workflow,
          contains('flutter build web --release --no-web-resources-cdn'));
      for (final define in [
        'IOT_FEATURE_ENABLED',
        'POLITICIAN_FOLLOW_ENABLED',
        'PUBLIC_APP_URL',
        'ANALYTICS_ENABLED',
        'PRIVACY_CONTROLLER_NAME',
        'PRIVACY_CONTACT_EMAIL',
      ]) {
        expect(workflow, contains('--dart-define=$define='));
      }
    }
    expect(deploy, contains('vars.PUBLIC_APP_URL'));
    expect(deploy, contains('vars.ANALYTICS_ENABLED'));
    expect(deploy, contains('vars.PRIVACY_CONTROLLER_NAME'));
    expect(deploy, contains('vars.PRIVACY_CONTACT_EMAIL'));
    expect(deploy.indexOf('name: Validate public privacy identity'),
        lessThan(deploy.indexOf('name: Build web release')));
    expect(deploy, contains('privacidade@fpolitico.com.br'));
    expect(deploy, contains('true|false'));
    expect(deploy, isNot(contains('*test*')));
    expect(deploy, isNot(contains('*teste*')));
    expect(ci, contains("- '.github/workflows/deploy-web.yml'"));
    expect(ci, contains("- 'firebase.json'"));
    for (final smoke in [
      '--dart-define=IOT_FEATURE_ENABLED=false',
      '--dart-define=POLITICIAN_FOLLOW_ENABLED=false',
      '--dart-define=ANALYTICS_ENABLED=true',
      '--dart-define=PUBLIC_APP_URL=https://example.invalid',
      '--dart-define=PRIVACY_CONTROLLER_NAME="Responsável de Teste"',
      '--dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid',
    ]) {
      expect(ci, contains(smoke));
    }
  });

  test('release shell gate accepts real-looking names and rejects placeholders',
      () async {
    final deploy =
        File('../.github/workflows/deploy-web.yml').readAsStringSync();
    final match = RegExp(
      r'- name: Validate public privacy identity\s+shell: bash\s+run: \|\s*\n((?:[ ]{10,}[^\n]*\n)+)',
    ).firstMatch(deploy);
    expect(match, isNotNull);
    final script = match!
        .group(1)!
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^ {10}'), ''))
        .join('\n');
    final bash =
        Platform.isWindows ? r'C:\Program Files\Git\bin\bash.exe' : 'bash';
    for (final (name, accepted) in [
      ('Giovanni Testa', true),
      ('Nome de Exemplo,', false),
      ('Nome (Teste)', false),
      ('Farol-Político', false),
    ]) {
      final result = await Process.run(bash, [
        '-c',
        script
      ], environment: {
        'PRIVACY_CONTROLLER_NAME': name,
        'PRIVACY_CONTACT_EMAIL': 'privacidade@fpolitico.com.br',
        'ANALYTICS_ENABLED': 'true',
        'PUBLIC_APP_URL': 'https://fpolitico.com.br',
      });
      expect(result.exitCode == 0, accepted,
          reason: '$name: ${result.stdout} ${result.stderr}');
    }
  });

  test('mutable web entrypoints are not cached across consent changes', () {
    final hosting = jsonDecode(File('../firebase.json').readAsStringSync())
        as Map<String, dynamic>;
    final headers = (hosting['hosting'] as Map<String, dynamic>)['headers']
        as List<dynamic>;
    const sources = [
      '/',
      '/index.html',
      '/flutter_bootstrap.js',
      '/flutter_service_worker.js',
      '/main.dart.js',
      '/version.json',
    ];
    for (final source in sources) {
      final matches = headers
          .cast<Map<String, dynamic>>()
          .where((entry) => entry['source'] == source)
          .toList();
      expect(matches, hasLength(1), reason: source);
      expect(matches.single['headers'], [
        {
          'key': 'Cache-Control',
          'value': 'no-cache, max-age=0, must-revalidate',
        },
      ]);
    }
  });
}
