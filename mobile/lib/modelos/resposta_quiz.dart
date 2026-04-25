class RespostaQuizValor {
  static const concordo = 'agree';
  static const discordo = 'disagree';
  static const neutro = 'neutral';

  const RespostaQuizValor._();
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

  String get textoResposta {
    switch (answer) {
      case RespostaQuizValor.concordo:
        return 'Concordo';
      case RespostaQuizValor.discordo:
        return 'Discordo';
      case RespostaQuizValor.neutro:
        return 'Resposta neutra';
      default:
        return 'Resposta não reconhecida';
    }
  }
}
