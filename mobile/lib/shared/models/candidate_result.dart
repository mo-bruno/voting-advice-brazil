import 'party.dart';
import 'thesis.dart';

class ThesisMatch {
  final int thesisId;
  final String thesisText;
  final int themeId;
  final String userAnswer;
  final String candidatePosition;
  final String? candidateAnalysis;
  final String matchType;

  const ThesisMatch({
    required this.thesisId,
    required this.thesisText,
    required this.themeId,
    required this.userAnswer,
    required this.candidatePosition,
    this.candidateAnalysis,
    required this.matchType,
  });

  factory ThesisMatch.fromJson(Map<String, dynamic> json) {
    return ThesisMatch(
      thesisId: json['thesis_id'] as int,
      thesisText: json['thesis_text'] as String,
      themeId: json['theme_id'] as int,
      userAnswer: json['user_answer'] as String,
      candidatePosition: json['candidate_position'] as String,
      candidateAnalysis: json['candidate_analysis'] as String?,
      matchType: json['match_type'] as String,
    );
  }

  ThesisAnswer get userAnswerEnum => answerFromApi(userAnswer);
  ThesisAnswer get candidateAnswerEnum =>
      answerFromCandidate(candidatePosition);

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
  final String? photoUrl;
  final double scorePercent;
  final int rank;
  final List<ThesisMatch> matches;
  final int? _countedTheses;
  final int? _answeredTheses;
  final int? _comparableCategories;
  final int? _documentedTheses;
  final int? _documentedCategories;
  final String? _rankingStatus;
  final bool? _rankingEligible;

  const CandidateResult({
    required this.candidateId,
    required this.name,
    required this.party,
    this.photoUrl,
    required this.scorePercent,
    required this.rank,
    required this.matches,
    int? countedTheses,
    int? answeredTheses,
    int? comparableCategories,
    int? documentedTheses,
    int? documentedCategories,
    String? rankingStatus,
    bool? rankingEligible,
  })  : _countedTheses = countedTheses,
        _answeredTheses = answeredTheses,
        _comparableCategories = comparableCategories,
        _documentedTheses = documentedTheses,
        _documentedCategories = documentedCategories,
        _rankingStatus = rankingStatus,
        _rankingEligible = rankingEligible;

  int get answeredTheses =>
      _answeredTheses ??
      matches
          .where(
            (match) => const [
              'agree',
              'disagree',
              'neutral',
            ].contains(match.userAnswer),
          )
          .length;

  int get countedTheses =>
      _countedTheses ??
      matches
          .where(
            (match) =>
                const [
                  'agree',
                  'disagree',
                  'neutral',
                ].contains(match.userAnswer) &&
                const [
                  'concordo',
                  'discordo',
                  'neutro',
                ].contains(match.candidatePosition),
          )
          .length;

  int get comparableCategories =>
      _comparableCategories ??
      matches
          .where(
            (match) =>
                const [
                  'agree',
                  'disagree',
                  'neutral',
                ].contains(match.userAnswer) &&
                const [
                  'concordo',
                  'discordo',
                  'neutro',
                ].contains(match.candidatePosition),
          )
          .map((match) => match.themeId)
          .toSet()
          .length;

  int get documentedTheses => _documentedTheses ?? countedTheses;
  int get documentedCategories => _documentedCategories ?? comparableCategories;
  bool get rankingEligible => _rankingEligible ?? false;
  String get rankingStatus =>
      _rankingStatus ??
      (rankingEligible
          ? 'eligible'
          : countedTheses == 0
              ? 'insufficient_documented_coverage'
              : 'insufficient_answer_coverage');
  bool get hasComparableEvidence => countedTheses > 0;
  String get affinityLabel =>
      rankingEligible ? '$rankº lugar' : 'Fora do ranking desta edição';
  String get coverageLabel =>
      '$countedTheses de $answeredTheses respostas comparáveis · '
      '$comparableCategories '
      '${comparableCategories == 1 ? 'categoria' : 'categorias'}';
  String get rankingExplanation {
    if (rankingStatus == 'insufficient_documented_coverage') {
      return 'O plano oferece posições comparáveis em $documentedTheses teses e '
          '$documentedCategories '
          '${documentedCategories == 1 ? 'categoria' : 'categorias'}. '
          'Esta edição exige pelo menos 5 teses e 4 categorias.';
    }
    if (rankingStatus == 'insufficient_answer_coverage') {
      return 'Nas suas respostas, foi possível comparar $countedTheses teses '
          'em $comparableCategories '
          '${comparableCategories == 1 ? 'categoria' : 'categorias'}. '
          'O ranking exige pelo menos 5 teses e 4 categorias.';
    }
    return 'Base: $coverageLabel.';
  }

  factory CandidateResult.fromJson(Map<String, dynamic> json) {
    return CandidateResult(
      candidateId: (json['candidate_id'] as int).toString(),
      name: json['name'] as String,
      party: json['party_acronym'] as String,
      photoUrl: json['photo_url'] as String?,
      scorePercent: (json['score_percent'] as num).toDouble(),
      rank: json['rank'] as int,
      countedTheses: json['counted_theses'] as int?,
      answeredTheses: json['answered_theses'] as int?,
      comparableCategories: json['comparable_categories'] as int?,
      documentedTheses: json['documented_theses'] as int?,
      documentedCategories: json['documented_categories'] as int?,
      rankingStatus: json['ranking_status'] as String?,
      rankingEligible: json['ranking_eligible'] as bool?,
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
  final String? analyticalPosition;
  final String? justification;
  final String? quote;
  final String? sourceRef;
  final String? sourceUrl;

  const CandidateJustification({
    required this.thesisId,
    required this.thesisText,
    required this.theme,
    required this.themeName,
    required this.position,
    this.analyticalPosition,
    required this.justification,
    this.quote,
    this.sourceRef,
    this.sourceUrl,
  });

  factory CandidateJustification.fromJson(Map<String, dynamic> json) {
    return CandidateJustification(
      thesisId: json['thesis_id'] as int,
      thesisText: json['thesis_text'] as String,
      theme: json['theme'] as String,
      themeName: json['theme_name'] as String,
      position: json['position'] as String,
      analyticalPosition: json['analytical_position'] as String?,
      justification: json['justification'] as String?,
      quote: json['quote'] as String?,
      sourceRef: json['source_ref'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }

  ThesisAnswer get positionAnswer => ThesisMatch.answerFromCandidate(position);
}
