import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

void main() {
  group('QuizSession metrics', () {
    test('counts answered, skipped, and weighted theses', () {
      final session = QuizSession.testOnly();

      session.theses = [
        Thesis(
          id: 1,
          title: 'Thesis 1',
          category: 'Economia',
          answer: ThesisAnswer.agree,
          doubleWeight: true,
        ),
        Thesis(
          id: 2,
          title: 'Thesis 2',
          category: 'Saude',
          answer: ThesisAnswer.skipped,
        ),
        Thesis(
          id: 3,
          title: 'Thesis 3',
          category: 'Educacao',
          answer: ThesisAnswer.unanswered,
          doubleWeight: true,
        ),
      ];

      expect(session.totalAnswered, 1);
      expect(session.totalSkipped, 1);
      expect(session.countWeighted, 2);
      expect(session.hasStartedFlow, isTrue);
    });

    test('tracks duration from a fixed start time to a fixed now', () {
      final session = QuizSession.testOnly();
      final startedAt = DateTime(2026, 5, 3, 10);

      expect(session.quizDurationMs(now: startedAt), 0);

      session.markQuizStarted(startedAt);

      expect(
        session.quizDurationMs(now: DateTime(2026, 5, 3, 10, 0, 3, 250)),
        3250,
      );
    });

    test('resetQuiz clears quiz start time and started flow state', () {
      final session = QuizSession.testOnly()
        ..theses = [
          Thesis(
            id: 1,
            title: 'Thesis 1',
            category: 'Economia',
            answer: ThesisAnswer.neutral,
          ),
        ]
        ..results = [
          const CandidateResult(
            candidateId: '13',
            name: 'Candidate',
            party: 'PT',
            scorePercent: 75,
            rank: 1,
            matches: [],
          ),
        ]
        ..selectedCandidateIds = {'13'};

      session.markQuizStarted(DateTime(2026, 5, 3, 10));

      session.resetQuiz();

      expect(session.quizStartedAt, isNull);
      expect(session.hasStartedFlow, isFalse);
    });

    test('submit sends the anonymous device id to the API client', () async {
      const deviceId = '550e8400-e29b-41d4-a716-446655440000';
      final api = _FakeApiClient();
      final deviceStore = _FakeDeviceIdentityStore(deviceId);
      final session = QuizSession.testOnly(
        api: api,
        deviceIdentityStore: deviceStore,
      )..theses = [
          Thesis(
            id: 1,
            title: 'Thesis 1',
            category: 'Economia',
            answer: ThesisAnswer.agree,
          ),
        ];

      await session.submit();

      expect(api.receivedDeviceId, deviceId);
      expect(session.results, hasLength(1));
    });
  });
}

class _FakeApiClient extends ApiClient {
  String? receivedDeviceId;

  @override
  Future<List<CandidateResult>> submitQuiz(
    List<Thesis> theses, {
    String? deviceId,
  }) async {
    receivedDeviceId = deviceId;
    return const [
      CandidateResult(
        candidateId: '13',
        name: 'Candidate',
        party: 'PT',
        scorePercent: 88,
        rank: 1,
        matches: [],
      ),
    ];
  }
}

class _FakeDeviceIdentityStore extends DeviceIdentityStore {
  final String deviceId;

  _FakeDeviceIdentityStore(this.deviceId);

  @override
  Future<String> getOrCreateDeviceId() async => deviceId;
}
