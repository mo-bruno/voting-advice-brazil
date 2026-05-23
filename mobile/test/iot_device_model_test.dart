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
