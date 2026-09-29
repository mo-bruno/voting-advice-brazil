import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    test('logs thesis_viewed without identifying the thesis', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisViewed(thesisId: 12, thesisIndex: 3);

      expect(sink.events.single.name, 'thesis_viewed');
      expect(sink.events.single.parameters, isNull);
    });

    test('logs thesis_answered with duration but no opinion or thesis',
        () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisAnswered(
        thesisId: 12,
        stance: 'agree',
        timeToAnswerMs: 1470,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'thesis_answered');
      expect(sink.events.single.parameters, {
        'time_to_answer_ms': 1470,
      });
    });

    test('logs thesis_skipped without identifying the thesis', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisSkipped(thesisId: 12);

      expect(sink.events.single.name, 'thesis_skipped');
      expect(sink.events.single.parameters, isNull);
    });

    test('logs quiz_completed with approved completion counters', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.quizCompleted(
        totalAnswered: 28,
        totalSkipped: 2,
        durationMs: 98000,
      );

      expect(sink.events.single.name, 'quiz_completed');
      expect(sink.events.single.parameters, {
        'total_answered': 28,
        'total_skipped': 2,
        'duration_ms': 98000,
      });
    });

    test('logs weight changes without revealing prioritized theses', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.weightAdded(thesisId: 12);
      await service.weightRemoved(thesisId: 13);

      expect(sink.events.first.name, 'weight_added');
      expect(sink.events.first.parameters, isNull);
      expect(sink.events.last.name, 'weight_removed');
      expect(sink.events.last.parameters, isNull);
    });

    test('logs results_viewed without candidate or affinity', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.resultsViewed(
        topCandidateId: 'candidate-13',
        topScorePercent: 82.5,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'results_viewed');
      expect(sink.events.single.parameters, isNull);
    });

    test('logs weighting_completed with weight count', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.weightingCompleted(countWeighted: 4);

      expect(sink.events.single.name, 'weighting_completed');
      expect(sink.events.single.parameters, {'count_weighted': 4});
    });

    test('logs party_selection_completed with selected party count', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.partySelectionCompleted(countSelected: 7);

      expect(sink.events.single.name, 'party_selection_completed');
      expect(sink.events.single.parameters, {'count_selected': 7});
    });

    test('logs party_toggled without identifying party or selection', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.partyToggled(partyAcronym: 'PT', selected: true);

      expect(sink.events.single.name, 'party_toggled');
      expect(sink.events.single.parameters, isNull);
    });

    test('logs comparison events without candidate or ranking position',
        () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.comparisonOpened();
      await service.comparisonCandidateAdded(
        candidateId: 'candidate-13',
        position: 2,
      );

      expect(sink.events.first.name, 'comparison_opened');
      expect(sink.events.first.parameters, isNull);
      expect(sink.events.last.name, 'comparison_candidate_added');
      expect(sink.events.last.parameters, isNull);
    });

    test('logs candidate positions view without candidate identity', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.candidatePositionsViewed(candidateId: 'candidate-13');

      expect(sink.events.single.name, 'candidate_positions_viewed');
      expect(sink.events.single.parameters, isNull);
    });

    test('logs the anonymous follow validation funnel without parameters',
        () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.followWaitlistViewed();
      await service.followWaitlistPromptViewed();
      await service.followWaitlistCtaClicked();
      await service.followWaitlistRegistered();
      await service.followWaitlistFailed();

      expect(
        sink.events.map((event) => event.name),
        [
          'follow_waitlist_viewed',
          'follow_waitlist_prompt_viewed',
          'follow_waitlist_cta_clicked',
          'follow_waitlist_registered',
          'follow_waitlist_failed',
        ],
      );
      expect(
        sink.events.every((event) => event.parameters == null),
        isTrue,
      );
    });
  });
}

class FakeAnalyticsSink implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(AnalyticsEvent(name, parameters));
  }
}

class AnalyticsEvent {
  const AnalyticsEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object>? parameters;
}
