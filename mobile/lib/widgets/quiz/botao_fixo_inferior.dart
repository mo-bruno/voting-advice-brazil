import 'package:flutter/material.dart';

class BotaoFixoInferior extends StatelessWidget {
  final String texto;
  final bool preenchido;
  final VoidCallback onPressed;

  const BotaoFixoInferior({
    super.key,
    required this.texto,
    required this.preenchido,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: preenchido ? Colors.white : Colors.transparent,
          side: const BorderSide(
            color: Colors.white,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: preenchido ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
