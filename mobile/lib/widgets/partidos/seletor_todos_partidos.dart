import 'package:flutter/material.dart';

class SeletorTodosPartidos extends StatelessWidget {
  final bool selecionado;
  final int totalSelecionados;
  final int totalPartidos;
  final VoidCallback onTap;

  const SeletorTodosPartidos({
    super.key,
    required this.selecionado,
    required this.totalSelecionados,
    required this.totalPartidos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              selecionado ? const Color(0xFF2B2B2B) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado ? Colors.white : Colors.white24,
            width: selecionado ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selecionado
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Selecionar todos os partidos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$totalSelecionados/$totalPartidos',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
