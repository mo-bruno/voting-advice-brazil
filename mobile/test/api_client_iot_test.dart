import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

void main() {
  test('pairIotDevice sends anonymous header and pairing body', () async {
    final client = _CapturingClient({
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'status': 'linked',
      'linked_at': '2026-05-22T20:00:00Z',
      'updated_at': '2026-05-22T20:00:00Z',
      'last_seen_at': null,
    });
    final api =
        ApiClient(baseUrl: 'https://example.test/api/v1', client: client);

    final device = await api.pairIotDevice(
      anonymousId: 'anon-1',
      deviceToken: '550e8400-e29b-41d4-a716-446655440000',
      pairingCode: '482913',
    );

    expect(device.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(client.lastMethod, 'PUT');
    expect(
        client.lastUri.toString(), 'https://example.test/api/v1/me/iot-device');
    expect(client.lastHeaders['X-Farol-Anonymous-Id'], 'anon-1');
    expect(client.lastBody, {
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'pairing_code': '482913',
    });
  });

  test('pairIotDevice sends manual prefix body without device token', () async {
    final client = _CapturingClient({
      'device_token': '2d90ae25-e29b-41d4-a716-446655440000',
      'status': 'linked',
      'linked_at': '2026-05-22T20:00:00Z',
      'updated_at': '2026-05-22T20:00:00Z',
      'last_seen_at': null,
    });
    final api =
        ApiClient(baseUrl: 'https://example.test/api/v1', client: client);

    final device = await api.pairIotDevice(
      anonymousId: 'anon-1',
      deviceTokenPrefix: '2d90ae25',
      pairingCode: '482913',
    );

    expect(device.deviceToken, '2d90ae25-e29b-41d4-a716-446655440000');
    expect(client.lastMethod, 'PUT');
    expect(client.lastBody, {
      'device_token_prefix': '2d90ae25',
      'pairing_code': '482913',
    });
    expect(client.lastBody!.containsKey('device_token'), isFalse);
  });

  test('fetchIotDevice returns null on 404', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: _StatusClient(404),
    );

    final device = await api.fetchIotDevice(anonymousId: 'anon-1');

    expect(device, isNull);
  });

  test('deleteIotDevice succeeds on 204 with empty body', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: _StatusClient(204),
    );

    await expectLater(
      api.deleteIotDevice(anonymousId: 'anon-1'),
      completes,
    );
  });
}

class _CapturingClient extends http.BaseClient {
  final Map<String, dynamic> response;
  late Uri lastUri;
  late String lastMethod;
  late Map<String, String> lastHeaders;
  Map<String, dynamic>? lastBody;

  _CapturingClient(this.response);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    lastMethod = request.method;
    lastHeaders = request.headers;
    if (request is http.Request && request.body.isNotEmpty) {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    final responseBytes = utf8.encode(jsonEncode(response));
    return http.StreamedResponse(
      Stream<List<int>>.value(responseBytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _StatusClient extends http.BaseClient {
  final int statusCode;

  _StatusClient(this.statusCode);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      statusCode,
    );
  }
}
