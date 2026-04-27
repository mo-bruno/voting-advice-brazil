import 'package:flutter/material.dart';

class BotaoAcaoQuiz extends StatelessWidget {
  final IconData icone;
  final VoidCallback onTap;

  const BotaoAcaoQuiz({
    super.key,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(
          icone,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
