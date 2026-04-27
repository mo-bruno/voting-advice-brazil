class RespostaQuizValor {
  static const concordo = 'agree';
  static const discordo = 'disagree';
  static const neutro = 'neutral';

  const RespostaQuizValor._();

  static String texto(String? answer) {
    switch (answer) {
      case concordo:
        return 'Concordo';
      case discordo:
        return 'Discordo';
      case neutro:
        return 'Resposta neutra';
      case null:
        return 'Sem resposta';
      default:
        return 'Resposta não reconhecida';
    }
  }
}

class RespostaQuiz {
  final int thesisId;
  final String answer;
  final int weight;

  const RespostaQuiz({
    required this.thesisId,
    required this.answer,
    this.weight = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'thesis_id': thesisId,
      'answer': answer,
      'weight': weight,
    };
  }

  String get textoResposta => RespostaQuizValor.texto(answer);
}
