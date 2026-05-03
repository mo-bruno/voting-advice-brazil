import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    test('logs thesis_answered with thesis, stance, and answer time', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink);

      await service.thesisAnswered(
        thesisId: 'thesis-12',
        stance: 'agree',
        timeToAnswerMs: 1470,
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'thesis_answered');
      expect(sink.events.single.parameters, {
        'thesis_id': 'thesis-12',
        'stance': 'agree',
        'time_to_answer_ms': 1470,
      });
    });

    test('logs results_viewed with top candidate and score', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink);

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
      final service = AnalyticsService(sink);

      await service.weightingCompleted(weightCount: 4);

      expect(sink.events.single.name, 'weighting_completed');
      expect(sink.events.single.parameters, {'weight_count': 4});
    });

    test('logs party_selection_completed with selected party count', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink);

      await service.partySelectionCompleted(selectedPartyCount: 7);

      expect(sink.events.single.name, 'party_selection_completed');
      expect(sink.events.single.parameters, {'selected_party_count': 7});
    });

    test('logs party_toggled with acronym and numeric selected flag', () async {
      final sink = FakeAnalyticsSink();
      final service = AnalyticsService(sink);

      await service.partyToggled(partyAcronym: 'PT', selected: true);

      expect(sink.events.single.name, 'party_toggled');
      expect(sink.events.single.parameters, {
        'party_acronym': 'PT',
        'selected': 1,
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
