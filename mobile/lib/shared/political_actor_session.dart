import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import 'models/official_evidence.dart';
import 'models/political_actor.dart';

class PoliticalActorSession extends ChangeNotifier {
  PoliticalActorSession._({ApiClient? api, String? anonymousId})
      : api = api ?? ApiClient(),
        anonymousId = anonymousId ?? _newAnonymousId();

  @visibleForTesting
  factory PoliticalActorSession.testOnly({
    ApiClient? api,
    String anonymousId = 'anon-test',
  }) =>
      PoliticalActorSession._(api: api, anonymousId: anonymousId);

  static final PoliticalActorSession instance = PoliticalActorSession._();

  final ApiClient api;
  final String anonymousId;
  PoliticalActor? followedActor;
  List<TrendingPoliticalActor> trending = [];
  List<PoliticalActor> searchResults = [];
  List<OfficialEvidence> evidence = [];
  String? cacheStatus;

  static String _newAnonymousId() {
    return 'anon-${DateTime.now().microsecondsSinceEpoch}';
  }

  void replaceFollowedActor(PoliticalActor actor) {
    followedActor = actor;
    notifyListeners();
  }
}
