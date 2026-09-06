import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/home/news_session.dart';
import 'package:http/http.dart' as http;

const _payload = {
  'period_start': '2026-08-30',
  'period_end': '2026-09-06',
  'period_label': '30 DE AGO A 6 DE SET DE 2026',
  'total': 1,
  'articles': [
    {
      'id': 'a',
      'title': 'Titulo',
      'summary': 'Resumo',
      'image_url': null,
      'theme_slug': 'eleicoes',
      'theme_label': 'ELEIÇÕES',
      'published_at': '2026-09-04T12:49:00Z',
      'reading_minutes': 2,
      'url': 'https://example.org/a',
    }
  ],
};

class _StubClient extends http.BaseClient {
  _StubClient(this.body, {this.status = 200});

  final Object body;
  final int status;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

ApiClient _api(Object body, {int status = 200}) => ApiClient(
      baseUrl: 'https://api.test/api/v1',
      client: _StubClient(body, status: status),
    );

void main() {
  test('comeca em idle', () {
    final session = NewsSession.testOnly(api: _api(_payload));

    expect(session.status, NewsStatus.idle);
  });

  test('carrega e vira ready', () async {
    final session = NewsSession.testOnly(api: _api(_payload));

    await session.load();

    expect(session.status, NewsStatus.ready);
    expect(session.articles, hasLength(1));
    expect(session.periodLabel, '30 DE AGO A 6 DE SET DE 2026');
  });

  test('lista vazia vira empty', () async {
    final session = NewsSession.testOnly(
      api: _api({..._payload, 'total': 0, 'articles': <dynamic>[]}),
    );

    await session.load();

    expect(session.status, NewsStatus.empty);
  });

  test('falha vira error', () async {
    final session = NewsSession.testOnly(
      api: _api({'detail': 'boom'}, status: 500),
    );

    await session.load();

    expect(session.status, NewsStatus.error);
    expect(session.articles, isEmpty);
  });

  test('notifica os ouvintes ao carregar', () async {
    final session = NewsSession.testOnly(api: _api(_payload));
    var notifications = 0;
    session.addListener(() => notifications++);

    await session.load();

    expect(notifications, greaterThanOrEqualTo(2));
  });
}
