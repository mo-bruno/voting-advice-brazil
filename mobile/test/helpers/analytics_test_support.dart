import 'package:guia_eleitoral/core/analytics/analytics_sink.dart';

final class RecordedAnalyticsCall {
  const RecordedAnalyticsCall(this.name, this.parameters);

  final String name;
  final Map<String, Object>? parameters;
}

final class RecordingAnalyticsSink implements AnalyticsSink {
  RecordingAnalyticsSink({this.block});

  final Future<void>? block;
  final List<RecordedAnalyticsCall> calls = [];

  List<String> get names => [
        for (final call in calls) call.name,
      ];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    calls.add(
      RecordedAnalyticsCall(
        name,
        parameters == null ? null : Map<String, Object>.of(parameters),
      ),
    );
    return block ?? Future<void>.value();
  }
}

List<RecordedAnalyticsCall> named(
  List<RecordedAnalyticsCall> calls,
  String name,
) =>
    calls.where((call) => call.name == name).toList();

RecordedAnalyticsCall lastNamed(
  List<RecordedAnalyticsCall> calls,
  String name,
) =>
    named(calls, name).last;

RecordedAnalyticsCall lastOperation(List<RecordedAnalyticsCall> calls) =>
    lastNamed(calls, 'operation_result');

RecordedAnalyticsCall lastEngagement(List<RecordedAnalyticsCall> calls) =>
    lastNamed(calls, 'engagement_action');

List<String> operationOutcomes(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['outcome']! as String,
    ];

List<String> operationTriggers(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['trigger']! as String,
    ];

List<String> operationNames(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['operation']! as String,
    ];

List<String> engagementTargets(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'engagement_action'))
        call.parameters!['target']! as String,
    ];
