import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

import 'helpers/analytics_test_support.dart';

void main() {
  group('AnalyticsService', () {
    test('logs thesis_viewed without identifying the thesis', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisViewed();

      expect(sink.calls.single.name, 'thesis_viewed');
      expect(sink.calls.single.parameters, isNull);
    });

    test('logs thesis_answered with duration but no opinion or thesis',
        () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisAnswered(timeToAnswerMs: 1470);

      expect(sink.calls, hasLength(1));
      expect(sink.calls.single.name, 'thesis_answered');
      expect(sink.calls.single.parameters, {
        'time_to_answer_ms': 1470,
      });
    });

    test('logs thesis_skipped without identifying the thesis', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.thesisSkipped();

      expect(sink.calls.single.name, 'thesis_skipped');
      expect(sink.calls.single.parameters, isNull);
    });

    test('logs quiz_completed with approved completion counters', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.quizCompleted(
        totalAnswered: 28,
        totalSkipped: 2,
        durationMs: 98000,
      );

      expect(sink.calls.single.name, 'quiz_completed');
      expect(sink.calls.single.parameters, {
        'total_answered': 28,
        'total_skipped': 2,
        'duration_ms': 98000,
      });
    });

    test('logs weight changes without revealing prioritized theses', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.weightAdded();
      await service.weightRemoved();

      expect(sink.calls.first.name, 'weight_added');
      expect(sink.calls.first.parameters, isNull);
      expect(sink.calls.last.name, 'weight_removed');
      expect(sink.calls.last.parameters, isNull);
    });

    test('logs results_viewed without candidate or affinity', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.resultsViewed();

      expect(sink.calls, hasLength(1));
      expect(sink.calls.single.name, 'results_viewed');
      expect(sink.calls.single.parameters, isNull);
    });

    test('logs weighting_completed with weight count', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.weightingCompleted(countWeighted: 4);

      expect(sink.calls.single.name, 'weighting_completed');
      expect(sink.calls.single.parameters, {'count_weighted': 4});
    });

    test('logs party_selection_completed with selected party count', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.partySelectionCompleted(countSelected: 7);

      expect(sink.calls.single.name, 'party_selection_completed');
      expect(sink.calls.single.parameters, {'count_selected': 7});
    });

    test('logs party_toggled without identifying party or selection', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.partyToggled();

      expect(sink.calls.single.name, 'party_toggled');
      expect(sink.calls.single.parameters, isNull);
    });

    test('logs comparison events without candidate or ranking position',
        () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.comparisonOpened();
      await service.comparisonCandidateAdded();

      expect(sink.calls.first.name, 'comparison_opened');
      expect(sink.calls.first.parameters, isNull);
      expect(sink.calls.last.name, 'comparison_candidate_added');
      expect(sink.calls.last.parameters, isNull);
    });

    test('new product events serialize only closed dimensions', () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.screenViewed(
        screen: AnalyticsScreen.communityFeed,
        source: AnalyticsSource.tab,
      );
      await service.operationResult(
        operation: AnalyticsOperation.communityFeedLoad,
        outcome: AnalyticsOutcome.empty,
        trigger: AnalyticsTrigger.initial,
        durationMs: 12,
        itemCount: 0,
      );

      expect(sink.calls[0].parameters, {
        'screen': 'community_feed',
        'source': 'tab',
      });
      expect(sink.calls[1].parameters, {
        'operation': 'community_feed_load',
        'outcome': 'empty',
        'trigger': 'initial',
        'duration_ms': 12,
        'item_count': 0,
      });
    });

    test('engagement and abandonment serialize only aggregate dimensions',
        () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.engagementAction(
        action: AnalyticsAction.outboundOpen,
        surface: AnalyticsSurface.news,
        target: AnalyticsTarget.newsArticle,
        outcome: AnalyticsOutcome.success,
      );
      await service.quizAbandoned(
        stage: AnalyticsQuizStage.weighting,
        reason: AnalyticsAbandonReason.back,
        totalAnswered: 12,
        totalSkipped: 3,
        durationMs: 5000,
      );

      expect(sink.calls[0].parameters, {
        'action': 'outbound_open',
        'surface': 'news',
        'target': 'news_article',
        'outcome': 'success',
      });
      expect(sink.calls[1].parameters, {
        'stage': 'weighting',
        'reason': 'back',
        'total_answered': 12,
        'total_skipped': 3,
        'duration_ms': 5000,
      });
    });

    test('logs the pseudonymous follow validation funnel without parameters',
        () async {
      final sink = RecordingAnalyticsSink();
      final service = AnalyticsService(sink: sink);

      await service.followWaitlistViewed();
      await service.followWaitlistPromptViewed();
      await service.followWaitlistCtaClicked();
      await service.followWaitlistRegistered();
      await service.followWaitlistFailed();

      expect(
        sink.calls.map((event) => event.name),
        [
          'follow_waitlist_viewed',
          'follow_waitlist_prompt_viewed',
          'follow_waitlist_cta_clicked',
          'follow_waitlist_registered',
          'follow_waitlist_failed',
        ],
      );
      expect(
        sink.calls.every((event) => event.parameters == null),
        isTrue,
      );
    });
  });
}
