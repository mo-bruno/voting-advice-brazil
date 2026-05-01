import 'package:flutter/material.dart';

import '../../shared/models/thesis.dart';
import '../../shared/quiz_session.dart';

class QuizController extends ChangeNotifier {
  final QuizSession session;
  int _currentIndex = 0;
  bool isLoading = false;
  String? errorMessage;

  QuizController({QuizSession? session})
      : session = session ?? QuizSession.instance;

  List<Thesis> get theses => session.theses;
  int get currentIndex => _currentIndex;
  int get totalTheses => theses.length;
  Thesis? get currentThesis => theses.isEmpty ? null : theses[_currentIndex];
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == theses.length - 1;

  Future<void> loadQuestions() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await session.loadQuestions();
      if (_currentIndex >= theses.length) {
        _currentIndex = 0;
      }
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  bool answer(ThesisAnswer answer) {
    final thesis = currentThesis;
    if (thesis == null) return false;
    thesis.answer = answer;
    if (isLast) {
      notifyListeners();
      return true;
    }
    _currentIndex++;
    notifyListeners();
    return false;
  }

  bool skip() => answer(ThesisAnswer.skipped);

  void previous() {
    if (!isFirst) {
      _currentIndex--;
      notifyListeners();
    }
  }
}
