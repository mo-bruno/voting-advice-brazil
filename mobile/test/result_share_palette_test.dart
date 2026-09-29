import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_palette.dart';

void _expectReadable(ResultSharePalette palette) {
  final beam = Color.alphaBlend(palette.beamOverlay, palette.background);
  final edge = Color.alphaBlend(palette.beamEdgeOverlay, beam);
  for (final surface in [palette.background, beam, edge]) {
    for (final textColor in [palette.foreground, palette.accent]) {
      final textLuminance = textColor.computeLuminance();
      final surfaceLuminance = surface.computeLuminance();
      final contrast = (max(textLuminance, surfaceLuminance) + .05) /
          (min(textLuminance, surfaceLuminance) + .05);
      expect(contrast, greaterThanOrEqualTo(4.5),
          reason: '${palette.label}: texto $textColor sobre $surface');
    }
  }
}

void main() {
  test('as 12 paletas preservam texto e percentuais legíveis sobre os feixes',
      () {
    expect(ResultSharePalette.values.map((palette) => palette.label), [
      'Azul',
      'Roxo',
      'Verde',
      'Coral',
      'Vermelho',
      'Laranja',
      'Amarelo',
      'Rosa',
      'Ciano',
      'Preto',
      'Branco',
      'Marrom',
    ]);
    for (final palette in ResultSharePalette.values) {
      _expectReadable(palette);
    }
  });
}
