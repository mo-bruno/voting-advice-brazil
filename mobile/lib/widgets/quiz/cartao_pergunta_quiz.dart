import 'package:flutter/material.dart';
import '../../modelos/pergunta.dart';
import 'botao_acao_quiz.dart';

class CartaoPerguntaQuiz extends StatelessWidget {
  final Pergunta pergunta;
  final int numeroPergunta;
  final int totalPerguntas;
  final bool telaGrande;
  final VoidCallback onDiscordar;
  final VoidCallback onNeutro;
  final VoidCallback onConcordar;
  final bool podeVoltarPergunta;
  final VoidCallback onVoltarPergunta;

  const CartaoPerguntaQuiz({
    super.key,
    required this.pergunta,
    required this.numeroPergunta,
    required this.totalPerguntas,
    required this.telaGrande,
    required this.onDiscordar,
    required this.onNeutro,
    required this.onConcordar,
    required this.podeVoltarPergunta,
    required this.onVoltarPergunta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          _TopoCartaoPergunta(
            numeroPergunta: numeroPergunta,
            totalPerguntas: totalPerguntas,
            podeVoltarPergunta: podeVoltarPergunta,
            onVoltarPergunta: onVoltarPergunta,
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: telaGrande ? 220 : 180,
            child: Center(
              child: Text(
                pergunta.texto,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: telaGrande ? 24 : 20,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BotaoAcaoQuiz(
                icone: Icons.close_rounded,
                onTap: onDiscordar,
              ),
              const SizedBox(width: 18),
              BotaoAcaoQuiz(
                icone: Icons.remove_rounded,
                onTap: onNeutro,
              ),
              const SizedBox(width: 18),
              BotaoAcaoQuiz(
                icone: Icons.check_rounded,
                onTap: onConcordar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopoCartaoPergunta extends StatelessWidget {
  final int numeroPergunta;
  final int totalPerguntas;
  final bool podeVoltarPergunta;
  final VoidCallback onVoltarPergunta;

  const _TopoCartaoPergunta({
    required this.numeroPergunta,
    required this.totalPerguntas,
    required this.podeVoltarPergunta,
    required this.onVoltarPergunta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: podeVoltarPergunta ? 1 : 0,
            child: IconButton(
              tooltip: 'Voltar pergunta',
              padding: EdgeInsets.zero,
              splashRadius: 22,
              onPressed: podeVoltarPergunta ? onVoltarPergunta : null,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 21,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: _ContadorPergunta(
              numeroPergunta: numeroPergunta,
              totalPerguntas: totalPerguntas,
            ),
          ),
        ),
        const SizedBox(width: 42, height: 42),
      ],
    );
  }
}

class _ContadorPergunta extends StatelessWidget {
  final int numeroPergunta;
  final int totalPerguntas;

  const _ContadorPergunta({
    required this.numeroPergunta,
    required this.totalPerguntas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$numeroPergunta/$totalPerguntas',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
