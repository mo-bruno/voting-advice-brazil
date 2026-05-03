import 'dart:async';

import 'package:flutter/material.dart';

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
  }

  Future<void> loadQuestions({bool force = false}) async {
    isLoading = true;
    errorMessage = null;
    if (force) {
      resetForNewQuiz();
    }
    notifyListeners();
    try {
      await session.loadQuestions(force: force);
      if (_currentIndex >= theses.length) {
        _currentIndex = 0;
      }
      markCurrentThesisViewed();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void markCurrentThesisViewed() {
    final thesis = currentThesis;
    if (thesis == null) return;
    _currentThesisViewedAt = now();
    if (_viewedThesisIds.add(thesis.id)) {
      unawaited(
        analytics.thesisViewed(
          thesisId: thesis.id,
          thesisIndex: _currentIndex + 1,
        ),
      );
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
      await analytics.thesisAnswered(
        thesisId: thesis.id,
        stance: thesis.apiAnswer,
        timeToAnswerMs: timeToAnswerMs < 0 ? 0 : timeToAnswerMs,
      );
      if (answer == ThesisAnswer.skipped) {
        await analytics.thesisSkipped(thesisId: thesis.id);
      }

      if (isLast) {
        await analytics.quizCompleted(
          totalAnswered: session.totalAnswered,
          totalSkipped: session.totalSkipped,
          durationMs: session.quizDurationMs(now: now()),
        );
        notifyListeners();
        return true;
      }

      _currentIndex++;
      markCurrentThesisViewed();
      notifyListeners();
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
      notifyListeners();
    }
  }
}
