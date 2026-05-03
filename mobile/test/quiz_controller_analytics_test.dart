import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/features/quiz/quiz_controller.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

class FakeAnalyticsSink implements AnalyticsSink {
  final events = <String>[];
  final parameters = <Map<String, Object>>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(name);
    this.parameters.add(parameters ?? const {});
  }
}

void main() {
  test('logs thesis answer timing and quiz completion', () async {
    final sink = FakeAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    final session = QuizSession.testOnly();
    session.theses = [Thesis(id: 1, title: 'A', category: 'X')];
    session.markQuizStarted(DateTime(2026, 5, 3, 12, 0, 0));

    final controller = QuizController(
      session: session,
      analytics: analytics,
      now: () => DateTime(2026, 5, 3, 12, 0, 2),
    );
    controller.markCurrentThesisViewed();

    final finished = await controller.answer(ThesisAnswer.agree);

    expect(finished, isTrue);
    expect(
      sink.events,
      containsAll(['thesis_viewed', 'thesis_answered', 'quiz_completed']),
    );
    expect(sink.parameters[1]['time_to_answer_ms'], 0);
    expect(sink.parameters.last['total_answered'], 1);
    expect(sink.parameters.last['total_skipped'], 0);
    expect(sink.parameters.last['duration_ms'], 2000);
  });
}
