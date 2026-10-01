import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bundle ships the Flutter emoji and symbol fallbacks locally', () {
    const emojiStem = 'notocoloremoji/v32/'
        'Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn';
    const symbolPath = 'notosanssymbols/v43/'
        'rP2up3q65FkAtHfwd-eIS2brbDN6gxP34F9jRRCe4W3gfQ8gb_VFRkzrbQ.woff2';
    final requiredPaths = <String>[
      for (var index = 0; index < 12; index++) '$emojiStem.$index.woff2',
      symbolPath,
    ];
    final root = Directory('web/font-fallbacks');
    expect(root.existsSync(), isTrue,
        reason: 'fontFallbackBaseUrl must resolve to bundled files');

    final manifestFile = File('${root.path}/SOURCES.json');
    expect(manifestFile.existsSync(), isTrue);
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['flutterVersion'], '3.41.6');
    expect(
      manifest['runtimeSource'],
      'https://github.com/flutter/flutter/blob/'
      'db50e20168db8fee486b9abf32fc912de3bc5b6a/'
      'engine/src/flutter/lib/web_ui/lib/src/engine/'
      'font_fallback_data.dart',
    );

    final assets = <String, Map<String, dynamic>>{
      for (final rawEntry in manifest['assets'] as List<dynamic>)
        (rawEntry as Map<String, dynamic>)['path'] as String: rawEntry,
    };
    expect(assets.keys.toSet(), requiredPaths.toSet());

    for (final relativePath in requiredPaths) {
      final entry = assets[relativePath]!;
      final asset = File('${root.path}/$relativePath');
      expect(asset.existsSync(), isTrue, reason: relativePath);
      final bytes = asset.readAsBytesSync();
      expect(bytes.length, entry['bytes'], reason: relativePath);
      expect(bytes.length, greaterThan(1024), reason: relativePath);
      expect(bytes.take(4), orderedEquals(utf8.encode('wOF2')),
          reason: relativePath);
      expect(
        entry['source'],
        'https://fonts.gstatic.com/s/$relativePath',
        reason: relativePath,
      );

      final checksum = Process.runSync('sha256sum', [asset.path]);
      expect(checksum.exitCode, 0, reason: checksum.stderr as String?);
      final actualSha256 = (checksum.stdout as String).split(' ').first;
      expect(entry['sha256'], actualSha256, reason: relativePath);

      final license = File('${root.path}/${entry['license']}');
      expect(license.existsSync(), isTrue, reason: relativePath);
      expect(
        license.readAsStringSync(),
        contains('SIL OPEN FONT LICENSE Version 1.1'),
        reason: relativePath,
      );
    }

    expect(
      manifest['licenseSources'],
      {
        'notocoloremoji/OFL.txt': 'https://github.com/google/fonts/blob/main/'
            'ofl/notocoloremoji/OFL.txt',
        'notosanssymbols/OFL.txt': 'https://github.com/google/fonts/blob/main/'
            'ofl/notosanssymbols/OFL.txt',
      },
    );
  });
}
