import 'package:firebase_analytics/firebase_analytics.dart';

import 'gtag_bridge_stub.dart' if (dart.library.html) 'gtag_bridge_web.dart';

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

class GtagAnalyticsSink implements AnalyticsSink {
  const GtagAnalyticsSink();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    logGtagEvent(name: name, parameters: parameters);
  }
}

class CompositeAnalyticsSink implements AnalyticsSink {
  const CompositeAnalyticsSink(this._sinks);

  final List<AnalyticsSink> _sinks;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    for (final sink in _sinks) {
      await sink.logEvent(name: name, parameters: parameters);
    }
  }
}

class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink})
      : _sink = sink ??
            const CompositeAnalyticsSink([
              FirebaseAnalyticsSink(),
              GtagAnalyticsSink(),
            ]);

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

  Future<void> thesisViewed({
    required int thesisId,
    required int thesisIndex,
  }) {
    return _sink.logEvent(
      name: 'thesis_viewed',
      parameters: {
        'thesis_id': thesisId,
        'thesis_index': thesisIndex,
      },
    );
  }

  Future<void> thesisAnswered({
    required int thesisId,
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

  Future<void> thesisSkipped({required int thesisId}) {
    return _sink.logEvent(
      name: 'thesis_skipped',
      parameters: {'thesis_id': thesisId},
    );
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
    return _sink.logEvent(
      name: 'weight_added',
      parameters: {'thesis_id': thesisId},
    );
  }

  Future<void> weightRemoved({required int thesisId}) {
    return _sink.logEvent(
      name: 'weight_removed',
      parameters: {'thesis_id': thesisId},
    );
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
    return _sink.logEvent(
      name: 'party_toggled',
      parameters: {
        'party_acronym': partyAcronym,
        'selected': selected ? 1 : 0,
      },
    );
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
    return _sink.logEvent(
      name: 'results_viewed',
      parameters: {
        'top_candidate_id': topCandidateId,
        'top_score_percent': topScorePercent,
      },
    );
  }

  Future<void> comparisonOpened() {
    return _sink.logEvent(name: 'comparison_opened');
  }

  Future<void> comparisonCandidateAdded({
    required String candidateId,
    required int position,
  }) {
    return _sink.logEvent(
      name: 'comparison_candidate_added',
      parameters: {
        'candidate_id': candidateId,
        'position': position,
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
