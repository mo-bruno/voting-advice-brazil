import 'package:flutter/material.dart';

class BotaoContorno extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotaoContorno({
    super.key,
    required this.texto,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: onPressed == null
              ? const Color(0xFF171717)
              : const Color(0xFF0F0F0F),
          disabledBackgroundColor: const Color(0xFF171717),
          disabledForegroundColor: Colors.white38,
          side: BorderSide(
            color: onPressed == null ? Colors.white24 : Colors.white54,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: onPressed == null ? Colors.white38 : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
