import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';

class FakeApiClient extends ApiClient {
  String? fetchedAnonymousId;
  String? followedAnonymousId;

  FakeApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<PoliticalActor?> fetchFollowedPoliticalActor({
    required String anonymousId,
  }) async {
    fetchedAnonymousId = anonymousId;
    return _actor(id: 7, name: 'Erika Hilton');
  }

  @override
  Future<PoliticalActor> followPoliticalActor({
    required int actorId,
    required String anonymousId,
  }) async {
    followedAnonymousId = anonymousId;
    return _actor(id: actorId, name: 'Erika Hilton');
  }
}

class FakeDeviceIdentityStore extends DeviceIdentityStore {
  FakeDeviceIdentityStore() : super();

  @override
  Future<String> getOrCreateDeviceId() async => 'device-123';
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

void main() {
  test('replaceFollowedActor replaces the current followed actor', () {
    final first = _actor(id: 1, name: 'Maria Silva');
    final second = _actor(id: 2, name: 'Joao Pereira');

    final session = PoliticalActorSession.testOnly();

    session.replaceFollowedActor(first);
    session.replaceFollowedActor(second);

    expect(session.followedActor?.id, 2);
  });

  test('loadFollowedActor uses the persisted device id', () async {
    final api = FakeApiClient();
    final session = PoliticalActorSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.loadFollowedActor();

    expect(api.fetchedAnonymousId, 'device-123');
    expect(session.followedActor?.displayName, 'Erika Hilton');
  });

  test('followActor persists follow with the device id', () async {
    final api = FakeApiClient();
    final session = PoliticalActorSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.followActor(_actor(id: 7, name: 'Erika Hilton'));

    expect(api.followedAnonymousId, 'device-123');
    expect(session.followedActor?.id, 7);
  });
}
