import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const existingDeviceId = '550e8400-e29b-41d4-a716-446655440000';
  final uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  group('DeviceIdentityStore', () {
    test('creates and persists a UUID v4 when none exists', () async {
      SharedPreferences.setMockInitialValues({});
      final store = DeviceIdentityStore();

      final first = await store.getOrCreateDeviceId();
      final second = await store.getOrCreateDeviceId();

      expect(first, matches(uuidV4Pattern));
      expect(second, first);
    });

    test('reuses an existing device id from local storage', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentityStore.deviceIdKey: existingDeviceId,
      });
      final store = DeviceIdentityStore();

      final deviceId = await store.getOrCreateDeviceId();

      expect(deviceId, existingDeviceId);
    });
  });
}
