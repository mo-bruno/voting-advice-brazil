import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A gaveta le tres sessions singleton e nao dispara requisicao nenhuma: ela
/// mostra o que o app ja carregou. Estes testes cobrem a montagem e a fiacao —
/// os estados de cada bloco tem arquivo proprio.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'farol_politico_device_id': 'a3f9c21b-0000-4000-8000-000000000000',
    });
    // Singletons vazam entre testes; cada um comeca do zero.
    IotDeviceSession.instance.device = null;
    IotDeviceSession.instance.lastEvent = null;
    PoliticalActorSession.instance.followedActor = null;
    QuizSession.instance.results = [];
    QuizSession.instance.selectedCandidateIds = {};
  });

  final actor = PoliticalActor(
    id: 7,
    source: 'camara',
    sourceId: '204554',
    displayName: 'Ana Vasconcelos',
    party: 'PDT',
    state: 'RS',
    role: 'federal_deputy',
    status: 'active',
    photoUrl: null,
    sourceUrl: null,
    lastIndexedAt: DateTime.utc(2026, 3, 1),
  );

  /// Esperar a tela ficar parada nao serve aqui: o ponto do estado pendente
  /// pulsa para sempre, como o LED do gadget, e a espera nunca terminaria.
  /// Bombear um intervalo fixo maior que a abertura da gaveta (246ms) e que a
  /// transicao de rota (300ms) da o mesmo resultado sem essa dependencia.
  Future<void> settleDrawer(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openDrawer(
    WidgetTester tester, {
    bool iotEnabled = true,
  }) async {
    // Tela de celular de verdade. Na superficie padrao (800x600) o terceiro
    // bloco cai abaixo da dobra e a ListView nem chega a construi-lo — a
    // gaveta rola, e isso e esperado, mas nao e o que estes testes medem.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (_) => Scaffold(
                drawer: AppDrawer(iotEnabled: iotEnabled),
                body: const SizedBox(),
              ),
          '/iot-device': (_) =>
              const Scaffold(body: Text('tela do dispositivo')),
          '/iot-pairing': (_) =>
              const Scaffold(body: Text('tela de pareamento')),
          '/results': (_) => const Scaffold(body: Text('comparação aberta')),
        },
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await settleDrawer(tester);
  }

  testWidgets('monta os quatro blocos e o rodape', (tester) async {
    await openDrawer(tester);

    expect(find.text('FAROL\nPOLÍTICO'), findsOneWidget);
    expect(find.text('MEU FAROL'), findsOneWidget);
    expect(find.text('ACOMPANHANDO'), findsOneWidget);
    expect(find.text('COMPARAÇÃO DOS PLANOS'), findsOneWidget);
    expect(find.text('SOBRE'), findsOneWidget);
  });

  testWidgets('nao repete os destinos que vivem na barra inferior', (
    tester,
  ) async {
    // Duplica-los aqui empilharia uma segunda copia da tela sobre o shell.
    await openDrawer(tester);

    expect(find.text('Início'), findsNothing);
    expect(find.text('Responder quiz'), findsNothing);
    expect(find.text('Acompanhar político'), findsNothing);
    expect(find.text('Comunidade'), findsNothing);
  });

  testWidgets('mostra o que as sessions ja tinham em memoria', (tester) async {
    PoliticalActorSession.instance.followedActor = actor;
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Ricardo Sampaio',
        party: 'PSB',
        scorePercent: 87,
        rank: 1,
        countedTheses: 7,
        answeredTheses: 9,
        matches: [],
      ),
    ];

    await openDrawer(tester);

    expect(find.text('Ana Vasconcelos'), findsOneWidget);
    expect(find.text('Ricardo Sampaio'), findsNothing);
    expect(find.text('87%'), findsNothing);
    expect(find.text('Ver resultados'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver resultados'));
    await tester.tap(find.text('Ver resultados'));
    await settleDrawer(tester);
    expect(find.text('comparação aberta'), findsOneWidget);
  });

  testWidgets('empate de afinidade não escolhe vencedor pela ordem da lista',
      (tester) async {
    QuizSession.instance.results = List.generate(
        9,
        (index) => CandidateResult(
              candidateId: '${index + 1}',
              name: 'Candidatura ${index + 1}',
              party: 'DC',
              scorePercent: 50,
              rank: 1,
              countedTheses: index % 7 + 1,
              answeredTheses: 9,
              matches: const [],
            ));
    await openDrawer(tester);
    expect(find.text('EMPATE NA MAIOR AFINIDADE'), findsNothing);
    expect(find.textContaining('9 candidaturas com 50.0%'), findsNothing);
    expect(find.text('Ver resultados'), findsOneWidget);
    expect(find.text('Candidatura 1'), findsNothing);
  });

  testWidgets('o rodape identifica o dispositivo anonimo', (tester) async {
    await openDrawer(tester);

    expect(find.textContaining('ID A3F9C21B'), findsOneWidget);
  });

  testWidgets('sem dispositivo, o bloco do Farol leva ao pareamento', (
    tester,
  ) async {
    await openDrawer(tester);

    await tester.tap(find.text('PAREAR DISPOSITIVO'));
    await settleDrawer(tester);

    expect(find.text('tela de pareamento'), findsOneWidget);
  });

  testWidgets('com dispositivo, o bloco do Farol leva a tela dele', (
    tester,
  ) async {
    final agora = DateTime.now();
    IotDeviceSession.instance.device = IotDevice(
      deviceToken: 'a3f9c21b0000',
      status: 'linked',
      linkedAt: agora.subtract(const Duration(days: 1)),
      updatedAt: agora,
      lastSeenAt: agora,
    );

    await openDrawer(tester);

    await tester.tap(find.text('AGUARDANDO VOTAÇÃO'));
    await settleDrawer(tester);

    expect(find.text('tela do dispositivo'), findsOneWidget);
  });

  testWidgets('privacidade explica o identificador sem sair da gaveta', (
    tester,
  ) async {
    await openDrawer(tester);

    await tester.tap(find.text('PRIVACIDADE'));
    await settleDrawer(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('sobre e privacidade descrevem o produto atual sem hardware',
      (tester) async {
    await openDrawer(tester, iotEnabled: false);

    await tester.tap(find.text('SOBRE'));
    await settleDrawer(tester);

    expect(find.textContaining('propostas publicadas'), findsOneWidget);
    expect(find.textContaining('não alteram a comparação do quiz'),
        findsOneWidget);
    expect(find.textContaining('eleições de 2026'), findsOneWidget);
    expect(find.textContaining('eleições de 2022'), findsNothing);
    expect(find.textContaining('com os votos que registraram'), findsNothing);

    await tester.tap(find.text('FECHAR'));
    await settleDrawer(tester);
    await tester.tap(find.text('PRIVACIDADE'));
    await settleDrawer(tester);

    expect(find.textContaining('salvar respostas do quiz'), findsOneWidget);
    expect(find.textContaining('participar da comunidade'), findsOneWidget);
    expect(
        find.textContaining('não aparece para outras pessoas'), findsOneWidget);
    expect(find.textContaining('Farol físico'), findsNothing);
    expect(find.textContaining('não saem do aparelho'), findsNothing);
  });
}
