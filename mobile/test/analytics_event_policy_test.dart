import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_event_policy.dart';

const noParameterEvents = {
  'quiz_intro_viewed',
  'quiz_started',
  'quiz_restarted',
  'thesis_viewed',
  'thesis_skipped',
  'weighting_started',
  'weight_added',
  'weight_removed',
  'party_selection_viewed',
  'party_toggled',
  'results_viewed',
  'comparison_opened',
  'comparison_candidate_added',
  'follow_waitlist_viewed',
  'follow_waitlist_prompt_viewed',
  'follow_waitlist_cta_clicked',
  'follow_waitlist_registered',
  'follow_waitlist_failed',
};

const hostileParameters = <String, Object>{
  'thesis_id': 12,
  'candidate_id': '13',
  'party_acronym': 'ABC',
  'stance': 'agree',
  'score': 91.2,
  'rank': 1,
  'url': 'https://example.test/?email=a@example.test',
  'route': '/candidate/13',
  'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
  'device_id': '550e8400-e29b-41d4-a716-446655440001',
  'free_text': 'conteúdo político',
};

const validParameterizedEvents = <String, Map<String, Object>>{
  'thesis_answered': {'time_to_answer_ms': 1},
  'quiz_completed': {
    'total_answered': 1,
    'total_skipped': 0,
    'duration_ms': 1,
  },
  'weighting_completed': {'count_weighted': 1},
  'party_selection_completed': {'count_selected': 1},
  'screen_viewed': {'screen': 'home', 'source': 'initial'},
  'engagement_action': {
    'action': 'outbound_open',
    'surface': 'news',
    'target': 'news_article',
    'outcome': 'success',
  },
  'operation_result': {
    'operation': 'news_load',
    'outcome': 'success',
    'trigger': 'initial',
  },
  'quiz_abandoned': {
    'stage': 'questions',
    'reason': 'back',
    'total_answered': 1,
    'total_skipped': 0,
    'duration_ms': 1,
  },
};

