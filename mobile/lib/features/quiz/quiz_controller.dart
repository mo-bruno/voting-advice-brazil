import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analytics/analytics_failure_classifier.dart';
import '../../core/analytics/analytics_service.dart';
import '../../shared/models/thesis.dart';
import '../../shared/quiz_session.dart';

typedef Clock = DateTime Function();

class QuizController extends ChangeNotifier {
  final QuizSession session;
  final AnalyticsService analytics;
  final Clock now;
  int _currentIndex = 0;
  bool isLoading = false;
  String? errorMessage;
  DateTime? _currentThesisViewedAt;
  final Set<int> _viewedThesisIds = {};
  bool _answering = false;
  bool _completionTracked = false;
  bool _disposed = false;

  QuizController({
    QuizSession? session,
    AnalyticsService? analytics,
    Clock? now,
  })  : session = session ?? QuizSession.instance,
        analytics = analytics ?? AnalyticsService(),
        now = now ?? DateTime.now;

  List<Thesis> get theses => session.theses;
  int get currentIndex => _currentIndex;
  int get totalTheses => theses.length;
  Thesis? get currentThesis => theses.isEmpty ? null : theses[_currentIndex];
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == theses.length - 1;

  /// Clears per-quiz state so a fresh run emits funnel events from scratch.
  ///
  /// The controller is normally created per [QuizPage] push, but this method
  /// makes the invariant explicit when callers reuse a controller instance
  /// or when [loadQuestions] is invoked with `force: true`.
  void resetForNewQuiz() {
    _currentIndex = 0;
    _viewedThesisIds.clear();
    _currentThesisViewedAt = null;
    _completionTracked = false;
  }

  void _track(Future<void> event) {
    unawaited(event.catchError((_) {}));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadQuestions({
    bool force = false,
    AnalyticsTrigger trigger = AnalyticsTrigger.initial,
  }) async {
    final stopwatch = Stopwatch()..start();
    var outcome = AnalyticsOutcome.failed;
    AnalyticsFailureType? failureType;
    int? itemCount;
    isLoading = true;
    errorMessage = null;
    if (force) {
      resetForNewQuiz();
    }
    _notify();
    try {
      await session.loadQuestions(force: force);
      if (_currentIndex >= theses.length) {
        _currentIndex = 0;
      }
      markCurrentThesisViewed();
      itemCount = theses.length;
      outcome =
          theses.isEmpty ? AnalyticsOutcome.empty : AnalyticsOutcome.success;
    } catch (error) {
      errorMessage = error.toString();
      failureType = classifyAnalyticsFailure(error);
    } finally {
      stopwatch.stop();
      isLoading = false;
      _track(analytics.operationResult(
        operation: AnalyticsOperation.quizLoad,
        outcome: outcome,
        trigger: trigger,
        failureType: failureType,
        durationMs: stopwatch.elapsedMilliseconds,
        itemCount: itemCount,
      ));
      _notify();
    }
  }

  void markCurrentThesisViewed() {
    final thesis = currentThesis;
    if (thesis == null) return;
    _currentThesisViewedAt = now();
    if (_viewedThesisIds.add(thesis.id)) {
      _track(analytics.thesisViewed());
    }
  }

  Future<bool> answer(ThesisAnswer answer) async {
    if (_answering) return false;
    _answering = true;
    try {
      final thesis = currentThesis;
      if (thesis == null) return false;
      thesis.answer = answer;

      final viewedAt = _currentThesisViewedAt ?? now();
      final timeToAnswerMs = now().difference(viewedAt).inMilliseconds;
      final finished = isLast;
      if (!finished) _currentIndex++;

      if (answer == ThesisAnswer.skipped) {
        _track(analytics.thesisSkipped());
      } else {
        _track(analytics.thesisAnswered(
          timeToAnswerMs: timeToAnswerMs < 0 ? 0 : timeToAnswerMs,
        ));
      }

      if (finished) {
        if (!_completionTracked) {
          _completionTracked = true;
          _track(analytics.quizCompleted(
            totalAnswered: session.totalAnswered,
            totalSkipped: session.totalSkipped,
            durationMs: session.quizDurationMs(now: now()),
          ));
        }
        _notify();
        return true;
      }

      markCurrentThesisViewed();
      _notify();
      return false;
    } finally {
      _answering = false;
    }
  }

  Future<bool> skip() => answer(ThesisAnswer.skipped);

  void previous() {
    if (!isFirst) {
      _currentIndex--;
      markCurrentThesisViewed();
      _notify();
    }
  }
}
