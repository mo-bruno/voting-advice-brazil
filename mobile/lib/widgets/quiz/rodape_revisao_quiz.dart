import 'package:flutter/material.dart';
import 'botao_fixo_inferior.dart';

class RodapeRevisaoQuiz extends StatelessWidget {
  final bool enviando;
  final String textoContinuar;
  final VoidCallback onContinuar;

  const RodapeRevisaoQuiz({
    super.key,
    required this.enviando,
    this.textoContinuar = 'CONTINUAR PARA RESULTADO',
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        border: Border(
          top: BorderSide(
            color: Color(0xFF242424),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: enviando
                  ? const SizedBox(
                      height: 46,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : BotaoFixoInferior(
                      texto: textoContinuar,
                      preenchido: true,
                      onPressed: onContinuar,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
