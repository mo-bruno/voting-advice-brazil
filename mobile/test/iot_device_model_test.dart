import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';

void main() {
  test('IotPairingPayload parses farol pair uri', () {
    final payload = IotPairingPayload.parse(
      'farol://pair?device_token=550e8400-e29b-41d4-a716-446655440000&pairing_code=482913',
    );

    expect(payload.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(payload.pairingCode, '482913');
  });

  test('IotPairingPayload rejects invalid scheme', () {
    expect(
      () => IotPairingPayload.parse('https://example.test/pair'),
      throwsA(isA<FormatException>()),
    );
  });

  test('IotManualPairingInput normalizes code and short id', () {
    const input = IotManualPairingInput(
      pairingCode: '482 913',
      shortId: '2D90 AE25',
    );

    expect(input.normalizedPairingCode, '482913');
    expect(input.normalizedShortId, '2d90ae25');
    expect(input.isValid, isTrue);
  });

  test('IotManualPairingInput rejects invalid values', () {
    const input = IotManualPairingInput(
      pairingCode: '48291',
      shortId: '2D90 AE2X',
    );

    expect(input.normalizedPairingCode, '48291');
    expect(input.normalizedShortId, '2d90ae2');
    expect(input.isValid, isFalse);
  });

  test('IotDevice parses backend payload', () {
    final device = IotDevice.fromJson({
      'device_token': '550e8400-e29b-41d4-a716-446655440000',
      'status': 'linked',
      'linked_at': '2026-05-22T20:00:00Z',
      'updated_at': '2026-05-22T20:01:00Z',
      'last_seen_at': null,
    });

    expect(device.deviceToken, '550e8400-e29b-41d4-a716-446655440000');
    expect(device.isLinked, isTrue);
  });
}
