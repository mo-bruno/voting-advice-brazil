// Run from mobile/: flutter test tool/render_brand_previews.dart
// Exports the real Flutter card, with fictional data, for visual review.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_data.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_palette.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';

void main() {
  final data = ResultShareData(
    results: List.generate(
      10,
      (index) => CandidateResult(
        candidateId: 'example-$index',
        name: 'Candidatura ${String.fromCharCode(65 + index)}',
        party: 'Exemplo fictício',
        scorePercent: 87.5 - index * 3,
        rank: index + 1,
        matches: const [],
        countedTheses: 20,
        answeredTheses: 30,
      ),
    ),
  );
  final samples = [
    (
      'azul-post',
      ResultSharePalette.blue,
      ResultShareFormat.post,
      ResultShareVariant.leader,
      14.0
    ),
    (
      'verde-ranking',
      ResultSharePalette.green,
      ResultShareFormat.story,
      ResultShareVariant.topFive,
      38.0
    ),
    (
      'preto-story',
      ResultSharePalette.black,
      ResultShareFormat.story,
      ResultShareVariant.leader,
      64.0
    ),
    (
      'branco-top10',
      ResultSharePalette.white,
      ResultShareFormat.post,
      ResultShareVariant.topTen,
      45.0
    ),
    (
      'limite-10',
      ResultSharePalette.black,
      ResultShareFormat.story,
      ResultShareVariant.leader,
      10.0
    ),
    (
      'limite-70',
      ResultSharePalette.black,
      ResultShareFormat.story,
      ResultShareVariant.leader,
      70.0
    ),
  ];

  testWidgets('exporta as aplicações reais da marca para revisão',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(ResultShareCard.loadFonts);
    final output = Directory(
        '../docs/previews/brand-directions/feixe-refinado/implementado');
    output.createSync(recursive: true);
    for (final (name, palette, format, variant, angle) in samples) {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: ResultShareCard(
                data: data.withVariant(variant),
                format: format,
                palette: palette,
                beamAngle: angle,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: name);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 3);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
}
