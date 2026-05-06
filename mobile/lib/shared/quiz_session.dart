import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/device/device_identity_store.dart';
import 'models/candidate_result.dart';
import 'models/party.dart';
import 'models/thesis.dart';

class QuizSession extends ChangeNotifier {
  QuizSession._({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  })  : api = api ?? ApiClient(),
        deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  @visibleForTesting
  factory QuizSession.testOnly({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  }) =>
      QuizSession._(
        api: api,
        deviceIdentityStore: deviceIdentityStore,
      );

  static final QuizSession instance = QuizSession._();

  final ApiClient api;
  final DeviceIdentityStore deviceIdentityStore;
  List<Thesis> theses = [];
  List<Party> candidates = [];
  List<CandidateResult> results = [];
  Set<String> selectedCandidateIds = {};
  DateTime? quizStartedAt;

  bool get hasStartedFlow =>
      theses.isNotEmpty ||
      results.isNotEmpty ||
      selectedCandidateIds.isNotEmpty;

  int get totalAnswered => theses
      .where(
        (thesis) =>
            thesis.answer != ThesisAnswer.unanswered &&
            thesis.answer != ThesisAnswer.skipped,
      )
      .length;

  int get totalSkipped =>
      theses.where((thesis) => thesis.answer == ThesisAnswer.skipped).length;

  int get countWeighted => theses.where((thesis) => thesis.doubleWeight).length;

  void markQuizStarted([DateTime? now]) {
    quizStartedAt = now ?? DateTime.now();
    notifyListeners();
  }

  int quizDurationMs({DateTime? now}) {
    final startedAt = quizStartedAt;
    if (startedAt == null) return 0;
    return (now ?? DateTime.now()).difference(startedAt).inMilliseconds;
  }

  void resetQuiz() {
    theses = [];
    results = [];
    selectedCandidateIds = {};
    quizStartedAt = null;
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
    final deviceId = await deviceIdentityStore.getOrCreateDeviceId();
    results = await api.submitQuiz(theses, deviceId: deviceId);
    notifyListeners();
  }

  List<CandidateResult> get visibleResults {
    if (selectedCandidateIds.isEmpty) return results;
    return results
        .where((result) => selectedCandidateIds.contains(result.candidateId))
        .toList();
  }
}
