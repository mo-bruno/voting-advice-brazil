import 'package:flutter/material.dart';

import 'farol_mark.dart';

/// Assinatura compacta para os títulos institucionais, inclusive em 320 px.
class FarolWordmark extends StatelessWidget {
  const FarolWordmark({
    super.key,
    this.label = 'FAROL POLÍTICO',
    this.fontSize = 14,
    this.markSize = 26,
  });

  final String label;
  final double fontSize;
  final double markSize;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FarolMark(size: markSize),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                )),
          ],
        ),
      );
}
