import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

void main() {
  test('registers anonymous interest and reports whether it was new', () async {
    final client = _InterestClient(
      statusCode: 200,
      response: {'registered': true, 'newly_registered': true},
    );
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: client,
    );

    final newlyRegistered = await api.registerPoliticianFollowInterest(
      anonymousId: 'anon-1',
    );

    expect(newlyRegistered, isTrue);
    expect(client.lastMethod, 'PUT');
    expect(
      client.lastUri.toString(),
      'https://example.test/api/v1/me/politician-follow-interest',
    );
    expect(client.lastHeaders['X-Farol-Anonymous-Id'], 'anon-1');
    expect(client.lastBody, isEmpty);
  });

  test('reads and removes anonymous interest with the private header',
      () async {
    final getClient = _InterestClient(
      statusCode: 200,
      response: {'registered': true},
    );
    final getApi = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: getClient,
    );

    final registered = await getApi.fetchPoliticianFollowInterest(
      anonymousId: 'anon-1',
    );

    expect(registered, isTrue);
    expect(getClient.lastMethod, 'GET');
    expect(getClient.lastHeaders['X-Farol-Anonymous-Id'], 'anon-1');

    final deleteClient = _InterestClient(statusCode: 204);
    final deleteApi = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: deleteClient,
    );

    await deleteApi.deletePoliticianFollowInterest(anonymousId: 'anon-1');

    expect(deleteClient.lastMethod, 'DELETE');
    expect(deleteClient.lastHeaders['X-Farol-Anonymous-Id'], 'anon-1');
  });
}

class _InterestClient extends http.BaseClient {
  _InterestClient({required this.statusCode, this.response});

  final int statusCode;
  final Map<String, dynamic>? response;
  late Uri lastUri;
  late String lastMethod;
  late Map<String, String> lastHeaders;
  late String lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    lastMethod = request.method;
    lastHeaders = request.headers;
    lastBody = request is http.Request ? request.body : '';
    final bytes =
        response == null ? <int>[] : utf8.encode(jsonEncode(response));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}
