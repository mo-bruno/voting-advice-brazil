class IotPairingPayload {
  final String deviceToken;
  final String pairingCode;

  const IotPairingPayload({
    required this.deviceToken,
    required this.pairingCode,
  });

  factory IotPairingPayload.parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'farol' || uri.host != 'pair') {
      throw const FormatException('QR Code do Farol invalido.');
    }
    final deviceToken = uri.queryParameters['device_token'];
    final pairingCode = uri.queryParameters['pairing_code'];
    final codePattern = RegExp(r'^[0-9]{6}$');
    if (deviceToken == null || deviceToken.isEmpty) {
      throw const FormatException('QR Code sem token do dispositivo.');
    }
    if (pairingCode == null || !codePattern.hasMatch(pairingCode)) {
      throw const FormatException('QR Code sem codigo de pareamento valido.');
    }
    return IotPairingPayload(
      deviceToken: deviceToken,
      pairingCode: pairingCode,
    );
  }
}

class IotDevice {
  final String deviceToken;
  final String status;
  final DateTime linkedAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  const IotDevice({
    required this.deviceToken,
    required this.status,
    required this.linkedAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  factory IotDevice.fromJson(Map<String, dynamic> json) {
    return IotDevice(
      deviceToken: json['device_token'] as String,
      status: json['status'] as String,
      linkedAt: DateTime.parse(json['linked_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
    );
  }

  String get shortToken {
    if (deviceToken.length <= 8) return deviceToken;
    return deviceToken.substring(0, 8).toUpperCase();
  }

  bool get isLinked => status == 'linked';
}
