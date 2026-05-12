import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:http/http.dart' as http;

void main() {
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
        client.lastUri.toString(), 'https://example.test/api/v1/quiz/submit');
    expect(client.lastBody, {
      'device_id': deviceId,
      'answers': [
        {'thesis_id': 1, 'answer': 'agree', 'weight': 2},
      ],
    });
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
}

class _CapturingClient extends http.BaseClient {
  late Uri lastUri;
  late Map<String, dynamic> lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final body = await request.finalize().bytesToString();
    lastBody = jsonDecode(body) as Map<String, dynamic>;
    final responseBytes = utf8.encode(jsonEncode({'results': <dynamic>[]}));
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
