import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publica metadados completos para previews sociais', () {
    final html = File('web/index.html').readAsStringSync();

    expect(_metaContent(html, property: 'og:type'), 'website');
    expect(_metaContent(html, property: 'og:url'), 'https://fpolitico.com.br/');
    expect(_metaContent(html, property: 'og:image'),
        'https://fpolitico.com.br/og-preview.png');
    expect(_metaContent(html, property: 'og:image:secure_url'),
        'https://fpolitico.com.br/og-preview.png');
    expect(_metaContent(html, property: 'og:image:type'), 'image/png');
    expect(_metaContent(html, property: 'og:image:width'), '1200');
    expect(_metaContent(html, property: 'og:image:height'), '630');
    expect(_metaContent(html, property: 'og:image:alt'),
        contains('Farol Político'));
    expect(_metaContent(html, name: 'twitter:card'), 'summary_large_image');
    expect(_metaContent(html, name: 'twitter:image'),
        'https://fpolitico.com.br/og-preview.png');
    expect(html,
        contains('<link rel="canonical" href="https://fpolitico.com.br/">'));
  });

  test('usa a identidade do Farol Político no manifesto instalável', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

    expect(manifest['name'], 'Farol Político');
    expect(manifest['short_name'], 'Farol Político');
    expect(manifest['description'], contains('Presidência de 2026'));
    expect(manifest['background_color'], '#131313');
    expect(manifest['theme_color'], '#131313');
  });

  test('fornece imagens nas dimensões exigidas por navegadores e redes', () {
    expect(_pngSize('web/favicon.png'), (64, 64));
    expect(_pngSize('web/icons/apple-touch-icon.png'), (180, 180));
    expect(_pngSize('web/icons/Icon-192.png'), (192, 192));
    expect(_pngSize('web/icons/Icon-512.png'), (512, 512));
    expect(_pngSize('web/icons/Icon-maskable-192.png'), (192, 192));
    expect(_pngSize('web/icons/Icon-maskable-512.png'), (512, 512));
    expect(_pngSize('web/og-preview.png'), (1200, 630));
  });
}

String? _metaContent(String html, {String? property, String? name}) {
  final key = property != null ? 'property' : 'name';
  final value = property ?? name;
  final tag = RegExp(
    '<meta\\s+[^>]*$key="${RegExp.escape(value!)}"[^>]*>',
    caseSensitive: false,
  ).firstMatch(html)?.group(0);
  return tag == null
      ? null
      : RegExp('content="([^"]*)"', caseSensitive: false)
          .firstMatch(tag)
          ?.group(1);
}

(int, int) _pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.length, greaterThanOrEqualTo(24), reason: '$path inválido');
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}
