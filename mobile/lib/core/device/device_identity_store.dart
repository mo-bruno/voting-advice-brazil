import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class _LocalUuidStore {
  const _LocalUuidStore({
    required this.key,
    required this.prefsFactory,
    required this.uuid,
  });

  final String key;
  final Future<SharedPreferences> Function() prefsFactory;
  final Uuid uuid;

  Future<String> getOrCreate() async {
    final prefs = await prefsFactory();
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = uuid.v4();
    await prefs.setString(key, created);
    return created;
  }
}

class DeviceIdentityStore {
  @visibleForTesting
  static const String deviceIdKey = 'farol_politico_device_id';

  final _LocalUuidStore _store;

  DeviceIdentityStore({
    Future<SharedPreferences> Function()? prefsFactory,
    Uuid? uuid,
  }) : _store = _LocalUuidStore(
          key: deviceIdKey,
          prefsFactory: prefsFactory ?? SharedPreferences.getInstance,
          uuid: uuid ?? const Uuid(),
        );

  Future<String> getOrCreateDeviceId() => _store.getOrCreate();
}

/// Identity scoped to demand validation so an interest cannot be joined to
/// quiz or community activity through the app's general-purpose UUID.
class PoliticianFollowInterestIdentityStore {
  @visibleForTesting
  static const String interestIdKey = 'farol_politico_follow_interest_id';

  final _LocalUuidStore _store;

  PoliticianFollowInterestIdentityStore({
    Future<SharedPreferences> Function()? prefsFactory,
    Uuid? uuid,
  }) : _store = _LocalUuidStore(
          key: interestIdKey,
          prefsFactory: prefsFactory ?? SharedPreferences.getInstance,
          uuid: uuid ?? const Uuid(),
        );

  Future<String> getOrCreateInterestId() => _store.getOrCreate();
}
