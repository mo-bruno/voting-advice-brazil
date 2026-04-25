import 'package:flutter/material.dart';

import '../../modelos/resultado_quiz.dart';
import '../../services/quiz_service.dart';
import '../imagem_politica.dart';
import 'badge_ranking.dart';
import 'detalhes_resultado_quiz.dart';

class CardResultadoQuiz extends StatefulWidget {
  final ResultadoQuiz resultado;

  const CardResultadoQuiz({
    super.key,
    required this.resultado,
  });

  @override
  State<CardResultadoQuiz> createState() => _CardResultadoQuizState();
}

class _CardResultadoQuizState extends State<CardResultadoQuiz> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final resultado = widget.resultado;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: _decoracao(resultado.rank),
      child: Column(
        children: [
          _ResumoResultado(
            resultado: resultado,
            expandido: _expandido,
            onAlternarDetalhes: _alternarDetalhes,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _expandido
                ? DetalhesResultadoQuiz(
                    key: const ValueKey('detalhes'),
                    resultado: resultado,
                  )
                : const SizedBox.shrink(key: ValueKey('fechado')),
          ),
        ],
      ),
    );
  }

  void _alternarDetalhes() {
    setState(() {
      _expandido = !_expandido;
    });
  }

  BoxDecoration _decoracao(int rank) {
    return BoxDecoration(
      color: rank == 1 ? const Color(0xFF2B2B2B) : const Color(0xFF202020),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: rank == 1 ? Colors.white : const Color(0xFF3A3A3A),
        width: rank == 1 ? 1.4 : 1,
      ),
    );
  }
}

class _ResumoResultado extends StatelessWidget {
  final ResultadoQuiz resultado;
  final bool expandido;
  final VoidCallback onAlternarDetalhes;

  const _ResumoResultado({
    required this.resultado,
    required this.expandido,
    required this.onAlternarDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    final percentual = resultado.scorePercent.toStringAsFixed(1);
    final logoUrl = QuizService.resolverUrlLogoPartido(resultado.party);
    final logoUrlApi = QuizService.resolverUrlMidia(resultado.partyLogo);

    return Row(
      children: [
        BadgeRanking(rank: resultado.rank),
        const SizedBox(width: 12),
        ImagemPolitica(
          url: logoUrl,
          urlSecundaria: logoUrlApi,
          fallbackText: resultado.party,
          size: 58,
          circular: false,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 14),
        Expanded(child: _TextoResultado(resultado: resultado)),
        const SizedBox(width: 12),
        Text(
          '$percentual%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        _BotaoDetalhesResultado(
          expandido: expandido,
          onPressed: onAlternarDetalhes,
        ),
      ],
    );
  }
}

class _TextoResultado extends StatelessWidget {
  final ResultadoQuiz resultado;

  const _TextoResultado({required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resultado.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          resultado.party,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BotaoDetalhesResultado extends StatelessWidget {
  final bool expandido;
  final VoidCallback onPressed;

  const _BotaoDetalhesResultado({
    required this.expandido,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: expandido ? 'Fechar ideias' : 'Ver ideias',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        backgroundColor: expandido ? Colors.white : const Color(0xFF111111),
        side: BorderSide(
          color: expandido ? Colors.white : Colors.white24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(
        expandido ? Icons.remove_rounded : Icons.add_rounded,
        color: expandido ? Colors.black : Colors.white,
        size: 22,
      ),
    );
  }
}
