import 'package:flutter/material.dart';

class BotaoFixoInferior extends StatelessWidget {
  final String texto;
  final bool preenchido;
  final VoidCallback? onPressed;

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
          backgroundColor: onPressed == null
              ? const Color(0xFF1A1A1A)
              : (preenchido ? Colors.white : Colors.transparent),
          disabledBackgroundColor: const Color(0xFF1A1A1A),
          disabledForegroundColor: Colors.white38,
          side: BorderSide(
            color: onPressed == null ? Colors.white24 : Colors.white,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: onPressed == null
                ? Colors.white38
                : (preenchido ? Colors.black : Colors.white),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
