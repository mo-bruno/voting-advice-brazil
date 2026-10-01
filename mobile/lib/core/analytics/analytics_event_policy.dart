import 'analytics_dimensions.dart';

class SanitizedAnalyticsEvent {
  SanitizedAnalyticsEvent({
    required this.name,
    Map<String, Object>? parameters,
  }) : parameters = parameters == null || parameters.isEmpty
            ? null
            : Map.unmodifiable(Map<String, Object>.of(parameters));

  final String name;
  final Map<String, Object>? parameters;
}

sealed class _ParameterRule {
  const _ParameterRule();

  Object? sanitize(Object? value);
}

final class _EnumRule extends _ParameterRule {
  _EnumRule(Iterable<String> values) : values = Set.unmodifiable(values);

  final Set<String> values;

  @override
  Object? sanitize(Object? value) =>
      value is String && values.contains(value) ? value : null;
}

final class _IntRule extends _ParameterRule {
  const _IntRule(this.max);

  final int max;

  @override
  Object? sanitize(Object? value) =>
      value is int && value >= 0 && value <= max ? value : null;
}

final class _EventSchema {
  const _EventSchema({
    this.required = const {},
    this.optional = const {},
  });

  final Map<String, _ParameterRule> required;
  final Map<String, _ParameterRule> optional;
}

abstract final class AnalyticsEventPolicy {
  static const _duration = _IntRule(86400000);
  static const _quizCount = _IntRule(60);
  static const _selectionCount = _IntRule(50);
  static const _itemCount = _IntRule(1000);

  static final _screen =
      _EnumRule(AnalyticsScreen.values.map((value) => value.value));
  static final _source =
      _EnumRule(AnalyticsSource.values.map((value) => value.value));
  static final _action =
      _EnumRule(AnalyticsAction.values.map((value) => value.value));
  static final _surface =
      _EnumRule(AnalyticsSurface.values.map((value) => value.value));
  static final _target =
      _EnumRule(AnalyticsTarget.values.map((value) => value.value));
  static final _operation =
      _EnumRule(AnalyticsOperation.values.map((value) => value.value));
  static final _outcome =
      _EnumRule(AnalyticsOutcome.values.map((value) => value.value));
  static final _trigger =
      _EnumRule(AnalyticsTrigger.values.map((value) => value.value));
  static final _failureType =
      _EnumRule(AnalyticsFailureType.values.map((value) => value.value));
  static final _quizStage =
      _EnumRule(AnalyticsQuizStage.values.map((value) => value.value));
  static final _abandonReason =
      _EnumRule(AnalyticsAbandonReason.values.map((value) => value.value));

  static const _noParameters = _EventSchema();

  static final _schemas = <String, _EventSchema>{
    for (final name in const {
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
    })
      name: _noParameters,
    'thesis_answered': const _EventSchema(
      required: {'time_to_answer_ms': _duration},
    ),
    'quiz_completed': const _EventSchema(
      required: {
        'total_answered': _quizCount,
        'total_skipped': _quizCount,
        'duration_ms': _duration,
      },
    ),
    'weighting_completed': const _EventSchema(
      required: {'count_weighted': _quizCount},
    ),
    'party_selection_completed': const _EventSchema(
      required: {'count_selected': _selectionCount},
    ),
    'screen_viewed': _EventSchema(
      required: {
        'screen': _screen,
        'source': _source,
      },
    ),
    'engagement_action': _EventSchema(
      required: {'action': _action},
      optional: {
        'surface': _surface,
        'source': _source,
        'target': _target,
        'outcome': _outcome,
      },
    ),
    'operation_result': _EventSchema(
      required: {
        'operation': _operation,
        'outcome': _outcome,
        'trigger': _trigger,
      },
      optional: {
        'failure_type': _failureType,
        'duration_ms': _duration,
        'item_count': _itemCount,
      },
    ),
    'quiz_abandoned': _EventSchema(
      required: {
        'stage': _quizStage,
        'reason': _abandonReason,
        'total_answered': _quizCount,
        'total_skipped': _quizCount,
        'duration_ms': _duration,
      },
    ),
  };

  static SanitizedAnalyticsEvent? sanitize({
    required String name,
    Map<String, Object>? parameters,
  }) {
    final schema = _schemas[name];
    if (schema == null) return null;

    final safe = <String, Object>{};
    for (final entry in schema.required.entries) {
      final value = entry.value.sanitize(parameters?[entry.key]);
      if (value == null) return null;
      safe[entry.key] = value;
    }
    for (final entry in schema.optional.entries) {
      final value = entry.value.sanitize(parameters?[entry.key]);
      if (value != null) safe[entry.key] = value;
    }

    if (name == 'engagement_action' && !_sanitizeEngagement(safe)) {
      return null;
    }
    if (name == 'operation_result' && !_sanitizeOperation(safe)) {
      return null;
    }
    return SanitizedAnalyticsEvent(name: name, parameters: safe);
  }

  static bool _sanitizeEngagement(Map<String, Object> safe) {
    final action = safe['action'];
    switch (action) {
      case 'quiz_entry':
        if (safe['surface'] == null || safe['source'] == null) return false;
        safe.remove('target');
        safe.remove('outcome');
        break;
      case 'evidence_open':
        if (safe['surface'] == null) return false;
        safe.remove('source');
        safe.remove('target');
        safe.remove('outcome');
        break;
      case 'outbound_open':
        if (safe['surface'] == null ||
            safe['target'] == null ||
            !_isObservableOutcome(safe['outcome'])) {
          return false;
        }
        safe.remove('source');
        break;
      case 'share':
        if (safe['surface'] != 'results' || safe['target'] == null) {
          return false;
        }
        safe.remove('source');
        if (safe['target'] == 'instagram_help') {
          safe.remove('outcome');
        } else if (!_isObservableOutcome(safe['outcome'])) {
          return false;
        }
        break;
      default:
        return false;
    }
    return true;
  }

  static bool _sanitizeOperation(Map<String, Object> safe) {
    final outcome = safe['outcome'];
    if (outcome == 'failed' || outcome == 'blocked') {
      return safe['failure_type'] != null;
    }
    safe.remove('failure_type');
    return true;
  }

  static bool _isObservableOutcome(Object? value) =>
      value == 'success' || value == 'failed';
}
