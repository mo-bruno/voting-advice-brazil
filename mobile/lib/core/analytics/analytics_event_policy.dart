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

abstract final class AnalyticsEventPolicy {
  static const _parameterKeys = <String, Set<String>>{
    'quiz_intro_viewed': {},
    'quiz_started': {},
    'quiz_restarted': {},
    'thesis_viewed': {},
    'thesis_answered': {'time_to_answer_ms'},
    'thesis_skipped': {},
    'quiz_completed': {'total_answered', 'total_skipped', 'duration_ms'},
    'weighting_started': {},
    'weight_added': {},
    'weight_removed': {},
    'weighting_completed': {'count_weighted'},
    'party_selection_viewed': {},
    'party_toggled': {},
    'party_selection_completed': {'count_selected'},
    'results_viewed': {},
    'comparison_opened': {},
    'comparison_candidate_added': {},
    'candidate_positions_viewed': {},
    'follow_waitlist_viewed': {},
    'follow_waitlist_prompt_viewed': {},
    'follow_waitlist_cta_clicked': {},
    'follow_waitlist_registered': {},
    'follow_waitlist_failed': {},
  };

  static SanitizedAnalyticsEvent? sanitize({
    required String name,
    Map<String, Object>? parameters,
  }) {
    final keys = _parameterKeys[name];
    if (keys == null) return null;
    final safe = <String, Object>{};
    if (parameters != null) {
      for (final key in keys) {
        final value = parameters[key];
        if (value is int && value >= 0) safe[key] = value;
      }
    }
    return SanitizedAnalyticsEvent(name: name, parameters: safe);
  }
}
