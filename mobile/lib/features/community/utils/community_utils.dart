import 'package:flutter/material.dart';

// `timeAgo` saiu daqui para `shared/utils/` quando a gaveta passou a datar o
// ultimo evento do Farol. Reexportado para que as telas da comunidade sigam
// importando um arquivo so.
export '../../../shared/utils/time_ago.dart';

Color avatarColor(String anonymousId) {
  const colors = [
    Color(0xFF1B6D24),
    Color(0xFF0C2B6E),
    Color(0xFF7B3F00),
    Color(0xFF6B2E89),
    Color(0xFF2E7D8C),
    Color(0xFF8B7000),
    Color(0xFF8B2222),
  ];
  return colors[anonymousId.hashCode.abs() % colors.length];
}

String shortUsername(String anonymousId) {
  final len = anonymousId.length;
  return 'u/${anonymousId.substring(0, len < 6 ? len : 6)}';
}

String avatarInitials(String anonymousId) {
  if (anonymousId.length >= 2) return anonymousId.substring(0, 2).toUpperCase();
  return '??';
}
