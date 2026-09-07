// lib/shared/widgets/drawer/farol_status_tile.dart
//
// O bloco do topo da gaveta: o que o LED do gadget esta mostrando agora. E o
// unico bloco colorido da gaveta, e tambem o caminho para a tela do
// dispositivo — por isso nao existe um item "Meu Farol" separado na lista.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../models/iot_device.dart';
import '../../utils/time_ago.dart';
import 'farol_led_state.dart';

class FarolStatusTile extends StatelessWidget {
  const FarolStatusTile({
    super.key,
    required this.device,
    required this.lastEvent,
    required this.onOpenDevice,
    required this.onPair,
    this.now,
  });

  final IotDevice? device;
  final IotLastEvent? lastEvent;
  final VoidCallback onOpenDevice;
  final VoidCallback onPair;

  /// Fixavel em teste. Ausente em producao, onde o relogio e o do sistema.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final state = farolLedStateFor(
      device: device,
      lastEvent: lastEvent,
      now: clock,
    );
    final absent = state == FarolLedState.absent;

    return InkWell(
      // Sem dispositivo o bloco inteiro nao e um destino: o unico caminho dali
      // e o botao de parear, que tem acao propria.
      onTap: absent ? null : onOpenDevice,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow(state: state, trailing: _timestamp(clock)),
            const SizedBox(height: 14),
            if (absent)
              _AbsentBody(onPair: onPair)
            else
              _PresentBody(
                state: state,
                lastEvent: state.isVote ? lastEvent : null,
                deviceLabel: 'Farol ${device!.shortToken}',
                detail: _detail(state, clock),
              ),
          ],
        ),
      ),
    );
  }

  /// O horario no canto do cabecalho data o que o bloco mostra. No estado
  /// offline ele fica de fora: a data do sumico ja aparece por extenso no
  /// corpo, e repetir daria dois relogios discordantes lado a lado.
  String? _timestamp(DateTime clock) {
    final event = lastEvent;
    if (event != null &&
        farolLedStateFor(device: device, lastEvent: event, now: clock).isVote) {
      return timeAgo(event.timestampUtc, now: clock);
    }
    final lastSeenAt = device?.lastSeenAt;
    if (lastSeenAt != null &&
        clock.difference(lastSeenAt) <= kFarolOfflineAfter) {
      return timeAgo(lastSeenAt, now: clock);
    }
    return null;
  }

  String? _detail(FarolLedState state, DateTime clock) {
    switch (state) {
      case FarolLedState.pending:
        return 'Conectado • nenhum evento ainda';
      case FarolLedState.offline:
        final lastSeenAt = device?.lastSeenAt;
        return lastSeenAt == null
            ? 'Nunca deu sinal desde o pareamento'
            : 'Visto pela última vez ${timeAgo(lastSeenAt, now: clock)}';
      default:
        return null;
    }
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.state, this.trailing});

  final FarolLedState state;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    // Apagado, o cabecalho tambem apaga: a barra e o rotulo saem do branco para
    // o cinza, e o bloco recua na hierarquia sem precisar mudar de lugar.
    final lit = state.isLit;
    final trailingText = trailing;

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          color: lit ? AppTheme.primary : AppTheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          'MEU FAROL',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: lit ? AppTheme.primary : AppTheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (trailingText != null)
          Text(
            trailingText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _PresentBody extends StatelessWidget {
  const _PresentBody({
    required this.state,
    required this.lastEvent,
    required this.deviceLabel,
    required this.detail,
  });

  final FarolLedState state;
  final IotLastEvent? lastEvent;
  final String deviceLabel;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final event = lastEvent;
    final label = state.label;
    final detailText = detail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LedDot(state: state),
            const SizedBox(width: 10),
            if (label != null)
              state.isVote
                  ? Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: state.color,
                      child: Text(
                        label,
                        style: textTheme.labelLarge!.copyWith(color: state.ink),
                      ),
                    )
                  // Sem voto para anunciar, o rotulo desce para o tamanho de
                  // legenda: em 304px "AGUARDANDO VOTAÇÃO" no corpo da etiqueta
                  // estouraria a linha, e ele nao merece o mesmo peso do badge.
                  : Expanded(
                      child: Text(
                        label,
                        style: textTheme.labelMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          event?.deputyName ?? deviceLabel,
          style: textTheme.titleLarge,
        ),
        if (event != null)
          Text('${event.party} • ${event.state}', style: textTheme.bodySmall),
        if (detailText != null)
          Text(detailText, style: textTheme.bodySmall),
      ],
    );
  }
}

class _AbsentBody extends StatelessWidget {
  const _AbsentBody({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LedDot(state: FarolLedState.absent),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Nenhum dispositivo', style: textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Um LED físico que muda de cor quando o político que você segue vota.',
          style: textTheme.bodySmall!.copyWith(height: 1.45),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPair,
            style: OutlinedButton.styleFrom(
              // O padding padrao (32) e largo demais para os 304px da gaveta.
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            ),
            child: const Text('PAREAR DISPOSITIVO'),
          ),
        ),
      ],
    );
  }
}

class _LedDot extends StatelessWidget {
  const _LedDot({required this.state});

  final FarolLedState state;

  @override
  Widget build(BuildContext context) {
    final lit = state.isLit;

    final dot = Container(
      key: const Key('farol-led-dot'),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Apagado o ponto fica vazado: um circulo cinza cheio pareceria uma
        // quarta cor de LED, e o gadget nao acende cinza.
        color: lit ? state.color : AppTheme.surface,
        border: lit ? null : Border.all(color: state.color, width: 1.5),
        boxShadow: lit
            ? [
                BoxShadow(
                  color: state.color.withValues(alpha: 0.7),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
    );

    // O gadget pulsa em azul enquanto espera uma votacao; a gaveta faz o mesmo,
    // e por isso so o estado pendente anima. Um voto ja se explica pela cor —
    // pulsar ali seria movimento sem informacao nova.
    if (state != FarolLedState.pending) return dot;

    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [_PulseRing(color: state.color), dot],
      ),
    );
  }
}

/// O anel que se expande e some, repetindo. Fica fora do `_LedDot` porque so
/// ele precisa de um `Ticker`, e um StatefulWidget para os outros estados seria
/// um controlador de animacao criado e destruido a toa.
class _PulseRing extends StatefulWidget {
  const _PulseRing({required this.color});

  final Color color;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A onda so ocupa os primeiros 70% do ciclo; o resto e a pausa entre
    // batidas, que e o que faz o movimento parecer respiracao e nao piscada.
    final wave = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    );

    return ScaleTransition(
      key: const Key('farol-led-pulse'),
      scale: Tween<double>(begin: 1, end: 2.6).animate(wave),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.55, end: 0).animate(wave),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
