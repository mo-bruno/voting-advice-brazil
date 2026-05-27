import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

class FakeApiClient extends ApiClient {
  String? fetchedAnonymousId;
  String? pairedAnonymousId;
  String? pairedDeviceToken;
  String? pairedDeviceTokenPrefix;
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
    String? deviceToken,
    String? deviceTokenPrefix,
    required String pairingCode,
  }) async {
    pairedAnonymousId = anonymousId;
    pairedDeviceToken = deviceToken;
    pairedDeviceTokenPrefix = deviceTokenPrefix;
    pairedCode = pairingCode;
    return IotDevice(
      deviceToken:
          deviceToken ?? '$deviceTokenPrefix-e29b-41d4-a716-446655440000',
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

class FakeThrowingApiClient extends ApiClient {
  FakeThrowingApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<IotDevice> pairIotDevice({
    required String anonymousId,
    String? deviceToken,
    String? deviceTokenPrefix,
    required String pairingCode,
  }) async {
    throw Exception('network error');
  }
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

  test('pairWithManualCode stores linked device using normalized input',
      () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.pairWithManualCode(
      const IotManualPairingInput(
        pairingCode: '482 913',
        shortId: '2D90 AE25',
      ),
    );

    expect(api.pairedAnonymousId, 'anon-1');
    expect(api.pairedDeviceToken, isNull);
    expect(api.pairedDeviceTokenPrefix, '2d90ae25');
    expect(api.pairedCode, '482913');
    expect(session.device?.isLinked, isTrue);
    expect(session.loading, isFalse);
    expect(session.error, isNull);
  });

  test('pairWithManualCode rejects invalid input without calling api',
      () async {
    final api = FakeApiClient();
    final session = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await session.pairWithManualCode(
      const IotManualPairingInput(
        pairingCode: '48291',
        shortId: '2D90 AE25',
      ),
    );

    expect(api.pairedAnonymousId, isNull);
    expect(session.error, isNotNull);
    expect(session.loading, isFalse);
  });

  test('pairWithPayload sets error and rethrows on failure', () async {
    final session = IotDeviceSession.testOnly(
      api: FakeThrowingApiClient(),
      deviceIdentityStore: FakeDeviceIdentityStore(),
    );

    await expectLater(
      session.pairWithPayload(
        const IotPairingPayload(
          deviceToken: '550e8400-e29b-41d4-a716-446655440000',
          pairingCode: '482913',
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(session.error, isNotNull);
    expect(session.loading, isFalse);
  });
}
