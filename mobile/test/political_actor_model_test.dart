import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/official_evidence.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';

void main() {
  group('PoliticalActor.fromJson', () {
    test('parses backend actor payload', () {
      final actor = PoliticalActor.fromJson({
        'id': 1,
        'source': 'camara',
        'source_id': '101',
        'display_name': 'Maria Silva',
        'party': 'PT',
        'state': 'SP',
        'role': 'federal_deputy',
        'status': 'active',
        'photo_url': null,
        'source_url': 'https://dadosabertos.camara.leg.br/api/v2/deputados/101',
        'last_indexed_at': '2026-05-06T12:00:00Z',
      });

      expect(actor.id, 1);
      expect(actor.displayName, 'Maria Silva');
      expect(actor.party, 'PT');
      expect(actor.state, 'SP');
      expect(actor.roleLabel, 'Deputada(o) federal');
    });
  });

  group('OfficialEvidence.fromJson', () {
    test('parses evidence card payload', () {
      final evidence = OfficialEvidence.fromJson({
        'id': 10,
        'political_actor_id': 1,
        'source': 'camara',
        'source_id': 'vote:2468-1:101',
        'evidence_type': 'vote',
        'title': 'Votou Sim',
        'summary': 'Votacao nominal do PL 123/2026.',
        'evidence_date': '2026-04-12T18:30:00Z',
        'source_url':
            'https://dadosabertos.camara.leg.br/api/v2/votacoes/2468-1',
        'fetched_at': '2026-05-06T12:00:00Z',
        'expires_at': '2026-05-07T12:00:00Z',
      });

      expect(evidence.type, EvidenceType.vote);
      expect(evidence.title, 'Votou Sim');
      expect(evidence.sourceLabel, 'Fonte: Camara dos Deputados');
    });
  });
}
