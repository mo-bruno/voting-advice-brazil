import 'package:flutter/material.dart';

import '../../modelos/pergunta.dart';
import '../../modelos/resposta_quiz.dart';
import 'card_tema_peso.dart';

class ConteudoRevisaoQuiz extends StatelessWidget {
  final List<Pergunta> perguntas;
  final Map<int, RespostaQuiz> respostas;
  final Set<int> pesosDuplos;
  final int? idPerguntaEmEdicao;
  final ValueChanged<int> onAlternarPeso;
  final ValueChanged<Pergunta> onAlternarEdicao;
  final void Function(Pergunta pergunta, String answer) onAlterarResposta;

  const ConteudoRevisaoQuiz({
    super.key,
    required this.perguntas,
    required this.respostas,
    required this.pesosDuplos,
    required this.idPerguntaEmEdicao,
    required this.onAlternarPeso,
    required this.onAlternarEdicao,
    required this.onAlterarResposta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CabecalhoRevisao(),
        const SizedBox(height: 24),
        const Text(
          'Quais temas são especialmente importantes para você? Marque os temas que devem ter peso duplo no cálculo.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
        if (perguntas.isEmpty)
          const Text(
            'Nenhuma resposta foi encontrada para revisar.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 15,
            ),
          )
        else
          ...List.generate(perguntas.length, _criarCardPergunta),
      ],
    );
  }

  Widget _criarCardPergunta(int index) {
    final pergunta = perguntas[index];
    final resposta = respostas[pergunta.id];
    final marcado = pesosDuplos.contains(pergunta.id);

    return CardTemaPeso(
      numero: index + 1,
      pergunta: pergunta,
      resposta: resposta,
      marcado: marcado,
      editando: idPerguntaEmEdicao == pergunta.id,
      onAlternarPeso: () => onAlternarPeso(pergunta.id),
      onAlternarEdicao: () => onAlternarEdicao(pergunta),
      onAlterarResposta: (answer) => onAlterarResposta(
        pergunta,
        answer,
      ),
    );
  }
}

class _CabecalhoRevisao extends StatelessWidget {
  const _CabecalhoRevisao();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'PESO DOS\nTEMAS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'PASSO 2 DE 4',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
