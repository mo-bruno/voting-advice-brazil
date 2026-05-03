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

  test('skip emits thesis_answered, thesis_skipped and quiz_completed',
      () async {
    final sink = FakeAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    final session = QuizSession.testOnly();
    session.theses = [Thesis(id: 1, title: 'A', category: 'X')];
    session.markQuizStarted(DateTime(2026, 5, 3, 12, 0, 0));

    final controller = QuizController(
      session: session,
      analytics: analytics,
      now: () => DateTime(2026, 5, 3, 12, 0, 1),
    );
    controller.markCurrentThesisViewed();

    final finished = await controller.skip();

    expect(finished, isTrue);
    expect(
      sink.events,
      containsAll([
        'thesis_viewed',
        'thesis_answered',
        'thesis_skipped',
        'quiz_completed',
      ]),
    );

    final answeredIndex = sink.events.indexOf('thesis_answered');
    expect(sink.parameters[answeredIndex]['stance'], 'skip');

    final completed = sink.parameters[sink.events.indexOf('quiz_completed')];
    expect(completed['total_answered'], 0);
    expect(completed['total_skipped'], 1);
  });

  test('non-last answer advances to next thesis_viewed without quiz_completed',
      () async {
    final sink = FakeAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    final session = QuizSession.testOnly();
    session.theses = [
      Thesis(id: 1, title: 'A', category: 'X'),
      Thesis(id: 2, title: 'B', category: 'X'),
    ];
    session.markQuizStarted(DateTime(2026, 5, 3, 12, 0, 0));

    final controller = QuizController(
      session: session,
      analytics: analytics,
      now: () => DateTime(2026, 5, 3, 12, 0, 1),
    );
    controller.markCurrentThesisViewed();

    final finished = await controller.answer(ThesisAnswer.agree);

    expect(finished, isFalse);
    expect(sink.events.contains('quiz_completed'), isFalse);
    expect(sink.events.last, 'thesis_viewed');
    // First viewed (id=1) + answered + second viewed (id=2)
    expect(
      sink.events.where((e) => e == 'thesis_viewed').length,
      2,
    );
    expect(sink.parameters.last['thesis_id'], 2);
    expect(sink.parameters.last['thesis_index'], 2);
  });

  test('thesis_viewed deduplicates when marked twice for same thesis',
      () async {
    final sink = FakeAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    final session = QuizSession.testOnly();
    session.theses = [Thesis(id: 1, title: 'A', category: 'X')];

    final controller = QuizController(
      session: session,
      analytics: analytics,
      now: () => DateTime(2026, 5, 3, 12, 0, 0),
    );

    controller.markCurrentThesisViewed();
    controller.markCurrentThesisViewed();

    expect(
      sink.events.where((e) => e == 'thesis_viewed').length,
      1,
    );
  });

  test('resetForNewQuiz clears dedup so same thesis re-emits thesis_viewed',
      () async {
    final sink = FakeAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    final session = QuizSession.testOnly();
    session.theses = [Thesis(id: 1, title: 'A', category: 'X')];

    final controller = QuizController(
      session: session,
      analytics: analytics,
      now: () => DateTime(2026, 5, 3, 12, 0, 0),
    );

    controller.markCurrentThesisViewed();
    controller.resetForNewQuiz();
    controller.markCurrentThesisViewed();

    expect(
      sink.events.where((e) => e == 'thesis_viewed').length,
      2,
    );
  });
}
