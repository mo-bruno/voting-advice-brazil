import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/quiz/quiz_controller.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

import 'helpers/analytics_test_support.dart';

class _QuizApi extends ApiClient {
  _QuizApi({this.questions = const [], this.error});

  final List<Thesis> questions;
  final Object? error;

  @override
  Future<List<Thesis>> fetchQuizQuestions({int limit = 60}) async {
    if (error case final value?) throw value;
    return questions;
  }
}

class _DelayedQuizApi extends ApiClient {
  final Completer<List<Thesis>> response = Completer();

  @override
  Future<List<Thesis>> fetchQuizQuestions({int limit = 60}) => response.future;
}

void main() {
  test('logs thesis answer timing and quiz completion', () async {
    final sink = RecordingAnalyticsSink();
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
      sink.names,
      containsAll(['thesis_viewed', 'thesis_answered', 'quiz_completed']),
    );
    expect(sink.calls[1].parameters!['time_to_answer_ms'], 0);
    expect(sink.calls.last.parameters!['total_answered'], 1);
    expect(sink.calls.last.parameters!['total_skipped'], 0);
    expect(sink.calls.last.parameters!['duration_ms'], 2000);
  });

  test('skip is exclusive and analytics never blocks progress', () async {
    final blocker = Completer<void>();
    final sink = RecordingAnalyticsSink(block: blocker.future);
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

    final finished =
        await controller.skip().timeout(const Duration(milliseconds: 100));

    expect(finished, isTrue);
    expect(
      sink.names,
      containsAll([
        'thesis_viewed',
        'thesis_skipped',
        'quiz_completed',
      ]),
    );
    expect(sink.names, isNot(contains('thesis_answered')));
    final completed = lastNamed(sink.calls, 'quiz_completed').parameters!;
    expect(completed['total_answered'], 0);
    expect(completed['total_skipped'], 1);
    blocker.complete();
  });

  test(
      're-answering the last thesis still finishes without duplicate completion',
      () async {
    final sink = RecordingAnalyticsSink();
    final session = QuizSession.testOnly()
      ..theses = [Thesis(id: 1, title: 'A', category: 'X')];
    final controller = QuizController(
      session: session,
      analytics: AnalyticsService(sink: sink),
    );

    expect(await controller.answer(ThesisAnswer.agree), isTrue);
    expect(await controller.answer(ThesisAnswer.disagree), isTrue);

    expect(
      sink.names.where((name) => name == 'quiz_completed'),
      hasLength(1),
    );
  });

  test('non-last answer advances to next thesis_viewed without quiz_completed',
      () async {
    final sink = RecordingAnalyticsSink();
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
    expect(sink.names.contains('quiz_completed'), isFalse);
    expect(sink.names.last, 'thesis_viewed');
    // First viewed (id=1) + answered + second viewed (id=2)
    expect(
      sink.names.where((e) => e == 'thesis_viewed').length,
      2,
    );
    expect(sink.calls.last.parameters, isNull);
  });

  test('thesis_viewed deduplicates when marked twice for same thesis',
      () async {
    final sink = RecordingAnalyticsSink();
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
      sink.names.where((e) => e == 'thesis_viewed').length,
      1,
    );
  });

  test('resetForNewQuiz clears dedup so same thesis re-emits thesis_viewed',
      () async {
    final sink = RecordingAnalyticsSink();
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
      sink.names.where((e) => e == 'thesis_viewed').length,
      2,
    );
  });

  test('quiz load reports one terminal result with trigger and duration',
      () async {
    final sink = RecordingAnalyticsSink();
    final controller = QuizController(
      session: QuizSession.testOnly(api: _QuizApi()),
      analytics: AnalyticsService(sink: sink),
    );

    await controller.loadQuestions(trigger: AnalyticsTrigger.retry);

    expect(named(sink.calls, 'operation_result'), hasLength(1));
    expect(
      lastOperation(sink.calls).parameters,
      allOf(
        containsPair('operation', 'quiz_load'),
        containsPair('outcome', 'empty'),
        containsPair('trigger', 'retry'),
        containsPair('item_count', 0),
        containsPair('duration_ms', isA<int>()),
      ),
    );
  });

  test('quiz load success reports only the generic item count', () async {
    final sink = RecordingAnalyticsSink();
    final controller = QuizController(
      session: QuizSession.testOnly(
        api: _QuizApi(
          questions: [Thesis(id: 42, title: 'Conteúdo', category: 'Tema')],
        ),
      ),
      analytics: AnalyticsService(sink: sink),
    );

    await controller.loadQuestions();

    expect(
      lastOperation(sink.calls).parameters,
      allOf(
        containsPair('operation', 'quiz_load'),
        containsPair('outcome', 'success'),
        containsPair('item_count', 1),
      ),
    );
    expect(
      lastOperation(sink.calls).parameters!.values,
      everyElement(isNot(anyOf(42, 'Conteúdo', 'Tema'))),
    );
  });

  test('quiz load failure is generic and terminal', () async {
    final sink = RecordingAnalyticsSink();
    final controller = QuizController(
      session: QuizSession.testOnly(
        api: _QuizApi(error: const ApiException('secret', statusCode: 503)),
      ),
      analytics: AnalyticsService(sink: sink),
    );

    await controller.loadQuestions();

    expect(
      lastOperation(sink.calls).parameters,
      allOf(
        containsPair('operation', 'quiz_load'),
        containsPair('outcome', 'failed'),
        containsPair('trigger', 'initial'),
        containsPair('failure_type', 'unavailable'),
      ),
    );
    expect(
      lastOperation(sink.calls).parameters!.values,
      isNot(contains('secret')),
    );
  });

  test('disposed controller still reports the pending load terminal', () async {
    final sink = RecordingAnalyticsSink();
    final api = _DelayedQuizApi();
    final controller = QuizController(
      session: QuizSession.testOnly(api: api),
      analytics: AnalyticsService(sink: sink),
    );

    final loading = controller.loadQuestions();
    controller.dispose();
    api.response.complete(const []);
    await loading;

    expect(named(sink.calls, 'operation_result'), hasLength(1));
    expect(lastOperation(sink.calls).parameters?['outcome'], 'empty');
  });
}
