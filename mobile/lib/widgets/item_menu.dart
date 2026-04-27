import 'package:flutter/material.dart';

class ItemMenu extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback onTap;
  final bool destacado;

  const ItemMenu({
    super.key,
    required this.icone,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final corFundo = destacado ? const Color(0xFF151515) : Colors.transparent;
    final corBorda = destacado ? Colors.white12 : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: corBorda),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(
            icone,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitulo == null
            ? null
            : Text(
                subtitulo!,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white38,
          size: 14,
        ),
      ),
    );
  }
}
