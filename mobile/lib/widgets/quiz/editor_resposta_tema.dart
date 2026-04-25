import 'package:flutter/material.dart';

import '../../modelos/resposta_quiz.dart';

class EditorRespostaTema extends StatelessWidget {
  final String? respostaAtual;
  final ValueChanged<String> onAlterarResposta;

  const EditorRespostaTema({
    super.key,
    required this.respostaAtual,
    required this.onAlterarResposta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BotaoRespostaInline(
              icone: Icons.close_rounded,
              selecionado: respostaAtual == RespostaQuizValor.discordo,
              onTap: () => onAlterarResposta(RespostaQuizValor.discordo),
            ),
            const SizedBox(width: 16),
            _BotaoRespostaInline(
              icone: Icons.remove_rounded,
              selecionado: respostaAtual == RespostaQuizValor.neutro,
              onTap: () => onAlterarResposta(RespostaQuizValor.neutro),
            ),
            const SizedBox(width: 16),
            _BotaoRespostaInline(
              icone: Icons.check_rounded,
              selecionado: respostaAtual == RespostaQuizValor.concordo,
              onTap: () => onAlterarResposta(RespostaQuizValor.concordo),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoRespostaInline extends StatelessWidget {
  final IconData icone;
  final bool selecionado;
  final VoidCallback onTap;

  const _BotaoRespostaInline({
    required this.icone,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : const Color(0xFF0F0F0F),
          shape: BoxShape.circle,
          border: Border.all(
            color: selecionado ? Colors.white : Colors.white38,
          ),
        ),
        child: Icon(
          icone,
          color: selecionado ? Colors.black : Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
