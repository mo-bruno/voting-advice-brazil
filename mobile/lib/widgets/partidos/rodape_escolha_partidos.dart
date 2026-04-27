import 'package:flutter/material.dart';

class RodapeEscolhaPartidos extends StatelessWidget {
  final bool enviando;
  final bool podeContinuar;
  final int selecionados;
  final int total;
  final VoidCallback onContinuar;

  const RodapeEscolhaPartidos({
    super.key,
    required this.enviando,
    required this.podeContinuar,
    required this.selecionados,
    required this.total,
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
          top: BorderSide(color: Color(0xFF242424)),
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
                  : SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: podeContinuar ? onContinuar : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              podeContinuar ? Colors.white : Colors.transparent,
                          disabledForegroundColor: Colors.white38,
                          side: BorderSide(
                            color:
                                podeContinuar ? Colors.white : Colors.white24,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          podeContinuar
                              ? 'VER RESULTADO ($selecionados/$total)'
                              : 'SELECIONE PELO MENOS UM PARTIDO',
                          style: TextStyle(
                            color:
                                podeContinuar ? Colors.black : Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
