import 'package:flutter/material.dart';

import '../../modelos/resultado_quiz.dart';

class DetalhesResultadoQuiz extends StatelessWidget {
  final ResultadoQuiz resultado;

  const DetalhesResultadoQuiz({
    super.key,
    required this.resultado,
  });

  @override
  Widget build(BuildContext context) {
    final ideias = resultado.matches
        .where((match) => match.candidatePosition != 'sem_posicao')
        .take(4)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: ideias.isEmpty
          ? const Text(
              'Ainda não há posições detalhadas para este representante.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
                height: 1.45,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Algumas ideias e posições',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...ideias.map(_ItemIdeiaResultado.new),
              ],
            ),
    );
  }
}

class _ItemIdeiaResultado extends StatelessWidget {
  final ResultadoMatch match;

  const _ItemIdeiaResultado(this.match);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              match.textoPosicao,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.thesisText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match.textoCompatibilidade,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
