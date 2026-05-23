import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

class FakeApiClient extends ApiClient {
  String? fetchedAnonymousId;
  String? pairedAnonymousId;
  String? pairedDeviceToken;
  String? pairedCode;

  FakeApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<IotDevice?> fetchIotDevice({required String anonymousId}) async {
    fetchedAnonymousId = anonymousId;
    return null;
  }

  @override
  Future<IotDevice> pairIotDevice({
    required String anonymousId,
    required String deviceToken,
    required String pairingCode,
  }) async {
    pairedAnonymousId = anonymousId;
    pairedDeviceToken = deviceToken;
    pairedCode = pairingCode;
    return IotDevice(
      deviceToken: deviceToken,
      status: 'linked',
      linkedAt: DateTime(2026, 5, 22),
      updatedAt: DateTime(2026, 5, 22),
      lastSeenAt: null,
    );
  }
}

class FakeDeviceIdentityStore extends DeviceIdentityStore {
  FakeDeviceIdentityStore() : super();

  @override
  Future<String> getOrCreateDeviceId() async => 'anon-1';
}

void main() {
  test('loadStatus uses persisted anonymous id', () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.loadStatus();

    expect(api.fetchedAnonymousId, 'anon-1');
    expect(session.device, isNull);
  });

  test('pairWithPayload stores linked device', () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.pairWithPayload(
      const IotPairingPayload(
        deviceToken: '550e8400-e29b-41d4-a716-446655440000',
        pairingCode: '482913',
      ),
    );

    expect(api.pairedAnonymousId, 'anon-1');
    expect(api.pairedDeviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(api.pairedCode, '482913');
    expect(session.device?.isLinked, isTrue);
  });
}