void main() {
  test('accepts exactly the 26 approved event names', () {
    final accepted = <String>{
      for (final name in noParameterEvents)
        if (AnalyticsEventPolicy.sanitize(name: name) != null) name,
      for (final entry in validParameterizedEvents.entries)
        if (AnalyticsEventPolicy.sanitize(
              name: entry.key,
              parameters: entry.value,
            ) !=
            null)
          entry.key,
    };

    expect(accepted, hasLength(26));
    expect(
      AnalyticsEventPolicy.sanitize(name: 'candidate_positions_viewed'),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(name: 'candidate_selected'),
      isNull,
    );
  });

  for (final name in noParameterEvents) {
    test('$name retains no parameters', () {
      expect(AnalyticsEventPolicy.sanitize(name: name)?.parameters, isNull);
      expect(
        AnalyticsEventPolicy.sanitize(
          name: name,
          parameters: hostileParameters,
        )?.parameters,
        isNull,
      );
    });
  }

  test('required missing or invalid enum drops the whole event', () {
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'screen_viewed',
        parameters: {'source': 'tab'},
      ),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'screen_viewed',
        parameters: {'screen': 'candidate_13', 'source': 'tab'},
      ),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'quiz_abandoned',
        parameters: {
          'stage': 'results',
          'reason': 'back',
          'total_answered': 2,
          'total_skipped': 0,
          'duration_ms': 1,
        },
      ),
      isNull,
    );
  });

  test('hostile identifiers and free text never cross the policy', () {
    final event = AnalyticsEventPolicy.sanitize(
      name: 'engagement_action',
      parameters: {
        'action': 'outbound_open',
        'surface': 'news',
        'target': 'news_article',
        'outcome': 'success',
        ...hostileParameters,
      },
    );

    expect(event!.parameters, {
      'action': 'outbound_open',
      'surface': 'news',
      'target': 'news_article',
      'outcome': 'success',
    });
  });

  test('engagement action enforces action-specific fields', () {
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {
          'action': 'quiz_entry',
          'surface': 'home',
          'source': 'home_cta',
          'target': 'candidate_13',
          'outcome': 'success',
        },
      )?.parameters,
      {
        'action': 'quiz_entry',
        'surface': 'home',
        'source': 'home_cta',
      },
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {'action': 'quiz_entry', 'surface': 'home'},
      ),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {
          'action': 'evidence_open',
          'surface': 'quiz',
          'source': 'route',
          'outcome': 'failed',
        },
      )?.parameters,
      {'action': 'evidence_open', 'surface': 'quiz'},
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {
          'action': 'outbound_open',
          'surface': 'news',
          'target': 'news_article',
          'outcome': 'empty',
        },
      ),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {
          'action': 'share',
          'surface': 'results',
          'target': 'instagram_help',
        },
      )?.parameters,
      {
        'action': 'share',
        'surface': 'results',
        'target': 'instagram_help',
      },
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'engagement_action',
        parameters: {
          'action': 'share',
          'surface': 'results',
          'target': 'download',
        },
      ),
      isNull,
    );
  });

  test('operation failures require a generic failure type', () {
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'operation_result',
        parameters: {
          'operation': 'news_load',
          'outcome': 'failed',
          'trigger': 'initial',
        },
      ),
      isNull,
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'operation_result',
        parameters: {
          'operation': 'news_load',
          'outcome': 'failed',
          'trigger': 'initial',
          'failure_type': 'network',
        },
      )?.parameters,
      {
        'operation': 'news_load',
        'outcome': 'failed',
        'trigger': 'initial',
        'failure_type': 'network',
      },
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'operation_result',
        parameters: {
          'operation': 'news_load',
          'outcome': 'success',
          'trigger': 'initial',
          'failure_type': 'network',
        },
      )?.parameters,
      {
        'operation': 'news_load',
        'outcome': 'success',
        'trigger': 'initial',
      },
    );
  });

  test('numeric fields accept exact upper boundaries', () {
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'quiz_completed',
        parameters: {
          'total_answered': 60,
          'total_skipped': 60,
          'duration_ms': 86400000,
        },
      )?.parameters,
      {
        'total_answered': 60,
        'total_skipped': 60,
        'duration_ms': 86400000,
      },
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'party_selection_completed',
        parameters: {'count_selected': 50},
      )?.parameters,
      {'count_selected': 50},
    );
    expect(
      AnalyticsEventPolicy.sanitize(
        name: 'operation_result',
        parameters: {
          'operation': 'community_feed_load',
          'outcome': 'success',
          'trigger': 'pagination',
          'duration_ms': 0,
          'item_count': 1000,
        },
      )?.parameters,
      {
        'operation': 'community_feed_load',
        'outcome': 'success',
        'trigger': 'pagination',
        'duration_ms': 0,
        'item_count': 1000,
      },
    );
  });

  test('numeric fields reject negative, overflow and noninteger values', () {
    for (final value in <Object>[-1, 86400001, '2', 1.5]) {
      expect(
        AnalyticsEventPolicy.sanitize(
          name: 'thesis_answered',
          parameters: {'time_to_answer_ms': value},
        ),
        isNull,
      );
    }
    for (final value in <Object>[-1, 61]) {
      expect(
        AnalyticsEventPolicy.sanitize(
          name: 'weighting_completed',
          parameters: {'count_weighted': value},
        ),
        isNull,
      );
    }
    for (final value in <Object>[-1, 51]) {
      expect(
        AnalyticsEventPolicy.sanitize(
          name: 'party_selection_completed',
          parameters: {'count_selected': value},
        ),
        isNull,
      );
    }
    for (final value in <Object>[-1, 1001]) {
      expect(
        AnalyticsEventPolicy.sanitize(
          name: 'operation_result',
          parameters: {
            'operation': 'news_load',
            'outcome': 'success',
            'trigger': 'initial',
            'item_count': value,
          },
        )?.parameters,
        isNot(contains('item_count')),
      );
    }
  });

  test('sanitized event is detached from input and immutable', () {
    final input = <String, Object>{
      'total_answered': 5,
      'total_skipped': 0,
      'duration_ms': 20,
    };
    final event = AnalyticsEventPolicy.sanitize(
      name: 'quiz_completed',
      parameters: input,
    )!;
    input['total_answered'] = 99;
    input['candidate_id'] = '13';
    expect(event.parameters, {
      'total_answered': 5,
      'total_skipped': 0,
      'duration_ms': 20,
    });
    expect(
      () => event.parameters!['candidate_id'] = '13',
      throwsUnsupportedError,
    );
    expect(
      () => event.parameters!.remove('total_answered'),
      throwsUnsupportedError,
    );
  });
}
