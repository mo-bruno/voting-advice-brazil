import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom interactive surfaces use semantic Material tap widgets', () {
    final offenders = _dartSources()
        .where((file) => file.readAsStringSync().contains('GestureDetector('))
        .map((file) => file.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Use InkWell or a shared semantic tap widget instead.',
    );
  });

  test('text fields expose persistent labels', () {
    final offenders = <String>[];

    for (final file in _dartSources()) {
      final source = file.readAsStringSync();
      var index = source.indexOf('TextField(');
      while (index != -1) {
        final call = _balancedCall(source, index);
        if (call != null && !call.contains('labelText:')) {
          offenders.add('${file.path}:${_lineNumber(source, index)}');
        }
        index = source.indexOf('TextField(', index + 1);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'TextField widgets need labelText, not only hint text.',
    );
  });
}

Iterable<File> _dartSources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

String? _balancedCall(String source, int start) {
  var depth = 0;
  for (var index = start; index < source.length; index++) {
    final char = source[index];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) {
        return source.substring(start, index + 1);
      }
    }
  }
  return null;
}

int _lineNumber(String source, int index) {
  return '\n'.allMatches(source.substring(0, index)).length + 1;
}
