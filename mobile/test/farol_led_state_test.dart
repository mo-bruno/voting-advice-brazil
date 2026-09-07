import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/farol_led_state.dart';

/// A gaveta resume o dispositivo numa cor so. Qual cor e uma decisao de
/// prioridade entre tres fatos independentes (ha dispositivo? ele deu sinal
/// recente? houve evento?), entao vive numa funcao pura — testavel sem montar
/// widget e sem relogio real.
void main() {
  final agora = DateTime.utc(2026, 3, 10, 12, 0);

  IotDevice deviceVisto(Duration atras, {String status = 'linked'}) {
    return IotDevice(
      deviceToken: 'a3f9c21b0000',
      status: status,
      linkedAt: agora.subtract(const Duration(days: 30)),
      updatedAt: agora.subtract(atras),
      lastSeenAt: agora.subtract(atras),
    );
  }

  IotLastEvent eventoCom(String alignment) {
    return IotLastEvent(
      deputyName: 'Ana Vasconcelos',
      party: 'PDT',
      state: 'RS',
      vote: 'NAO',
      alignment: alignment,
      description: 'PL 1234/2025',
      timestampUtc: agora.subtract(const Duration(hours: 2)),
    );
  }

  group('sem dispositivo utilizavel', () {
    test('nenhum dispositivo pareado', () {
      expect(
        farolLedStateFor(device: null, lastEvent: null, now: agora),
        FarolLedState.absent,
      );
    });

    test('dispositivo desvinculado conta como ausente', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(Duration.zero, status: 'unlinked'),
          lastEvent: null,
          now: agora,
        ),
        FarolLedState.absent,
      );
    });
  });

  group('dispositivo pareado', () {
    test('sem evento ainda fica pendente', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(const Duration(minutes: 3)),
          lastEvent: null,
          now: agora,
        ),
        FarolLedState.pending,
      );
    });

    test('evento alinhado pinta de verde', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(const Duration(minutes: 3)),
          lastEvent: eventoCom('aligned'),
          now: agora,
        ),
        FarolLedState.aligned,
      );
    });

    test('evento divergente pinta de vermelho', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(const Duration(minutes: 3)),
          lastEvent: eventoCom('divergent'),
          now: agora,
        ),
        FarolLedState.divergent,
      );
    });

    test('alinhamento desconhecido cai em abstencao', () {
      // Espelha IotLastEvent.alignmentColor, cujo `default` e o amarelo.
      expect(
        farolLedStateFor(
          device: deviceVisto(const Duration(minutes: 3)),
          lastEvent: eventoCom('qualquer_outra_coisa'),
          now: agora,
        ),
        FarolLedState.abstention,
      );
    });
  });

  group('acordo com o modelo', () {
    // A tela do dispositivo pinta pelo IotLastEvent e a gaveta pinta pelo
    // FarolLedState. Sao dois caminhos para a mesma cor; este teste e o que
    // impede que um deles mude sozinho e o app passe a mostrar dois vermelhos
    // diferentes para o mesmo voto.
    for (final alignment in const ['aligned', 'divergent', 'abstention']) {
      test('$alignment: a mesma cor e o mesmo rotulo dos dois lados', () {
        final event = eventoCom(alignment);
        final state = farolLedStateFor(
          device: deviceVisto(const Duration(minutes: 3)),
          lastEvent: event,
          now: agora,
        );

        expect(state.color, event.alignmentColor);
        expect(state.label, event.alignmentLabel);
      });
    }
  });

  group('silencio do dispositivo', () {
    test('sem sinal ha mais que o limite fica offline', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(kFarolOfflineAfter + const Duration(minutes: 1)),
          lastEvent: null,
          now: agora,
        ),
        FarolLedState.offline,
      );
    });

    test('nunca visto fica offline', () {
      final nuncaVisto = IotDevice(
        deviceToken: 'a3f9c21b0000',
        status: 'linked',
        linkedAt: agora.subtract(const Duration(minutes: 1)),
        updatedAt: agora.subtract(const Duration(minutes: 1)),
        lastSeenAt: null,
      );

      expect(
        farolLedStateFor(device: nuncaVisto, lastEvent: null, now: agora),
        FarolLedState.offline,
      );
    });

    test('offline vence o evento: um LED apagado nao mostra cor', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(const Duration(days: 2)),
          lastEvent: eventoCom('divergent'),
          now: agora,
        ),
        FarolLedState.offline,
      );
    });

    test('exatamente no limite ainda conta como online', () {
      expect(
        farolLedStateFor(
          device: deviceVisto(kFarolOfflineAfter),
          lastEvent: null,
          now: agora,
        ),
        FarolLedState.pending,
      );
    });
  });
}
