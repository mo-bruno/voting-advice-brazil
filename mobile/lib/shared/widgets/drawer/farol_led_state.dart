// lib/shared/widgets/drawer/farol_led_state.dart
//
// Traduz o par (dispositivo, ultimo evento) numa unica cor de LED — a mesma
// decisao que o firmware toma no hardware, feita aqui para a gaveta. E logica
// pura de proposito: sem widget, sem rede e sem DateTime.now() implicito, entao
// da para testar as regras de prioridade sem montar tela nenhuma.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../models/iot_device.dart';

/// Silencio maior que isto e tratado como dispositivo desligado. O aparelho nao
/// avisa que caiu — so para de dar sinal —, entao a gaveta infere pela idade do
/// ultimo contato em vez de esperar um status que nunca chega.
const Duration kFarolOfflineAfter = Duration(minutes: 15);

enum FarolLedState {
  aligned,
  abstention,
  divergent,
  pending,
  offline,
  absent,
}

/// Prioridade entre os tres fatos, do mais forte para o mais fraco:
/// 1. nao ha dispositivo vinculado  -> `absent`
/// 2. ele nao da sinal ha um tempo  -> `offline` (um LED apagado nao tem cor,
///    entao isto vence ate um evento recente)
/// 3. ha evento                     -> a cor do alinhamento
/// 4. nada aconteceu ainda          -> `pending`
FarolLedState farolLedStateFor({
  required IotDevice? device,
  required IotLastEvent? lastEvent,
  required DateTime now,
}) {
  if (device == null || !device.isLinked) return FarolLedState.absent;

  final lastSeenAt = device.lastSeenAt;
  if (lastSeenAt == null || now.difference(lastSeenAt) > kFarolOfflineAfter) {
    return FarolLedState.offline;
  }

  if (lastEvent == null) return FarolLedState.pending;

  switch (lastEvent.alignment) {
    case 'aligned':
      return FarolLedState.aligned;
    case 'divergent':
      return FarolLedState.divergent;
    default:
      return FarolLedState.abstention;
  }
}

extension FarolLedStateVisuals on FarolLedState {
  /// A cor que identifica o estado. Nos tres alinhamentos ela e a mesma que o
  /// firmware acende; nos outros tres representa o aparelho, nao um voto.
  Color get color => switch (this) {
        FarolLedState.aligned => AppTheme.ledAligned,
        FarolLedState.abstention => AppTheme.ledAbstention,
        FarolLedState.divergent => AppTheme.ledDivergent,
        FarolLedState.pending => AppTheme.ledPending,
        FarolLedState.offline => AppTheme.ledOff,
        FarolLedState.absent => AppTheme.ledOff,
      };

  /// Tinta legivel sobre `color` quando ela vira fundo de etiqueta.
  Color get ink =>
      this == FarolLedState.divergent ? Colors.white : Colors.black;

  /// `null` onde nao ha nada a rotular: sem dispositivo, o bloco fala por
  /// extenso em vez de mostrar uma etiqueta de estado.
  String? get label => switch (this) {
        FarolLedState.aligned => 'ALINHADO',
        FarolLedState.abstention => 'ABSTENCAO',
        FarolLedState.divergent => 'DIVERGENTE',
        FarolLedState.pending => 'AGUARDANDO VOTAÇÃO',
        FarolLedState.offline => 'DISPOSITIVO OFFLINE',
        FarolLedState.absent => null,
      };

  /// So os tres alinhamentos viram etiqueta solida — os outros estados nao
  /// descrevem um voto, entao ficam em texto simples.
  bool get isVote =>
      this == FarolLedState.aligned ||
      this == FarolLedState.abstention ||
      this == FarolLedState.divergent;

  /// O ponto so brilha quando ha luz acesa de verdade.
  bool get isLit => isVote || this == FarolLedState.pending;
}

/// Quanto da cor do estado vaza para o cabecalho da gaveta.
///
/// Os alfas nao sao iguais de proposito: sobre o fundo #131313 um verde escuro
/// a 22% some enquanto um amarelo puro a 40% grita. Os valores foram escolhidos
/// para que os quatro estados cheguem com o mesmo PESO, nao com a mesma
/// formula. `0` significa cabecalho sem halo.
extension FarolLedStateHalo on FarolLedState {
  double get haloAlpha => switch (this) {
        FarolLedState.aligned => 0.40,
        FarolLedState.divergent => 0.30,
        FarolLedState.abstention => 0.22,
        FarolLedState.pending => 0.55,
        FarolLedState.offline => 0,
        FarolLedState.absent => 0,
      };
}
