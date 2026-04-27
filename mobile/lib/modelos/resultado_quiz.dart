class ResultadoQuiz {
  final String candidateId;
  final String name;
  final String party;
  final String? partyLogo;
  final String? fotoUrl;
  final double scorePercent;
  final int rank;
  final List<ResultadoMatch> matches;

  const ResultadoQuiz({
    required this.candidateId,
    required this.name,
    required this.party,
    this.partyLogo,
    this.fotoUrl,
    required this.scorePercent,
    required this.rank,
    this.matches = const [],
  });

  factory ResultadoQuiz.fromJson(Map<String, dynamic> json) {
    final matches = (json['matches'] as List? ?? [])
        .map((item) => ResultadoMatch.fromJson(item))
        .toList();

    return ResultadoQuiz(
      candidateId: json['candidate_id'].toString(),
      name: json['name'] ?? '',
      party: json['party'] ?? '',
      partyLogo: json['party_logo'],
      fotoUrl: json['photo_url'] ?? json['foto_url'],
      scorePercent: (json['score_percent'] as num).toDouble(),
      rank: json['rank'],
      matches: matches,
    );
  }

  ResultadoQuiz copyWith({
    int? rank,
  }) {
    return ResultadoQuiz(
      candidateId: candidateId,
      name: name,
      party: party,
      partyLogo: partyLogo,
      fotoUrl: fotoUrl,
      scorePercent: scorePercent,
      rank: rank ?? this.rank,
      matches: matches,
    );
  }
}

class ResultadoMatch {
  final int thesisId;
  final String thesisText;
  final String themeId;
  final String userAnswer;
  final String candidatePosition;
  final String matchType;

  const ResultadoMatch({
    required this.thesisId,
    required this.thesisText,
    required this.themeId,
    required this.userAnswer,
    required this.candidatePosition,
    required this.matchType,
  });

  factory ResultadoMatch.fromJson(Map<String, dynamic> json) {
    return ResultadoMatch(
      thesisId: json['thesis_id'],
      thesisText: json['thesis_text'] ?? '',
      themeId: json['theme_id'] ?? '',
      userAnswer: json['user_answer'] ?? '',
      candidatePosition: json['candidate_position'] ?? '',
      matchType: json['match_type'] ?? '',
    );
  }

  String get textoPosicao {
    switch (candidatePosition) {
      case 'concordo':
        return 'Concorda';
      case 'discordo':
        return 'Discorda';
      case 'neutro':
        return 'Neutro';
      case 'sem_posicao':
        return 'Sem posição';
      default:
        return candidatePosition;
    }
  }

  String get textoCompatibilidade {
    switch (matchType) {
      case 'match':
        return 'Combina com você';
      case 'partial':
        return 'Parcial';
      case 'mismatch':
        return 'Diverge de você';
      case 'skipped':
        return 'Sem comparação';
      default:
        return matchType;
    }
  }
}
