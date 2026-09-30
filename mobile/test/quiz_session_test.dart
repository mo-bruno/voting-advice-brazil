import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

void main() {
  group('QuizSession metrics', () {
    test('affinity ties consider only selected candidates with evidence', () {
      final session = QuizSession.testOnly()
        ..results = const [
          CandidateResult(
            candidateId: '1',
            name: 'Sem evidência',
            party: 'DC',
            scorePercent: 0,
            rank: 0,
            matches: [],
            countedTheses: 0,
            answeredTheses: 5,
          ),
          CandidateResult(
            candidateId: '2',
            name: 'Discordâncias reais',
            party: 'DC',
            scorePercent: 0,
            rank: 1,
            matches: [],
            countedTheses: 5,
            answeredTheses: 5,
          ),
          CandidateResult(
            candidateId: '3',
            name: 'Fora da seleção',
            party: 'DC',
            scorePercent: 100,
            rank: 1,
            matches: [],
            countedTheses: 5,
            answeredTheses: 5,
          ),
        ]
        ..selectedCandidateIds = {'1', '2'};
      expect(session.topAffinityResults.map((result) => result.candidateId), [
        '2',
      ]);
    });

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
      session.candidates = [
        Party.fromCandidateJson({
          'id': 13,
          'name': 'Candidato da edição anterior',
          'party_acronym': 'PT',
        }),
      ];

      session.markQuizStarted(DateTime(2026, 5, 3, 10));

      session.resetQuiz();

      expect(session.quizStartedAt, isNull);
      expect(session.hasStartedFlow, isFalse);
      expect(session.candidates, isEmpty);
    });

    test('submit with IoT disabled never reads or sends the device id',
        () async {
      const deviceId = '550e8400-e29b-41d4-a716-446655440000';
      final api = _FakeApiClient();
      final deviceStore = _FakeDeviceIdentityStore(deviceId);
      final session = QuizSession.testOnly(
        api: api,
        deviceIdentityStore: deviceStore,
        iotEnabled: false,
      )..theses = [
          Thesis(
            id: 1,
            title: 'Thesis 1',
            category: 'Economia',
            answer: ThesisAnswer.agree,
          ),
        ];

      await session.submit();

      expect(deviceStore.reads, 0);
      expect(api.receivedDeviceId, isNull);
      expect(session.results, hasLength(1));
    });

    test('submit with IoT enabled preserves the device contract', () async {
      const deviceId = '550e8400-e29b-41d4-a716-446655440000';
      final api = _FakeApiClient();
      final deviceStore = _FakeDeviceIdentityStore(deviceId);
      final session = QuizSession.testOnly(
        api: api,
        deviceIdentityStore: deviceStore,
        iotEnabled: true,
      )..theses = [
          Thesis(
            id: 1,
            title: 'Thesis 1',
            category: 'Economia',
            answer: ThesisAnswer.agree,
          ),
        ];

      await session.submit();

      expect(deviceStore.reads, 1);
      expect(api.receivedDeviceId, deviceId);
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
  int reads = 0;

  _FakeDeviceIdentityStore(this.deviceId);

  @override
  Future<String> getOrCreateDeviceId() async {
    reads++;
    return deviceId;
  }
}
