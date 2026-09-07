import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:http/http.dart' as http;

const _payload = {
  'period_start': '2026-08-30',
  'period_end': '2026-09-06',
  'period_label': '30 DE AGO A 6 DE SET DE 2026',
  'total': 1,
  'articles': [
    {
      'id': 'abc123',
      'title': 'Titulo',
      'summary': 'Resumo',
      'image_url': null,
      'theme_slug': 'eleicoes',
      'theme_label': 'ELEIÇÕES',
      'published_at': '2026-09-04T12:49:00Z',
      'reading_minutes': 2,
      'url': 'https://example.org/1',
    }
  ],
};

/// Segue o padrão dos outros testes de API deste diretório: um
/// `http.BaseClient` de mentira, sem depender de pacote extra.
class _StubClient extends http.BaseClient {
  _StubClient(this.body, {this.status = 200});

  final Object body;
  final int status;
  late Uri lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  test('busca as noticias da semana', () async {
    final stub = _StubClient(_payload);
    final api = ApiClient(baseUrl: 'https://api.test/api/v1', client: stub);

    final result = await api.fetchWeeklyNews();

    expect(stub.lastUri.path, '/api/v1/news/weekly');
    expect(result.periodLabel, '30 DE AGO A 6 DE SET DE 2026');
    expect(result.articles, hasLength(1));
    expect(result.articles.first.title, 'Titulo');
  });

  test('lista vazia nao e erro', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient({..._payload, 'total': 0, 'articles': <dynamic>[]}),
    );

    final result = await api.fetchWeeklyNews();

    expect(result.articles, isEmpty);
  });

  test('erro http vira ApiException', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient({'detail': 'boom'}, status: 500),
    );

    expect(api.fetchWeeklyNews(), throwsA(isA<ApiException>()));
  });

  test('reescreve a imagem para o proxy da nossa api', () async {
    // A Camara nao manda CORS nas imagens; o Flutter Web nao consegue
    // desenha-las direto. O ApiClient aponta a miniatura para o nosso proxy.
    final payload = <String, dynamic>{
      ..._payload,
      'articles': <Map<String, dynamic>>[
        <String, dynamic>{
          ...(_payload['articles'] as List)[0] as Map<String, dynamic>,
          'image_url': 'https://www.camara.leg.br/midias/image/foto.jpg',
        },
      ],
    };
    final api = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient(payload),
    );

    final result = await api.fetchWeeklyNews();

    final url = result.articles.first.imageUrl!;
    expect(url, startsWith('https://api.test/api/v1/news/image?url='));
    expect(Uri.parse(url).queryParameters['url'],
        'https://www.camara.leg.br/midias/image/foto.jpg');
  });

  test('imagem nula continua nula depois da reescrita', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient(_payload),
    );

    final result = await api.fetchWeeklyNews();

    expect(result.articles.first.imageUrl, isNull);
  });

}
