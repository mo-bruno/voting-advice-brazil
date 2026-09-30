import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';

void main() {
  test('web bootstrap starts with only the denied consent command', () {
    final index = File('web/index.html').readAsStringSync();
    final workflow =
        File('../.github/workflows/deploy-web.yml').readAsStringSync();
    expect(index, contains("gtag('consent', 'default'"));
    for (final field in [
      'analytics_storage',
      'ad_storage',
      'ad_user_data',
      'ad_personalization',
    ]) {
      expect(index, contains("'$field': 'denied'"));
    }
    expect(index.indexOf("gtag('consent', 'default'"),
        lessThan(index.indexOf('<script src="flutter_bootstrap.js"')));
    for (final forbidden in [
      'googletagmanager.com/gtag/js',
      "gtag('js'",
      "gtag('config'",
      "gtag('event'",
    ]) {
      expect(index, isNot(contains(forbidden)));
    }
    expect(workflow, contains('--no-web-resources-cdn'));
    expect(workflow, contains('--dart-define=ANALYTICS_ENABLED='));
  });

  test('Flutter and Android startup keep collection off', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(mainSource, isNot(contains('Firebase.initializeApp')));
    expect(manifest, contains('firebase_analytics_collection_enabled'));
    expect(manifest, contains('android:value="false"'));
    final analyticsSources = Directory('lib/core/analytics')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final forbidden in ["gtag('js'", "gtag('config'", "gtag('event'"]) {
      expect(analyticsSources, isNot(contains(forbidden)));
    }
  });

  test('Inter fonts and license are bundled for app and exporter', () {
    final themeSource =
        File('lib/core/theme/app_theme.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final brandExporter =
        File('tool/generate_web_brand_assets.py').readAsStringSync();
    final brandReadme = File('branding/README.md').readAsStringSync();
    expect(themeSource, isNot(contains('GoogleFonts')));
    expect(themeSource, isNot(contains('package:google_fonts')));
    expect(pubspec, isNot(contains('google_fonts:')));
    expect(pubspec, contains('family: Inter'));
    for (final name in [
      'Inter-Regular.ttf',
      'Inter-SemiBold.ttf',
      'Inter-ExtraBold.ttf',
      'Inter-OFL.txt',
      'Inter-SOURCES.md',
    ]) {
      expect(File('assets/fonts/$name').existsSync(), isTrue);
      expect(pubspec, contains('assets/fonts/$name'));
    }
    expect(brandExporter, contains('ROOT / "assets/fonts"'));
    expect(brandExporter, contains('assets/fonts/Inter-OFL.txt'));
    expect(brandExporter, isNot(contains('test/fixtures/fonts')));
    expect(brandReadme, contains('mobile/assets/fonts'));
    expect(brandReadme, contains('tema Flutter'));
    expect(brandReadme, contains('exportador'));
    expect(brandReadme, isNot(contains('mobile/test/fixtures/fonts')));
    expect(AppTheme.dark.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('test sources no longer require runtime Google fonts', () {
    final files = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) =>
            !file.path.endsWith('analytics_bootstrap_files_test.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('package:google_fonts')),
          reason: file.path);
      expect(source, isNot(contains('GoogleFonts.')), reason: file.path);
      expect(source, isNot(contains('test/fixtures/fonts')), reason: file.path);
      for (final suffix in ['regular', '600', '800']) {
        expect(source, isNot(contains('Inter_$suffix')), reason: file.path);
      }
    }
  });
}
