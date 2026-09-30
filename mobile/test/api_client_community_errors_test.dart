import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient client(String body, int status) => ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: MockClient((_) async => http.Response(body, status)),
      );

  test('denuncia preserva status e motivo devolvidos pela API', () async {
    final api = client(jsonEncode({'detail': 'Serviço indisponível.'}), 503);
    await expectLater(
      api.reportPost('p1', reason: 'spam', anonymousId: 'private-id'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 503)
          .having((e) => e.message, 'motivo', 'Serviço indisponível.')),
    );
  });

  test('remocao preserva status e motivo devolvidos pela API', () async {
    final api = client(jsonEncode({'detail': 'Post não encontrado.'}), 404);
    await expectLater(
      api.deletePost('p1', anonymousId: 'private-id'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 404)
          .having((e) => e.message, 'motivo', 'Post não encontrado.')),
    );
  });

  test('erro do proxy sem JSON continua sendo um erro HTTP tipado', () async {
    final api = client('<html>Service Unavailable</html>', 503);
    await expectLater(
      api.createPost(anonymousId: 'private-id', content: 'Política brasileira'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
  });

  test('validacao estruturada retorna orientacao de revisao dos dados',
      () async {
    final api = client(
        jsonEncode({
          'detail': [
            {
              'type': 'string_too_long',
              'loc': ['body', 'content'],
              'msg': 'String should have at most 300 characters'
            },
          ]
        }),
        422);
    await expectLater(
      api.createComment('p1', 'x' * 301, anonymousId: 'private-id'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 422)
          .having((e) => e.message, 'orientacao', contains('Revise'))),
    );
  });
  test('envio parado termina com erro tipado e permite recuperar rascunho',
      () async {
    final pending = Completer<http.Response>();
    final api = ApiClient(
        baseUrl: 'https://api.test/api/v1',
        communityWriteTimeout: const Duration(milliseconds: 10),
        client: MockClient((_) => pending.future));
    await expectLater(
        api.createComment('p1', 'Meu rascunho', anonymousId: 'private-id'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 408)));
  });

  test('limite de envios preserva Retry-After para orientacao de espera',
      () async {
    final api = ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: MockClient((_) async => http.Response(
            jsonEncode({'detail': 'Limite atingido.'}), 429,
            headers: {'retry-after': '120'})));
    await expectLater(
        api.createComment('p1', 'Concordo.', anonymousId: 'private-id'),
        throwsA(isA<ApiException>()
            .having((e) => e.retryAfterSeconds, 'espera', 120)));
  });

  test('apagar comentario envia identidade privada e aceita resposta vazia',
      () async {
    http.Request? request;
    final api = ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: MockClient((r) async {
          request = r;
          return http.Response('', 204);
        }));
    await api.deleteComment('p1', 'c1', anonymousId: 'private-id');
    expect(request!.method, 'DELETE');
    expect(request!.url.path, '/api/v1/community/posts/p1/comments/c1');
    expect(request!.headers['x-farol-anonymous-id'], 'private-id');
  });
}
