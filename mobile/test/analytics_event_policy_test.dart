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
  'candidate_positions_viewed',
  'follow_waitlist_viewed',
  'follow_waitlist_prompt_viewed',
  'follow_waitlist_cta_clicked',
  'follow_waitlist_registered',
  'follow_waitlist_failed',
};

const hostileParameters = <String, Object>{
  'candidate_id': '13',
  'stance': 'agree',
  'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
  'device_id': '550e8400-e29b-41d4-a716-446655440001',
  'free_text': 'conteúdo político',
  'count': 1,
};

const allowedParameterKeys = {
  'thesis_answered': {'time_to_answer_ms'},
  'quiz_completed': {'total_answered', 'total_skipped', 'duration_ms'},
  'weighting_completed': {'count_weighted'},
  'party_selection_completed': {'count_selected'},
};

void main() {
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

  test('unknown event is dropped', () {
    expect(AnalyticsEventPolicy.sanitize(name: 'candidate_selected'), isNull);
  });

  for (final entry in allowedParameterKeys.entries) {
    test('${entry.key} forwards only nonnegative integer schema values', () {
      final allowed = {
        for (final key in entry.value) key: 24,
      };
      final sanitized = AnalyticsEventPolicy.sanitize(
        name: entry.key,
        parameters: {...hostileParameters, ...allowed},
      );
      expect(sanitized?.parameters, allowed);
      expect(
        AnalyticsEventPolicy.sanitize(
          name: entry.key,
          parameters: {
            for (final key in entry.value) key: -1,
            ...hostileParameters,
          },
        )?.parameters,
        isNull,
      );
    });
  }

  test('quiz completion keeps only its numeric totals', () {
    final event = AnalyticsEventPolicy.sanitize(
      name: 'quiz_completed',
      parameters: {
        'total_answered': 24,
        'total_skipped': 6,
        'duration_ms': 83000,
        'candidate_id': '13',
        'affinity': 91.2,
        'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
      },
    );
    expect(event?.parameters, {
      'total_answered': 24,
      'total_skipped': 6,
      'duration_ms': 83000,
    });
  });

  test('answered duration rejects invalid numeric and political values', () {
    for (final value in <Object>[-1, '2', 1.5, double.nan, double.infinity]) {
      expect(
        AnalyticsEventPolicy.sanitize(
          name: 'thesis_answered',
          parameters: {
            'time_to_answer_ms': value,
            'stance': 'agree',
            'thesis_id': 12,
          },
        )?.parameters,
        isNull,
      );
    }
  });

  test('sanitized event is detached from input and immutable', () {
    final input = <String, Object>{'total_answered': 5};
    final event = AnalyticsEventPolicy.sanitize(
      name: 'quiz_completed',
      parameters: input,
    )!;
    input['total_answered'] = 99;
    input['candidate_id'] = '13';
    expect(event.parameters, {'total_answered': 5});
    expect(
        () => event.parameters!['candidate_id'] = '13', throwsUnsupportedError);
    expect(() => event.parameters!.remove('total_answered'),
        throwsUnsupportedError);
  });
}
