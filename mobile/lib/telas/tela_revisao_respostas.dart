import 'package:flutter/material.dart';

import '../core/layout/app_scaffold.dart';
import '../modelos/pergunta.dart';
import '../modelos/resposta_quiz.dart';
import '../routes/app_routes.dart';
import '../widgets/quiz/conteudo_revisao_quiz.dart';
import '../widgets/quiz/rodape_revisao_quiz.dart';

class TelaRevisaoRespostas extends StatefulWidget {
  final List<Pergunta> perguntas;
  final Map<int, String> respostas;
  final Set<int> pesosDuplos;
  final ValueChanged<Set<int>> onPesosAlterados;

  const TelaRevisaoRespostas({
    super.key,
    required this.perguntas,
    required this.respostas,
    required this.pesosDuplos,
    required this.onPesosAlterados,
  });

  @override
  State<TelaRevisaoRespostas> createState() => _TelaRevisaoRespostasState();
}

class _TelaRevisaoRespostasState extends State<TelaRevisaoRespostas> {
  late final Set<int> _pesosDuplos;

  int? _idPerguntaEmEdicao;

  @override
  void initState() {
    super.initState();
    _pesosDuplos = {...widget.pesosDuplos};
  }

  List<Pergunta> get _perguntasRespondidas {
    return widget.perguntas.where((pergunta) {
      return widget.respostas.containsKey(pergunta.id);
    }).toList();
  }

  void _alternarPeso(int idPergunta) {
    setState(() {
      if (_pesosDuplos.contains(idPergunta)) {
        _pesosDuplos.remove(idPergunta);
      } else {
        _pesosDuplos.add(idPergunta);
      }
    });

    widget.onPesosAlterados(_pesosDuplos);
  }

  void _alternarEdicao(Pergunta pergunta) {
    setState(() {
      if (_idPerguntaEmEdicao == pergunta.id) {
        _idPerguntaEmEdicao = null;
      } else {
        _idPerguntaEmEdicao = pergunta.id;
      }
    });
  }

  void _alterarResposta(Pergunta pergunta, String answer) {
    setState(() {
      widget.respostas[pergunta.id] = answer;
      _idPerguntaEmEdicao = null;
    });

    widget.onPesosAlterados(_pesosDuplos);
  }

  void _continuarParaPartidos() {
    final respostasComPeso = widget.respostas.entries.map((entry) {
      return RespostaQuiz(
        thesisId: entry.key,
        answer: entry.value,
        weight: _pesosDuplos.contains(entry.key) ? 2 : 1,
      );
    }).toList();

    Navigator.pushNamed(
      context,
      AppRoutes.escolhaPartidos,
      arguments: EscolhaPartidosArgs(
        respostas: respostasComPeso,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perguntasRespondidas = _perguntasRespondidas;

    return AppScaffold(
      mostrarVoltar: true,
      titulo: 'Peso dos temas',
      larguraMaxima: 430,
      larguraMaximaTelaGrande: 760,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      paddingTelaGrande: const EdgeInsets.fromLTRB(40, 28, 40, 28),
      bodyBuilder: (context, telaGrande) {
        return ConteudoRevisaoQuiz(
          perguntas: perguntasRespondidas,
          respostas: widget.respostas,
          pesosDuplos: _pesosDuplos,
          idPerguntaEmEdicao: _idPerguntaEmEdicao,
          onAlternarPeso: _alternarPeso,
          onAlternarEdicao: _alternarEdicao,
          onAlterarResposta: _alterarResposta,
        );
      },
      footer: RodapeRevisaoQuiz(
        enviando: false,
        textoContinuar: 'ESCOLHER PARTIDOS',
        onContinuar: _continuarParaPartidos,
      ),
    );
  }
}
