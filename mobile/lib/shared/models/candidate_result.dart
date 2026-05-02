import 'party.dart';
import 'thesis.dart';

class ThesisMatch {
  final int thesisId;
  final String thesisText;
  final String themeId;
  final String userAnswer;
  final String candidatePosition;
  final String matchType;

  const ThesisMatch({
    required this.thesisId,
    required this.thesisText,
    required this.themeId,
    required this.userAnswer,
    required this.candidatePosition,
    required this.matchType,
  });

  factory ThesisMatch.fromJson(Map<String, dynamic> json) {
    return ThesisMatch(
      thesisId: json['thesis_id'] as int,
      thesisText: json['thesis_text'] as String,
      themeId: json['theme_id'] as String,
      userAnswer: json['user_answer'] as String,
      candidatePosition: json['candidate_position'] as String,
      matchType: json['match_type'] as String,
    );
  }

  ThesisAnswer get userAnswerEnum => answerFromApi(userAnswer);
  ThesisAnswer get candidateAnswerEnum => answerFromCandidate(candidatePosition);

  static ThesisAnswer answerFromApi(String value) {
    switch (value) {
      case 'agree':
        return ThesisAnswer.agree;
      case 'disagree':
        return ThesisAnswer.disagree;
      case 'neutral':
        return ThesisAnswer.neutral;
      default:
        return ThesisAnswer.skipped;
    }
  }

  static ThesisAnswer answerFromCandidate(String value) {
    switch (value) {
      case 'concordo':
        return ThesisAnswer.agree;
      case 'discordo':
        return ThesisAnswer.disagree;
      case 'neutro':
        return ThesisAnswer.neutral;
      default:
        return ThesisAnswer.skipped;
    }
  }
}

class CandidateResult {
  final String candidateId;
  final String name;
  final String party;
  final double scorePercent;
  final int rank;
  final List<ThesisMatch> matches;

  const CandidateResult({
    required this.candidateId,
    required this.name,
    required this.party,
    required this.scorePercent,
    required this.rank,
    required this.matches,
  });

  factory CandidateResult.fromJson(Map<String, dynamic> json) {
    return CandidateResult(
      candidateId: json['candidate_id'] as String,
      name: json['name'] as String,
      party: json['party'] as String,
      scorePercent: (json['score_percent'] as num).toDouble(),
      rank: json['rank'] as int,
      matches: (json['matches'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ThesisMatch.fromJson)
          .toList(),
    );
  }

  String get abbreviation => Party.partyAbbreviation(party);
  String get logoAsset => Party.logoAssetForParty(party);
  bool get hasLogoAsset => Party.hasLogoAssetForParty(party);
}

class CandidateJustification {
  final int thesisId;
  final String thesisText;
  final String theme;
  final String themeName;
  final String position;
  final String? justification;

  const CandidateJustification({
    required this.thesisId,
    required this.thesisText,
    required this.theme,
    required this.themeName,
    required this.position,
    required this.justification,
  });

  factory CandidateJustification.fromJson(Map<String, dynamic> json) {
    return CandidateJustification(
      thesisId: json['thesis_id'] as int,
      thesisText: json['thesis_text'] as String,
      theme: json['theme'] as String,
      themeName: json['theme_name'] as String,
      position: json['position'] as String,
      justification: json['justification'] as String?,
    );
  }

  ThesisAnswer get positionAnswer => ThesisMatch.answerFromCandidate(position);
}
