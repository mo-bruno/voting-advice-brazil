import 'package:flutter/material.dart';

// `timeAgo` saiu daqui para `shared/utils/` quando a gaveta passou a datar o
// ultimo evento do Farol. Reexportado para que as telas da comunidade sigam
// importando um arquivo so.
export '../../../shared/utils/time_ago.dart';

Color avatarColor(String authorAlias) {
  const colors = [
    Color(0xFF1B6D24),
    Color(0xFF0C2B6E),
    Color(0xFF7B3F00),
    Color(0xFF6B2E89),
    Color(0xFF2E7D8C),
    Color(0xFF8B7000),
    Color(0xFF8B2222),
  ];
  return colors[authorAlias.hashCode.abs() % colors.length];
}

String avatarInitials(String authorAlias) {
  final name =
      authorAlias.startsWith('u/') ? authorAlias.substring(2) : authorAlias;
  if (name.length >= 2) return name.substring(0, 2).toUpperCase();
  return '??';
}
