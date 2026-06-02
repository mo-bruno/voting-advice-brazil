import 'package:flutter/material.dart';

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays}d';
  if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()}sem';
  if (diff.inDays < 365) return 'há ${(diff.inDays / 30).floor()}m';
  return 'há ${(diff.inDays / 365).floor()}a';
}

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
