import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityStore {
  @visibleForTesting
  static const String deviceIdKey = 'farol_politico_device_id';

  final Future<SharedPreferences> Function() _prefsFactory;
  final Uuid _uuid;

  DeviceIdentityStore({
    Future<SharedPreferences> Function()? prefsFactory,
    Uuid? uuid,
  })  : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance,
        _uuid = uuid ?? const Uuid();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await _prefsFactory();
    final existing = prefs.getString(deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _uuid.v4();
    await prefs.setString(deviceIdKey, created);
    return created;
  }
}
