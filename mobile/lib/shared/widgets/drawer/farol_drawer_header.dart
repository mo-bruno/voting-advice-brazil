// lib/shared/widgets/drawer/farol_drawer_header.dart
//
// A marca, mais o halo que a gaveta usa para dizer a cor do LED antes de
// qualquer palavra ser lida. O halo e a razao de o cabecalho ter deixado de ser
// um DrawerHeader padrao: ele precisa desenhar atras do texto.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'farol_led_state.dart';

class FarolDrawerHeader extends StatelessWidget {
  const FarolDrawerHeader({super.key, required this.state});

  final FarolLedState state;

  @override
  Widget build(BuildContext context) {
    final alpha = state.haloAlpha;

    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.outlineVariant),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (alpha > 0)
            Container(
              key: const Key('farol-drawer-halo'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  // Nasce fora do canto superior esquerdo, como se a luz viesse
                  // de tras da marca em vez de estar impressa nela.
                  center: const Alignment(-0.76, -0.88),
                  radius: 1.1,
                  colors: [
                    state.color.withValues(alpha: alpha),
                    state.color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'FAROL\nPOLÍTICO',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    height: 1.0,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BRASIL 2026',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
