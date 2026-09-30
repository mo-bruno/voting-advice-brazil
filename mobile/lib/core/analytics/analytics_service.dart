import 'analytics_dependencies.dart';
import 'analytics_dimensions.dart';
import 'analytics_sink.dart';

export 'analytics_dimensions.dart';
export 'analytics_sink.dart';

class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink})
      : _sink = sink ?? AnalyticsDependencies.instance.sink;

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

  Future<void> thesisViewed() {
    return _sink.logEvent(name: 'thesis_viewed');
  }

  Future<void> thesisAnswered({
    required int timeToAnswerMs,
  }) {
    return _sink.logEvent(
      name: 'thesis_answered',
      parameters: {
        'time_to_answer_ms': timeToAnswerMs,
      },
    );
  }

  Future<void> thesisSkipped() {
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

  Future<void> weightAdded() {
    return _sink.logEvent(name: 'weight_added');
  }

  Future<void> weightRemoved() {
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

  Future<void> partyToggled() {
    return _sink.logEvent(name: 'party_toggled');
  }

  Future<void> partySelectionCompleted({required int countSelected}) {
    return _sink.logEvent(
      name: 'party_selection_completed',
      parameters: {'count_selected': countSelected},
    );
  }

  Future<void> resultsViewed() {
    return _sink.logEvent(name: 'results_viewed');
  }

  Future<void> comparisonOpened() {
    return _sink.logEvent(name: 'comparison_opened');
  }

  Future<void> comparisonCandidateAdded() {
    return _sink.logEvent(name: 'comparison_candidate_added');
  }

  Future<void> screenViewed({
    required AnalyticsScreen screen,
    required AnalyticsSource source,
  }) {
    return _sink.logEvent(
      name: 'screen_viewed',
      parameters: {
        'screen': screen.value,
        'source': source.value,
      },
    );
  }

  Future<void> engagementAction({
    required AnalyticsAction action,
    AnalyticsSurface? surface,
    AnalyticsSource? source,
    AnalyticsTarget? target,
    AnalyticsOutcome? outcome,
  }) {
    return _sink.logEvent(
      name: 'engagement_action',
      parameters: {
        'action': action.value,
        if (surface != null) 'surface': surface.value,
        if (source != null) 'source': source.value,
        if (target != null) 'target': target.value,
        if (outcome != null) 'outcome': outcome.value,
      },
    );
  }

  Future<void> operationResult({
    required AnalyticsOperation operation,
    required AnalyticsOutcome outcome,
    required AnalyticsTrigger trigger,
    AnalyticsFailureType? failureType,
    int? durationMs,
    int? itemCount,
  }) {
    return _sink.logEvent(
      name: 'operation_result',
      parameters: {
        'operation': operation.value,
        'outcome': outcome.value,
        'trigger': trigger.value,
        if (failureType != null) 'failure_type': failureType.value,
        if (durationMs != null) 'duration_ms': durationMs,
        if (itemCount != null) 'item_count': itemCount,
      },
    );
  }

  Future<void> quizAbandoned({
    required AnalyticsQuizStage stage,
    required AnalyticsAbandonReason reason,
    required int totalAnswered,
    required int totalSkipped,
    required int durationMs,
  }) {
    return _sink.logEvent(
      name: 'quiz_abandoned',
      parameters: {
        'stage': stage.value,
        'reason': reason.value,
        'total_answered': totalAnswered,
        'total_skipped': totalSkipped,
        'duration_ms': durationMs,
      },
    );
  }

  Future<void> followWaitlistViewed() {
    return _sink.logEvent(name: 'follow_waitlist_viewed');
  }

  Future<void> followWaitlistPromptViewed() {
    return _sink.logEvent(name: 'follow_waitlist_prompt_viewed');
  }

  Future<void> followWaitlistCtaClicked() {
    return _sink.logEvent(name: 'follow_waitlist_cta_clicked');
  }

  Future<void> followWaitlistRegistered() {
    return _sink.logEvent(name: 'follow_waitlist_registered');
  }

  Future<void> followWaitlistFailed() {
    return _sink.logEvent(name: 'follow_waitlist_failed');
  }
}
