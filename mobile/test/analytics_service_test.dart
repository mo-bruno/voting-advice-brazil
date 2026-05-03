import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    test('logs thesis_viewed with thesis id and index', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisViewed(thesisId: 12, thesisIndex: 3);

      expect(sink.events.single.name, 'thesis_viewed');
      expect(sink.events.single.parameters, {
        'thesis_id': 12,
        'thesis_index': 3,
      });
    });

    test('logs thesis_answered with thesis, stance, and answer time', () async {
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
        'thesis_id': 12,
        'stance': 'agree',
        'time_to_answer_ms': 1470,
      });
    });

    test('logs thesis_skipped with only thesis id', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisSkipped(thesisId: 12);

      expect(sink.events.single.name, 'thesis_skipped');
      expect(sink.events.single.parameters, {'thesis_id': 12});
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

    test('logs weight changes with thesis id', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.weightAdded(thesisId: 12);
      await service.weightRemoved(thesisId: 13);

      expect(sink.events.first.name, 'weight_added');
      expect(sink.events.first.parameters, {'thesis_id': 12});
      expect(sink.events.last.name, 'weight_removed');
      expect(sink.events.last.parameters, {'thesis_id': 13});
    });

    test('logs results_viewed with top candidate and score', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.resultsViewed(
        topCandidateId: 'candidate-13',
        topScorePercent: 82.5,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'results_viewed');
      expect(sink.events.single.parameters, {
        'top_candidate_id': 'candidate-13',
        'top_score_percent': 82.5,
      });
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

    test('logs party_toggled with acronym and numeric selected flag', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.partyToggled(partyAcronym: 'PT', selected: true);

      expect(sink.events.single.name, 'party_toggled');
      expect(sink.events.single.parameters, {
        'party_acronym': 'PT',
        'selected': 1,
      });
    });

    test('logs comparison events with approved parameter keys', () async {
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
      expect(sink.events.last.parameters, {
        'candidate_id': 'candidate-13',
        'position': 2,
      });
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
