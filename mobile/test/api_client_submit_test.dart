import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:http/http.dart' as http;

void main() {
  test('fetchQuizQuestions requests the full presidential catalogue', () async {
    final client = _CapturingClient(
      responseBody: const <String, dynamic>{
        'theses': <dynamic>[],
        'total': 0,
      },
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );

    await api.fetchQuizQuestions();

    expect(
      client.lastUri.toString(),
      'https://example.test/api/v1/quiz/questions?limit=60',
    );
  });

  test(
    'submitQuiz preserves the error code needed to restart an outdated quiz',
    () async {
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        client: _CapturingClient(
          statusCode: 422,
          responseBody: {
            'detail': {
              'code': 'invalid_thesis_ids',
              'message': 'Teses indisponíveis.',
            },
          },
        ),
      );
      await expectLater(
        api.submitQuiz(const <Thesis>[]),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having(
                (error) => error.code,
                'code',
                'invalid_thesis_ids',
              ),
        ),
      );
    },
  );

  test('submitQuiz includes device_id when provided', () async {
    const deviceId = '550e8400-e29b-41d4-a716-446655440000';
    final client = _CapturingClient();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );
    final thesis = Thesis(
      id: 1,
      title: 'Tese 1',
      category: 'Economia',
      answer: ThesisAnswer.agree,
      doubleWeight: true,
    );

    final results = await api.submitQuiz([thesis], deviceId: deviceId);

    expect(results, isEmpty);
    expect(
      client.lastUri.toString(),
      'https://example.test/api/v1/quiz/submit',
    );
    expect(client.lastBody, {
      'device_id': deviceId,
      'answers': [
        {'thesis_id': 1, 'answer': 'agree', 'weight': 2},
      ],
    });
  });

  test('submitQuiz sends the selected candidate ids', () async {
    final client = _CapturingClient();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );

    await api.submitQuiz(
      const <Thesis>[],
      candidateIds: const {'7', '13'},
    );

    expect(client.lastBody['candidate_ids'], [7, 13]);
  });

  test('submitQuiz omits device_id when not provided', () async {
    final client = _CapturingClient();
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );
    final thesis = Thesis(
      id: 1,
      title: 'Tese 1',
      category: 'Economia',
      answer: ThesisAnswer.neutral,
    );

    await api.submitQuiz([thesis]);

    expect(client.lastBody.containsKey('device_id'), isFalse);
    expect(client.lastBody['answers'], [
      {'thesis_id': 1, 'answer': 'neutral', 'weight': 1},
    ]);
  });

  test(
    'submitQuiz resolves a relative official photo against the API origin',
    () async {
      final client = _CapturingClient(
        responseBody: {
          'results': [
            {
              'candidate_id': 13,
              'name': 'Candidata Teste',
              'party_acronym': 'PT',
              'party_logo_url': '/data/logos/partidos/PT.png',
              'photo_url': '/data/fotos/2026/BR/123.jpg',
              'score_percent': 80,
              'score_by_theme': <String, dynamic>{},
              'rank': 1,
              'matches': <dynamic>[],
            },
          ],
        },
      );
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        client: client,
      );

      final results = await api.submitQuiz(const <Thesis>[]);

      expect(
        results.single.photoUrl,
        'https://example.test/data/fotos/2026/BR/123.jpg',
      );
    },
  );

  test('fetchCandidates resolves a relative official photo', () async {
    final client = _CapturingClient(
      responseBody: {
        'candidates': [
          {
            'id': 13,
            'name': 'Candidata Teste',
            'party_acronym': 'MISSÃO',
            'spectrum': null,
            'photo_url': '/data/fotos/2026/BR/123.jpg',
          },
        ],
      },
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );

    final candidates = await api.fetchCandidates();

    expect(candidates.single.abbreviation, 'MISSAO');
    expect(
      candidates.single.photoUrl,
      'https://example.test/data/fotos/2026/BR/123.jpg',
    );
  });
}

class _CapturingClient extends http.BaseClient {
  final Object responseBody;
  final int statusCode;

  _CapturingClient({
    this.responseBody = const <String, dynamic>{'results': <dynamic>[]},
    this.statusCode = 200,
  });

  late Uri lastUri;
  late Map<String, dynamic> lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final body = await request.finalize().bytesToString();
    lastBody = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    final responseBytes = utf8.encode(jsonEncode(responseBody));
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBytes),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}
