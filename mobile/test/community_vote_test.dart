import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/community_session.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _post(String id, {int score = 3}) => {
      'id': id,
      'author_alias': 'u/abc123def0',
      'is_mine': false,
      'content': 'Conteudo do post $id',
      'political_actor_id': null,
      'theme_slug': null,
      'score': score,
      'created_at': '2026-09-04T12:00:00Z',
    };

/// Responde a listagem na hora e segura o voto ate o teste liberar, para que o
/// estado "votando" seja observavel de forma deterministica.
class _VoteGateClient extends http.BaseClient {
  _VoteGateClient(this.gate);

  final Future<void> gate;
  int voteCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isVote = request.url.path.contains('/votes');
    Object body;
    if (isVote) {
      voteCalls++;
      await gate;
      body = _post('a', score: 4);
    } else {
      body = {
        'posts': [_post('a')],
        'has_next': false,
      };
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommunitySession().invalidate();
  });

  testWidgets('toques repetidos nao disparam votos concorrentes',
      (tester) async {
    final gate = Completer<void>();
    final client = _VoteGateClient(gate.future);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: CommunityFeedPage(
        apiClient:
            ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final seta = find.byIcon(Icons.keyboard_arrow_up_rounded);
    expect(seta, findsOneWidget);

    await tester.tap(seta);
    await tester.pump();
    // Enquanto a primeira requisicao esta em voo, mais toques nao devem
    // disparar novas. Sem a trava, cada toque virava uma chamada.
    await tester.tap(seta, warnIfMissed: false);
    await tester.pump();
    await tester.tap(seta, warnIfMissed: false);
    await tester.pump();

    expect(client.voteCalls, 1);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Depois que termina, votar de novo volta a funcionar.
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('score so muda depois da resposta do servidor', (tester) async {
    final gate = Completer<void>();
    final client = _VoteGateClient(gate.future);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: CommunityFeedPage(
        apiClient:
            ApiClient(baseUrl: 'https://api.test/api/v1', client: client),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();

    // Nada de atualizacao otimista: o backend faz upsert e recalcula o score, e
    // o PostOut nao devolve o voto do usuario — o cliente nao tem como prever
    // o resultado. Mostrar um numero chutado e corrigir depois seria pior.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsNothing);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('4'), findsOneWidget);
  });
}
