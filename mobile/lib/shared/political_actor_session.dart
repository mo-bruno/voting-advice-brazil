import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/device/device_identity_store.dart';
import 'models/official_evidence.dart';
import 'models/political_actor.dart';

class PoliticalActorSession extends ChangeNotifier {
  PoliticalActorSession._({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  })  : api = api ?? ApiClient(),
        deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

  @visibleForTesting
  factory PoliticalActorSession.testOnly({
    ApiClient? api,
    DeviceIdentityStore? deviceIdentityStore,
  }) =>
      PoliticalActorSession._(
        api: api,
        deviceIdentityStore: deviceIdentityStore,
      );

  static final PoliticalActorSession instance = PoliticalActorSession._();

  final ApiClient api;
  final DeviceIdentityStore deviceIdentityStore;
  PoliticalActor? followedActor;
  List<TrendingPoliticalActor> trending = [];
  List<PoliticalActor> searchResults = [];
  List<OfficialEvidence> evidence = [];
  String? cacheStatus;

  Future<void> loadFollowedActor() async {
    try {
      final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
      followedActor = await api.fetchFollowedPoliticalActor(
        anonymousId: anonymousId,
      );
      notifyListeners();
    } catch (_) {
      // Network failures are non-fatal; UI degrades gracefully.
    }
  }

  Future<void> followActor(PoliticalActor actor) async {
    final anonymousId = await deviceIdentityStore.getOrCreateDeviceId();
    followedActor = await api.followPoliticalActor(
      actorId: actor.id,
      anonymousId: anonymousId,
    );
    notifyListeners();
  }

  void replaceFollowedActor(PoliticalActor actor) {
    followedActor = actor;
    notifyListeners();
  }
}
