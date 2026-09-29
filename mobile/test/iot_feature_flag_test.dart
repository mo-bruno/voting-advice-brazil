import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/core/features/feature_flags.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/quiz/quiz_controller.dart';
import 'package:guia_eleitoral/features/quiz/quiz_page.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:guia_eleitoral/shared/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PulseApiClient extends ApiClient {
  _PulseApiClient() : super(baseUrl: 'https://example.test');

  String? pulseAnswer;
  int? pulseCurrent;
  int? pulseTotal;

  @override
  Future<void> sendQuizPulse({
    required String anonymousId,
    required String answer,
    required int current,
    required int total,
  }) async {
    pulseAnswer = answer;
    pulseCurrent = current;
    pulseTotal = total;
  }
}

class _DeviceIdentityStore extends DeviceIdentityStore {
  @override
  Future<String> getOrCreateDeviceId() async => 'anon-1';
}

class _SilentAnalyticsSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

QuizController _quizController() {
  final session = QuizSession.testOnly();
  session.theses = [
    Thesis(id: 1, title: 'Primeira tese', category: 'Teste'),
    Thesis(id: 2, title: 'Segunda tese', category: 'Teste'),
  ];
  return QuizController(
    session: session,
    analytics: AnalyticsService(sink: _SilentAnalyticsSink()),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  test('a configuração de ambiente desativa IoT por padrão', () {
    expect(FeatureFlags.environment.iotEnabled, isFalse);
    expect(FeatureFlags.environment.politicianFollowEnabled, isFalse);
  });

  testWidgets('rotas IoT somem quando a funcionalidade está desativada',
      (tester) async {
    await tester.pumpWidget(
      const MyApp(featureFlags: FeatureFlags(iotEnabled: false)),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.routes!.containsKey('/iot-device'), isFalse);
    expect(app.routes!.containsKey('/iot-pairing'), isFalse);
    expect(app.routes!.containsKey('/political-actor-profile'), isFalse);
  });

  testWidgets('gaveta esconde todos os controles de dispositivo físico',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const AppDrawer(
          iotEnabled: false,
          politicianFollowEnabled: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('CONECTAR FAROL'), findsNothing);
    expect(find.textContaining('Farol conectado'), findsNothing);
    expect(find.text('MEU FAROL'), findsNothing);
    expect(find.text('ACOMPANHANDO'), findsOneWidget);
    expect(find.text('COMPARAÇÃO DOS PLANOS'), findsOneWidget);
  });

  testWidgets('rotas IoT continuam disponíveis quando habilitadas',
      (tester) async {
    await tester.pumpWidget(
      const MyApp(featureFlags: FeatureFlags(iotEnabled: true)),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.routes!.containsKey('/iot-device'), isTrue);
    expect(app.routes!.containsKey('/iot-pairing'), isTrue);
  });

  testWidgets('perfil político volta às rotas quando a flag é habilitada',
      (tester) async {
    await tester.pumpWidget(
      const MyApp(
        featureFlags: FeatureFlags(
          iotEnabled: false,
          politicianFollowEnabled: true,
        ),
      ),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.routes!.containsKey('/political-actor-profile'), isTrue);
  });

  testWidgets('responder não envia pulso IoT quando desativado',
      (tester) async {
    final api = _PulseApiClient();
    final iotSession = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: _DeviceIdentityStore(),
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: QuizPage(
        iotEnabled: false,
        controller: _quizController(),
        iotSession: iotSession,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONCORDO'));
    await tester.pumpAndSettle();

    expect(api.pulseAnswer, isNull);
  });

  testWidgets('responder envia pulso IoT quando habilitado', (tester) async {
    final api = _PulseApiClient();
    final iotSession = IotDeviceSession.testOnly(
      api: api,
      deviceIdentityStore: _DeviceIdentityStore(),
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: QuizPage(
        iotEnabled: true,
        controller: _quizController(),
        iotSession: iotSession,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONCORDO'));
    await tester.pumpAndSettle();

    expect(api.pulseAnswer, 'agree');
    expect(api.pulseCurrent, 1);
    expect(api.pulseTotal, 2);
  });
}
