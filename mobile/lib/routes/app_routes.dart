import 'package:flutter/material.dart';
import '../telas/tela_inicial.dart';
import '../telas/tela_pergunta_quiz.dart';
import '../telas/tela_sobre.dart';
import '../telas/tela_tutorial_quiz.dart';

class AppRoutes {
  static const String inicial = '/';
  static const String sobre = '/sobre';
  static const String tutorial = '/tutorial';
  static const String perguntaQuiz = '/pergunta-quiz';

  static Map<String, WidgetBuilder> routes = {
    inicial: (_) => const TelaInicial(),
    sobre: (_) => const TelaSobre(),
    tutorial: (_) => const TelaTutorialQuiz(),
    perguntaQuiz: (_) => const TelaPerguntaQuiz(),
  };
}
