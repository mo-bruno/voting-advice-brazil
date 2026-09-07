import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

class _StubClient extends http.BaseClient {
  late Uri lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final body = jsonEncode({'posts': <dynamic>[], 'has_next': false});
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  test('sem sort explicito nao envia o parametro', () async {
    final stub = _StubClient();
    final api = ApiClient(baseUrl: 'https://api.test/api/v1', client: stub);

    await api.listPosts(anonymousId: 'dev-1');

    expect(stub.lastUri.queryParameters.containsKey('sort'), isFalse);
  });

  test('envia sort=recent quando pedido', () async {
    final stub = _StubClient();
    final api = ApiClient(baseUrl: 'https://api.test/api/v1', client: stub);

    await api.listPosts(anonymousId: 'dev-1', sort: 'recent');

    expect(stub.lastUri.queryParameters['sort'], 'recent');
  });
}
