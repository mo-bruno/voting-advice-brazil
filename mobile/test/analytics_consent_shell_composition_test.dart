import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/home/home_page.dart';
import 'package:guia_eleitoral/features/home/news_session.dart';
import 'package:guia_eleitoral/features/privacy/privacy_config.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements AnalyticsConsentStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _Effects implements AnalyticsConsentEffects {
  @override
  Future<void> updateConsent({required bool granted}) async {}
}

class _NewsClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    const payload = {
      'period_start': '2026-09-23',
      'period_end': '2026-09-30',
      'period_label': 'SEMANA ATUAL',
      'total': 0,
      'articles': <Object>[],
    };
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(payload))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _SilentSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  testWidgets('pending banner leaves real Home quiz action tappable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final newsClient = _NewsClient();
    addTearDown(newsClient.close);
    final controller = AnalyticsConsentController.testOnly(
      store: _Store(),
      effects: _Effects(),
    );
    await controller.hydrate();
    addTearDown(controller.dispose);
    final news = NewsSession.testOnly(
      api: ApiClient(
        baseUrl: 'https://api.test/api/v1',
        client: newsClient,
      ),
    );
    addTearDown(news.dispose);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: const TextScaler.linear(2),
      ),
      child: MyApp(
        analyticsConsent: controller,
        privacyConfig: const PrivacyConfig(
          controllerName: 'Responsável de Teste',
          contactEmail: 'privacidade@fpolitico.com.br',
        ),
        pageBuilders: [
          (onStartQuiz) => HomePage(
                onStartQuiz: onStartQuiz,
                newsSession: news,
              ),
          (_) => const Scaffold(body: Text('acompanhar')),
          (_) => const Scaffold(body: Text('quiz')),
          (_) => const Scaffold(body: Text('comunidade')),
        ],
      ),
    ));
    await tester.pump();
    expect(find.text('REJEITAR MÉTRICAS'), findsOneWidget);
    expect(find.text('ACEITAR MÉTRICAS'), findsOneWidget);
    expect(find.text('SAIBA MAIS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Começar o quiz'));
    await tester.pump();
    expect(find.text('Começar o quiz').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('SAIBA MAIS'));
    await tester.pump();
    await tester.tap(find.text('SAIBA MAIS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('PRIVACIDADE E DADOS'), findsOneWidget);
    expect(controller.state, AnalyticsConsent.pending);
  });

  for (final page in ['intro', 'selection']) {
    testWidgets('pending banner keeps $page quiz action reachable at 200% text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = AnalyticsConsentController.testOnly(
        store: _Store(),
        effects: _Effects(),
      );
      await controller.hydrate();
      addTearDown(controller.dispose);
      final session = QuizSession.testOnly()
        ..candidates = [
          Party.fromCandidateJson({
            'id': 13,
            'name': 'Candidatura',
            'party_acronym': 'PT',
          }),
        ]
        ..selectedCandidateIds = {'13'};
      addTearDown(session.dispose);
      final analytics = AnalyticsService(sink: _SilentSink());
      final isIntro = page == 'intro';
      final action = isIntro ? 'COMEÇAR PERGUNTAS' : 'VER RESULTADOS';
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: MyApp(
          analyticsConsent: controller,
          privacyConfig: const PrivacyConfig(
            controllerName: 'Responsável de Teste',
            contactEmail: 'privacidade@fpolitico.com.br',
          ),
          pageBuilders: [
            (_) => isIntro
                ? QuizIntroPage(analytics: analytics)
                : PartySelectionPage(session: session, analytics: analytics),
            (_) => const Scaffold(body: Text('acompanhar')),
            (_) => const Scaffold(body: Text('quiz')),
            (_) => const Scaffold(body: Text('comunidade')),
          ],
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(controller.state, AnalyticsConsent.pending);
      for (final label in [
        'REJEITAR MÉTRICAS',
        'ACEITAR MÉTRICAS',
        'SAIBA MAIS',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.ensureVisible(find.text(action));
      await tester.pump();
      expect(find.text(action).hitTestable(), findsOneWidget);
      expect(controller.state, AnalyticsConsent.pending);
      expect(tester.takeException(), isNull);
    });
  }
}
