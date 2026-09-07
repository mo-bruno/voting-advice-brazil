// lib/shared/utils/time_ago.dart
//
// Idade de um instante em texto curto. Vive em `shared/` porque nao pertence a
// nenhuma feature: a comunidade usa para datar posts e a gaveta usa para datar
// o ultimo evento do Farol. Uma segunda implementacao levaria as duas telas a
// dizerem "ha 2h" e "2 horas atras" para o mesmo instante.

/// `now` existe para o teste poder fixar o relogio; em producao fica ausente.
String timeAgo(DateTime dt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays}d';
  if (diff.inDays < 30) return 'há ${(diff.inDays / 7).floor()}sem';
  if (diff.inDays < 365) return 'há ${(diff.inDays / 30).floor()}m';
  return 'há ${(diff.inDays / 365).floor()}a';
}
