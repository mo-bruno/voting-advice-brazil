import 'package:flutter/material.dart';

import '../../modelos/partido.dart';
import '../imagem_politica.dart';

class CardPartido extends StatelessWidget {
  final Partido partido;
  final bool selecionado;
  final VoidCallback onTap;
  final VoidCallback onMostrarDetalhe;

  const CardPartido({
    super.key,
    required this.partido,
    required this.selecionado,
    required this.onTap,
    required this.onMostrarDetalhe,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              selecionado ? const Color(0xFF252525) : const Color(0xFF151515),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selecionado ? Colors.white70 : Colors.white12,
            width: selecionado ? 1.35 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: _BotaoDetalhePartido(onPressed: onMostrarDetalhe),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: selecionado ? 1 : 0,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ImagemPolitica(
                    url: partido.logoUrl,
                    fallbackText: partido.sigla,
                    size: 58,
                    circular: false,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    partido.sigla,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoDetalhePartido extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotaoDetalhePartido({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: 'Ver detalhes',
        padding: EdgeInsets.zero,
        splashRadius: 18,
        onPressed: onPressed,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Colors.white70,
          size: 24,
        ),
      ),
    );
  }
}
