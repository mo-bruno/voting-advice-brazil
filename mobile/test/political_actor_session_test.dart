import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';

void main() {
  test('replaceFollowedActor replaces the current followed actor', () {
    final first = PoliticalActor(
      id: 1,
      source: 'camara',
      sourceId: '101',
      displayName: 'Maria Silva',
      party: 'PT',
      state: 'SP',
      role: 'federal_deputy',
      status: 'active',
      photoUrl: null,
      sourceUrl: null,
      lastIndexedAt: DateTime(2026, 5, 6),
    );
    final second = PoliticalActor(
      id: 2,
      source: 'camara',
      sourceId: '102',
      displayName: 'Joao Pereira',
      party: 'PSD',
      state: 'MG',
      role: 'federal_deputy',
      status: 'active',
      photoUrl: null,
      sourceUrl: null,
      lastIndexedAt: DateTime(2026, 5, 6),
    );

    final session = PoliticalActorSession.testOnly();

    session.replaceFollowedActor(first);
    session.replaceFollowedActor(second);

    expect(session.followedActor?.id, 2);
  });
}
