import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/farol_led_state.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/farol_status_tile.dart';

/// O bloco do Farol e o unico da gaveta que muda de cor. Cada estado precisa
/// dizer duas coisas sem que o usuario abra outra tela: o que o LED esta
/// mostrando agora e por que.
void main() {
  setUp(() {});

  final agora = DateTime.utc(2026, 3, 10, 12, 0);

  IotDevice deviceVisto(Duration atras) {
    return IotDevice(
      deviceToken: 'a3f9c21b0000',
      status: 'linked',
      linkedAt: agora.subtract(const Duration(days: 30)),
      updatedAt: agora.subtract(atras),
      lastSeenAt: agora.subtract(atras),
    );
  }

  final eventoDivergente = IotLastEvent(
    deputyName: 'Ana Vasconcelos',
    party: 'PDT',
    state: 'RS',
    vote: 'NAO',
    alignment: 'divergent',
    description: 'PL 1234/2025',
    timestampUtc: agora.subtract(const Duration(hours: 2)),
  );

  Future<void> pump(
    WidgetTester tester, {
    IotDevice? device,
    IotLastEvent? lastEvent,
    VoidCallback? onOpenDevice,
    VoidCallback? onPair,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          width: 304,
          child: FarolStatusTile(
            device: device,
            lastEvent: lastEvent,
            now: agora,
            onOpenDevice: onOpenDevice ?? () {},
            onPair: onPair ?? () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  double pulseScale(WidgetTester tester) {
    final transition = tester.widget<ScaleTransition>(
      find.byKey(const Key('farol-led-pulse')),
    );
    return transition.scale.value;
  }

  Color dotColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.byKey(const Key('farol-led-dot')),
    );
    return (container.decoration as BoxDecoration).color!;
  }

  testWidgets('sempre se identifica, em qualquer estado', (tester) async {
    await pump(tester);

    expect(find.text('MEU FAROL'), findsOneWidget);
  });

  group('com evento recente', () {
    testWidgets('mostra alinhamento, deputado e quando foi', (tester) async {
      await pump(
        tester,
        device: deviceVisto(const Duration(minutes: 3)),
        lastEvent: eventoDivergente,
      );

      expect(find.text('DIVERGENTE'), findsOneWidget);
      expect(find.text('Ana Vasconcelos'), findsOneWidget);
      expect(find.text('PDT • RS'), findsOneWidget);
      expect(find.text('há 2h'), findsOneWidget);
    });

    testWidgets('o ponto usa a cor do alinhamento', (tester) async {
      await pump(
        tester,
        device: deviceVisto(const Duration(minutes: 3)),
        lastEvent: eventoDivergente,
      );

      expect(dotColor(tester), FarolLedState.divergent.color);
    });

    testWidgets('tocar abre a tela do dispositivo', (tester) async {
      var aberto = 0;
      await pump(
        tester,
        device: deviceVisto(const Duration(minutes: 3)),
        lastEvent: eventoDivergente,
        onOpenDevice: () => aberto++,
      );

      await tester.tap(find.text('Ana Vasconcelos'));
      await tester.pump();

      expect(aberto, 1);
    });
  });

  group('pareado sem evento', () {
    testWidgets('diz que esta esperando, nao que esta vazio', (tester) async {
      await pump(tester, device: deviceVisto(const Duration(minutes: 3)));

      expect(find.text('AGUARDANDO VOTAÇÃO'), findsOneWidget);
      expect(find.text('Farol A3F9C21B'), findsOneWidget);
    });
  });

  group('pulso', () {
    testWidgets('o ponto pendente pulsa, como o LED do gadget', (tester) async {
      await pump(tester, device: deviceVisto(const Duration(minutes: 3)));

      final inicio = pulseScale(tester);
      await tester.pump(const Duration(milliseconds: 700));
      final depois = pulseScale(tester);

      expect(depois, isNot(inicio));
    });

    testWidgets('um voto nao pulsa: a cor ja e a mensagem', (tester) async {
      await pump(
        tester,
        device: deviceVisto(const Duration(minutes: 3)),
        lastEvent: eventoDivergente,
      );

      expect(find.byKey(const Key('farol-led-pulse')), findsNothing);
    });

    testWidgets('aparelho apagado nao pulsa', (tester) async {
      await pump(tester, device: deviceVisto(const Duration(days: 2)));

      expect(find.byKey(const Key('farol-led-pulse')), findsNothing);
    });
  });

  group('offline', () {
    testWidgets('diz ha quanto tempo sumiu', (tester) async {
      await pump(tester, device: deviceVisto(const Duration(days: 2)));

      expect(find.text('DISPOSITIVO OFFLINE'), findsOneWidget);
      expect(find.textContaining('há 2d'), findsOneWidget);
    });

    testWidgets('nao mostra a cor de um evento antigo', (tester) async {
      // O aparelho esta apagado; pintar de vermelho seria mentir sobre o que a
      // pessoa veria olhando para a mesa dela.
      await pump(
        tester,
        device: deviceVisto(const Duration(days: 2)),
        lastEvent: eventoDivergente,
      );

      expect(dotColor(tester), isNot(FarolLedState.divergent.color));
      expect(find.text('DIVERGENTE'), findsNothing);
    });
  });

  group('sem dispositivo', () {
    testWidgets('convida a parear em vez de sumir', (tester) async {
      await pump(tester);

      expect(find.text('PAREAR DISPOSITIVO'), findsOneWidget);
    });

    testWidgets('o botao leva ao pareamento, nao a tela do dispositivo',
        (tester) async {
      var pareou = 0;
      var abriu = 0;
      await pump(
        tester,
        onPair: () => pareou++,
        onOpenDevice: () => abriu++,
      );

      await tester.tap(find.text('PAREAR DISPOSITIVO'));
      await tester.pump();

      expect(pareou, 1);
      expect(abriu, 0);
    });
  });
}
