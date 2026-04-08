import 'package:flutter/material.dart';
import '../../shared/models/thesis.dart';

class QuizController extends ChangeNotifier {
  final List<Thesis> _theses = Thesis.getSampleTheses();
  int _currentIndex = 0;

  List<Thesis> get theses => _theses;
  int get currentIndex => _currentIndex;
  int get totalTheses => _theses.length;
  Thesis get currentThesis => _theses[_currentIndex];
  bool get isFirst => _currentIndex == 0;
  bool get isLast => _currentIndex == _theses.length - 1;

  int get answeredCount =>
      _theses.where((t) => t.answer != ThesisAnswer.unanswered).length;

  void answer(ThesisAnswer answer) {
    _theses[_currentIndex].answer = answer;
    if (!isLast) {
      _currentIndex++;
    }
    notifyListeners();
  }

  void skip() {
    _theses[_currentIndex].answer = ThesisAnswer.skipped;
    if (!isLast) {
      _currentIndex++;
    }
    notifyListeners();
  }

  void goTo(int index) {
    if (index >= 0 && index < _theses.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void previous() {
    if (!isFirst) {
      _currentIndex--;
      notifyListeners();
    }
  }
}
