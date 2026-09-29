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
  }) async {
    await _instance.logEvent(name: name, parameters: parameters);
  }
}

class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink})
      : _sink = sink ?? const FirebaseAnalyticsSink();

  final AnalyticsSink _sink;

  // Keep public call signatures compatible, but never forward political
  // answers, priorities, parties, candidates, or affinity to analytics.
  // Generic usage events do not imply complete anonymization.

  Future<void> quizIntroViewed() {
    return _sink.logEvent(name: 'quiz_intro_viewed');
  }

  Future<void> quizStarted() {
    return _sink.logEvent(name: 'quiz_started');
  }

  Future<void> quizRestarted() {
    return _sink.logEvent(name: 'quiz_restarted');
  }

  Future<void> thesisViewed({
    required int thesisId,
    required int thesisIndex,
  }) {
    return _sink.logEvent(name: 'thesis_viewed');
  }

  Future<void> thesisAnswered({
    required int thesisId,
    required String stance,
    required int timeToAnswerMs,
  }) {
    return _sink.logEvent(
      name: 'thesis_answered',
      parameters: {
        'time_to_answer_ms': timeToAnswerMs,
      },
    );
  }

  Future<void> thesisSkipped({required int thesisId}) {
    return _sink.logEvent(name: 'thesis_skipped');
  }

  Future<void> quizCompleted({
    required int totalAnswered,
    required int totalSkipped,
    required int durationMs,
  }) {
    return _sink.logEvent(
      name: 'quiz_completed',
      parameters: {
        'total_answered': totalAnswered,
        'total_skipped': totalSkipped,
        'duration_ms': durationMs,
      },
    );
  }

  Future<void> weightingStarted() {
    return _sink.logEvent(name: 'weighting_started');
  }

  Future<void> weightAdded({required int thesisId}) {
    return _sink.logEvent(name: 'weight_added');
  }

  Future<void> weightRemoved({required int thesisId}) {
    return _sink.logEvent(name: 'weight_removed');
  }

  Future<void> weightingCompleted({required int countWeighted}) {
    return _sink.logEvent(
      name: 'weighting_completed',
      parameters: {'count_weighted': countWeighted},
    );
  }

  Future<void> partySelectionViewed() {
    return _sink.logEvent(name: 'party_selection_viewed');
  }

  Future<void> partyToggled({
    required String partyAcronym,
    required bool selected,
  }) {
    return _sink.logEvent(name: 'party_toggled');
  }

  Future<void> partySelectionCompleted({required int countSelected}) {
    return _sink.logEvent(
      name: 'party_selection_completed',
      parameters: {'count_selected': countSelected},
    );
  }

  Future<void> resultsViewed({
    required String topCandidateId,
    required double topScorePercent,
  }) {
    return _sink.logEvent(name: 'results_viewed');
  }

  Future<void> comparisonOpened() {
    return _sink.logEvent(name: 'comparison_opened');
  }

  Future<void> comparisonCandidateAdded({
    required String candidateId,
    required int position,
  }) {
    return _sink.logEvent(name: 'comparison_candidate_added');
  }

  Future<void> candidatePositionsViewed({required String candidateId}) {
    return _sink.logEvent(name: 'candidate_positions_viewed');
  }
}
