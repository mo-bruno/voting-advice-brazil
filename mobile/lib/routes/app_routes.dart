import 'package:flutter/material.dart';
import '../modelos/pergunta.dart';
import '../modelos/resposta_quiz.dart';
import '../modelos/resultado_quiz.dart';
import '../telas/tela_escolha_partidos.dart';
import '../telas/tela_inicial.dart';
import '../telas/tela_pergunta_quiz.dart';
import '../telas/tela_resultado_quiz.dart';
import '../telas/tela_revisao_respostas.dart';
import '../telas/tela_sobre.dart';
import '../telas/tela_tutorial_quiz.dart';

class AppRoutes {
  static const String inicial = '/';
  static const String sobre = '/sobre';
  static const String tutorial = '/tutorial';
  static const String perguntaQuiz = '/pergunta-quiz';
  static const String revisaoRespostas = '/revisao-respostas';
  static const String escolhaPartidos = '/escolha-partidos';
  static const String resultadoQuiz = '/resultado-quiz';

  static final Map<String, WidgetBuilder> routes = {
    inicial: (_) => const TelaInicial(),
    sobre: (_) => const TelaSobre(),
    tutorial: (_) => const TelaTutorialQuiz(),
    perguntaQuiz: (_) => const TelaPerguntaQuiz(),
    revisaoRespostas: _buildRevisaoRespostas,
    escolhaPartidos: _buildEscolhaPartidos,
    resultadoQuiz: _buildResultadoQuiz,
  };

  static Widget _buildRevisaoRespostas(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is RevisaoRespostasArgs) {
      return TelaRevisaoRespostas(
        perguntas: args.perguntas,
        respostas: args.respostas,
        pesosDuplos: args.pesosDuplos,
        onPesosAlterados: args.onPesosAlterados,
      );
    }

    return TelaRevisaoRespostas(
      perguntas: const [],
      respostas: const {},
      pesosDuplos: const {},
      onPesosAlterados: (_) {},
    );
  }

  static Widget _buildEscolhaPartidos(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is EscolhaPartidosArgs) {
      return TelaEscolhaPartidos(respostas: args.respostas);
    }

    return const TelaEscolhaPartidos(respostas: []);
  }

  static Widget _buildResultadoQuiz(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is ResultadoQuizArgs) {
      return TelaResultadoQuiz(resultados: args.resultados);
    }

    return const TelaResultadoQuiz(resultados: []);
  }
}

class RevisaoRespostasArgs {
  final List<Pergunta> perguntas;
  final Map<int, String> respostas;
  final Set<int> pesosDuplos;
  final ValueChanged<Set<int>> onPesosAlterados;

  const RevisaoRespostasArgs({
    required this.perguntas,
    required this.respostas,
    required this.pesosDuplos,
    required this.onPesosAlterados,
  });
}

class EscolhaPartidosArgs {
  final List<RespostaQuiz> respostas;

  const EscolhaPartidosArgs({
    required this.respostas,
  });
}

class ResultadoQuizArgs {
  final List<ResultadoQuiz> resultados;

  const ResultadoQuizArgs({
    required this.resultados,
  });
}
