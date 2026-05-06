import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/models/candidate_result.dart';
import '../../shared/models/official_evidence.dart';
import '../../shared/models/party.dart';
import '../../shared/models/political_actor.dart';
import '../../shared/models/thesis.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://farol-politico-api-ia6m2uvoba-uk.a.run.app/api/v1',
  );

  final String baseUrl;
  final http.Client _client;

  ApiClient({this.baseUrl = defaultBaseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<List<Thesis>> fetchQuizQuestions({int limit = 30}) async {
    final uri = Uri.parse('$baseUrl/quiz/questions?limit=$limit');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return (json['theses'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Thesis.fromJson)
        .toList();
  }

  Future<List<Party>> fetchCandidates() async {
    final uri = Uri.parse('$baseUrl/candidates?page_size=50');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return (json['candidates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Party.fromCandidateJson)
        .toList();
  }

  Future<List<CandidateResult>> submitQuiz(List<Thesis> theses) async {
    final answers = theses
        .where((thesis) => thesis.wasAnswered)
        .map((thesis) => thesis.toSubmitJson())
        .toList();
    final uri = Uri.parse('$baseUrl/quiz/submit');
    final json =
        await _postJson(uri, {'answers': answers}) as Map<String, dynamic>;
    return (json['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CandidateResult.fromJson)
        .toList();
  }

  Future<List<CandidateJustification>> fetchCandidateJustifications(
    String candidateId,
  ) async {
    final uri = Uri.parse('$baseUrl/candidates/$candidateId/justifications');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return (json['justifications'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(CandidateJustification.fromJson)
        .toList();
  }

  Future<PoliticalActorListResponse> fetchPoliticalActors({
    String? search,
    String? state,
    String? party,
    int page = 1,
    int pageSize = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/political-actors').replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (party != null && party.trim().isNotEmpty) 'party': party.trim(),
        'page': '$page',
        'page_size': '$pageSize',
      },
    );
    final json = await _getJson(uri) as Map<String, dynamic>;
    return PoliticalActorListResponse.fromJson(json);
  }

  Future<List<TrendingPoliticalActor>> fetchTrendingPoliticalActors() async {
    final uri = Uri.parse('$baseUrl/political-actors/trending');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return (json['actors'] as List<dynamic>)
        .map((item) => TrendingPoliticalActor.fromJson(
              item as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<PoliticalActor> fetchPoliticalActor(int actorId) async {
    final uri = Uri.parse('$baseUrl/political-actors/$actorId');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return PoliticalActor.fromJson(json);
  }

  Future<EvidenceResponse> fetchOfficialEvidence(int actorId) async {
    final uri = Uri.parse('$baseUrl/political-actors/$actorId/evidence');
    final json = await _getJson(uri) as Map<String, dynamic>;
    return EvidenceResponse.fromJson(json);
  }

  Future<PoliticalActor> followPoliticalActor({
    required int actorId,
    required String anonymousId,
  }) async {
    final uri = Uri.parse('$baseUrl/me/followed-actor');
    final json = await _putJson(
      uri,
      {'political_actor_id': actorId},
      headers: {'X-Farol-Anonymous-Id': anonymousId},
    ) as Map<String, dynamic>;
    return PoliticalActor.fromJson(
      json['political_actor'] as Map<String, dynamic>,
    );
  }

  Future<dynamic> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    return _decode(response);
  }

  Future<dynamic> _postJson(Uri uri, Map<String, dynamic> body) async {
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> _putJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final response = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic> && detail['message'] is String) {
        throw ApiException(detail['message'] as String);
      }
      if (detail is String) {
        throw ApiException(detail);
      }
    }
    throw ApiException('Erro ${response.statusCode} ao conectar com a API.');
  }
}
