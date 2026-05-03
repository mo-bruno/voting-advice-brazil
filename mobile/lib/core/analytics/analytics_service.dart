import 'package:firebase_analytics/firebase_analytics.dart';

abstract class AnalyticsSink {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });
}

class FirebaseAnalyticsSink implements AnalyticsSink {
  const FirebaseAnalyticsSink({FirebaseAnalytics? analytics})
      : _analytics = analytics;

  final FirebaseAnalytics? _analytics;

  FirebaseAnalytics get _instance => _analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return _instance.logEvent(name: name, parameters: parameters);
  }
}

class AnalyticsService {
  const AnalyticsService(this._sink);

  final AnalyticsSink _sink;

  Future<void> quizIntroViewed() {
    return _sink.logEvent(name: 'quiz_intro_viewed');
  }

  Future<void> quizStarted() {
    return _sink.logEvent(name: 'quiz_started');
  }

  Future<void> quizRestarted() {
    return _sink.logEvent(name: 'quiz_restarted');
  }

  Future<void> thesisViewed({required String thesisId}) {
    return _sink.logEvent(
      name: 'thesis_viewed',
      parameters: {'thesis_id': thesisId},
    );
  }

  Future<void> thesisAnswered({
    required String thesisId,
    required String stance,
    required int timeToAnswerMs,
  }) {
    return _sink.logEvent(
      name: 'thesis_answered',
      parameters: {
        'thesis_id': thesisId,
        'stance': stance,
        'time_to_answer_ms': timeToAnswerMs,
      },
    );
  }

  Future<void> thesisSkipped({
    required String thesisId,
    required int timeToAnswerMs,
  }) {
    return _sink.logEvent(
      name: 'thesis_skipped',
      parameters: {
        'thesis_id': thesisId,
        'time_to_answer_ms': timeToAnswerMs,
      },
    );
  }

  Future<void> quizCompleted({
    required int answeredCount,
    required int skippedCount,
    required int timeToCompleteMs,
  }) {
    return _sink.logEvent(
      name: 'quiz_completed',
      parameters: {
        'answered_count': answeredCount,
        'skipped_count': skippedCount,
        'time_to_complete_ms': timeToCompleteMs,
      },
    );
  }

  Future<void> weightingStarted() {
    return _sink.logEvent(name: 'weighting_started');
  }

  Future<void> weightAdded({required String themeId}) {
    return _sink.logEvent(
      name: 'weight_added',
      parameters: {'theme_id': themeId},
    );
  }

  Future<void> weightRemoved({required String themeId}) {
    return _sink.logEvent(
      name: 'weight_removed',
      parameters: {'theme_id': themeId},
    );
  }

  Future<void> weightingCompleted({required int weightCount}) {
    return _sink.logEvent(
      name: 'weighting_completed',
      parameters: {'weight_count': weightCount},
    );
  }

  Future<void> partySelectionViewed() {
    return _sink.logEvent(name: 'party_selection_viewed');
  }

  Future<void> partyToggled({
    required String partyAcronym,
    required bool selected,
  }) {
    return _sink.logEvent(
      name: 'party_toggled',
      parameters: {
        'party_acronym': partyAcronym,
        'selected': selected ? 1 : 0,
      },
    );
  }

  Future<void> partySelectionCompleted({required int selectedPartyCount}) {
    return _sink.logEvent(
      name: 'party_selection_completed',
      parameters: {'selected_party_count': selectedPartyCount},
    );
  }

  Future<void> resultsViewed({
    required String topCandidateId,
    required double topScorePercent,
  }) {
    return _sink.logEvent(
      name: 'results_viewed',
      parameters: {
        'top_candidate_id': topCandidateId,
        'top_score_percent': topScorePercent,
      },
    );
  }

  Future<void> comparisonOpened({required String candidateId}) {
    return _sink.logEvent(
      name: 'comparison_opened',
      parameters: {'candidate_id': candidateId},
    );
  }

  Future<void> comparisonCandidateAdded({
    required String candidateId,
    required int candidateCount,
  }) {
    return _sink.logEvent(
      name: 'comparison_candidate_added',
      parameters: {
        'candidate_id': candidateId,
        'candidate_count': candidateCount,
      },
    );
  }

  Future<void> candidatePositionsViewed({required String candidateId}) {
    return _sink.logEvent(
      name: 'candidate_positions_viewed',
      parameters: {'candidate_id': candidateId},
    );
  }
}
