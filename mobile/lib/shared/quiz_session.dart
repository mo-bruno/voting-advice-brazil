import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/device/device_identity_store.dart';
import '../core/features/feature_flags.dart';
import 'models/candidate_result.dart';
import 'models/party.dart';
import 'models/thesis.dart';

class QuizSession extends ChangeNotifier {
  QuizSession._({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
    bool? iotEnabled,
  })  : iotEnabled = iotEnabled ?? FeatureFlags.environment.iotEnabled,
        api = api ?? ApiClient(),
        deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  @visibleForTesting
  factory QuizSession.testOnly({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
    bool? iotEnabled,
  }) =>
      QuizSession._(
        api: api,
        deviceIdentityStore: deviceIdentityStore,
        iotEnabled: iotEnabled,
      );

  static final QuizSession instance = QuizSession._();
  static const minimumAnswers = 5;

  final ApiClient api;
  final DeviceIdentityStore deviceIdentityStore;
  final bool iotEnabled;
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

  bool get canSubmit => totalAnswered >= minimumAnswers;

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
    candidates = [];
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
    final deviceId =
        iotEnabled ? await deviceIdentityStore.getOrCreateDeviceId() : null;
    results = await api.submitQuiz(
      theses,
      deviceId: deviceId,
      candidateIds: selectedCandidateIds,
    );
    notifyListeners();
  }

  List<CandidateResult> get visibleResults {
    if (selectedCandidateIds.isEmpty) return results;
    return results
        .where((result) => selectedCandidateIds.contains(result.candidateId))
        .toList();
  }

  List<CandidateResult> get topAffinityResults {
    final ranked =
        visibleResults.where((result) => result.rankingEligible).toList();
    if (ranked.isEmpty) return [];
    final bestRank = ranked.fold<int>(
      ranked.first.rank,
      (best, result) => result.rank < best ? result.rank : best,
    );
    return ranked.where((result) => result.rank == bestRank).toList();
  }
}
