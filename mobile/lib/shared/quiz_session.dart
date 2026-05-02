import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import 'models/candidate_result.dart';
import 'models/party.dart';
import 'models/thesis.dart';

class QuizSession extends ChangeNotifier {
  QuizSession._();

  static final QuizSession instance = QuizSession._();

  final ApiClient api = ApiClient();
  List<Thesis> theses = [];
  List<Party> candidates = [];
  List<CandidateResult> results = [];
  Set<String> selectedCandidateIds = {};

  void resetQuiz() {
    theses = [];
    results = [];
    selectedCandidateIds = {};
    notifyListeners();
  }

  Future<void> loadQuestions({bool force = false}) async {
    if (theses.isNotEmpty && !force) return;
    theses = await api.fetchQuizQuestions();
    notifyListeners();
  }

  Future<void> loadCandidates({bool force = false}) async {
    if (candidates.isNotEmpty && !force) return;
    candidates = await api.fetchCandidates();
    notifyListeners();
  }

  Future<void> submit() async {
    results = await api.submitQuiz(theses);
    notifyListeners();
  }

  List<CandidateResult> get visibleResults {
    if (selectedCandidateIds.isEmpty) return results;
    return results
        .where((result) => selectedCandidateIds.contains(result.candidateId))
        .toList();
  }
}
