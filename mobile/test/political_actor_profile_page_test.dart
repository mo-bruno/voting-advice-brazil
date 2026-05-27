import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/political_actors/political_actor_profile_page.dart';
import 'package:guia_eleitoral/shared/models/official_evidence.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';
import 'package:http/http.dart' as http;

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('retries transient evidence fetch without showing raw error',
      (tester) async {
    final actor = _actor(id: 172, name: 'Erika Hilton');
    final api = _FlakyEvidenceApiClient();
    final session = PoliticalActorSession.testOnly(api: api);

    await tester.pumpWidget(_profileApp(actor: actor, session: session));
    await tester.pump();

    expect(find.textContaining('ClientException'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));

    expect(api.evidenceCalls, 2);
    expect(find.text('Apresentou PRL'), findsOneWidget);
    expect(find.textContaining('ClientException'), findsNothing);
  });

  testWidgets('shows change action when current actor is already followed',
      (tester) async {
    final actor = _actor(id: 172, name: 'Erika Hilton');
    final session =
        PoliticalActorSession.testOnly(api: _StableEvidenceApiClient());
    session.replaceFollowedActor(actor);

    await tester.pumpWidget(_profileApp(actor: actor, session: session));
    await tester.pump();

    expect(find.text('ACOMPANHANDO'), findsOneWidget);
    expect(find.text('TROCAR POLITICO'), findsOneWidget);

    await tester.tap(find.text('TROCAR POLITICO'));
    await tester.pumpAndSettle();

    expect(find.text('search page'), findsOneWidget);
  });

  testWidgets('groups evidence by category and limits each category to five',
      (tester) async {
    final actor = _actor(id: 172, name: 'Erika Hilton');
    final session = PoliticalActorSession.testOnly(
      api: _GroupedEvidenceApiClient(),
    );

    await tester.pumpWidget(_profileApp(actor: actor, session: session));
    await tester.pumpAndSettle();

    expect(find.text('PROPOSICOES'), findsOneWidget);
    expect(find.text('DESPESAS PARLAMENTARES'), findsOneWidget);
    expect(find.text('VOTACOES RECENTES'), findsOneWidget);
    expect(find.text('Proposicao 1'), findsOneWidget);
    expect(find.text('Proposicao 5'), findsOneWidget);
    expect(find.text('Proposicao 6'), findsNothing);
    expect(find.text('Despesa 1'), findsOneWidget);
    expect(find.text('Voto 1'), findsOneWidget);
  });
}

Widget _profileApp({
  required PoliticalActor actor,
  required PoliticalActorSession session,
}) {
  return MaterialApp(
    routes: {
      '/political-actors': (_) => const Scaffold(body: Text('search page')),
    },
    home: Builder(
      builder: (context) {
        return Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: actor),
            builder: (_) => PoliticalActorProfilePage(session: session),
          ),
        );
      },
    ),
  );
}

class _FlakyEvidenceApiClient extends _StableEvidenceApiClient {
  int evidenceCalls = 0;

  @override
  Future<EvidenceResponse> fetchOfficialEvidence(int actorId) async {
    evidenceCalls++;
    if (evidenceCalls == 1) {
      throw http.ClientException(
        'Failed to fetch',
        Uri.parse(
            'https://example.test/api/v1/political-actors/$actorId/evidence'),
      );
    }
    return super.fetchOfficialEvidence(actorId);
  }
}

class _StableEvidenceApiClient extends ApiClient {
  _StableEvidenceApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<EvidenceResponse> fetchOfficialEvidence(int actorId) async {
    final now = DateTime(2026, 5, 12);
    return EvidenceResponse(
      cacheStatus: 'fresh',
      evidence: [
        OfficialEvidence(
          id: 1,
          politicalActorId: actorId,
          source: 'camara',
          sourceId: 'proposition:1',
          type: EvidenceType.proposition,
          title: 'Apresentou PRL',
          summary: 'Parecer da relatora.',
          evidenceDate: now,
          sourceUrl: null,
          fetchedAt: now,
          expiresAt: now,
        ),
      ],
    );
  }
}

class _GroupedEvidenceApiClient extends ApiClient {
  _GroupedEvidenceApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<EvidenceResponse> fetchOfficialEvidence(int actorId) async {
    final now = DateTime(2026, 5, 12);
    return EvidenceResponse(
      cacheStatus: 'fresh',
      evidence: [
        for (var i = 1; i <= 6; i++)
          _evidence(
            actorId: actorId,
            id: i,
            type: EvidenceType.proposition,
            title: 'Proposicao $i',
            now: now,
          ),
        _evidence(
          actorId: actorId,
          id: 7,
          type: EvidenceType.expense,
          title: 'Despesa 1',
          now: now,
        ),
        _evidence(
          actorId: actorId,
          id: 8,
          type: EvidenceType.vote,
          title: 'Voto 1',
          now: now,
        ),
      ],
    );
  }
}

OfficialEvidence _evidence({
  required int actorId,
  required int id,
  required EvidenceType type,
  required String title,
  required DateTime now,
}) {
  return OfficialEvidence(
    id: id,
    politicalActorId: actorId,
    source: 'camara',
    sourceId: '$type:$id',
    type: type,
    title: title,
    summary: 'Resumo oficial.',
    evidenceDate: now,
    sourceUrl: null,
    fetchedAt: now,
    expiresAt: now,
  );
}

PoliticalActor _actor({required int id, required String name}) {
  return PoliticalActor(
    id: id,
    source: 'camara',
    sourceId: '$id',
    displayName: name,
    party: 'PSOL',
    state: 'SP',
    role: 'federal_deputy',
    status: 'active',
    photoUrl: null,
    sourceUrl: null,
    lastIndexedAt: DateTime(2026, 5, 6),
  );
}
