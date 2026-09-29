import 'package:flutter/material.dart';

import 'feixe_geometry.dart';

/// A marca não herda as cores de acento dos cards. Usa branco ou preto.
/// Semantics fica a cargo do nome ao lado, para não anunciar a marca duas vezes.
class FarolMark extends StatelessWidget {
  const FarolMark({super.key, this.size = 24, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _FarolMarkPainter(color),
        ),
      );
}

class _FarolMarkPainter extends CustomPainter {
  const _FarolMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / feixeViewBox, size.height / feixeViewBox);
    for (final plane in feixePlanes) {
      canvas.drawPath(
        Path()..addPolygon(plane.points, true),
        Paint()..color = color.withValues(alpha: color.a * plane.opacity),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FarolMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
