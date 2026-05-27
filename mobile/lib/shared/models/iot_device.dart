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

class IotManualPairingInput {
  final String pairingCode;
  final String shortId;

  const IotManualPairingInput({
    required this.pairingCode,
    required this.shortId,
  });

  String get normalizedPairingCode {
    return pairingCode.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String get normalizedShortId {
    return shortId.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
  }

  bool get isValid {
    return RegExp(r'^[0-9]{6}$').hasMatch(normalizedPairingCode) &&
        RegExp(r'^[0-9a-f]{8}$').hasMatch(normalizedShortId);
  }
}

import 'package:flutter/material.dart';

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

class IotLastEvent {
  final String deputyName;
  final String party;
  final String state;
  final String vote;
  final String alignment;
  final String description;
  final DateTime timestampUtc;

  const IotLastEvent({
    required this.deputyName,
    required this.party,
    required this.state,
    required this.vote,
    required this.alignment,
    required this.description,
    required this.timestampUtc,
  });

  factory IotLastEvent.fromJson(Map<String, dynamic> json) {
    return IotLastEvent(
      deputyName: json['deputy_name'] as String,
      party: json['party'] as String,
      state: json['state'] as String,
      vote: json['vote'] as String,
      alignment: json['alignment'] as String,
      description: json['description'] as String,
      timestampUtc: DateTime.parse(json['timestamp_utc'] as String),
    );
  }

  Color get alignmentColor {
    switch (alignment) {
      case 'aligned':
        return const Color(0xFF1B6D24);
      case 'divergent':
        return const Color(0xFFBA1A1A);
      default:
        return const Color(0xFFFFE000);
    }
  }

  String get alignmentLabel {
    switch (alignment) {
      case 'aligned':
        return 'ALINHADO';
      case 'divergent':
        return 'DIVERGENTE';
      default:
        return 'ABSTENCAO';
    }
  }
}
