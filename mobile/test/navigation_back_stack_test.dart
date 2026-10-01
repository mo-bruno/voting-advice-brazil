import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/comparison/comparison_page.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/features/weighting/weighting_page.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

class _SilentSink implements AnalyticsSink {
  const _SilentSink();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  late AnalyticsService analytics;

  setUp(() {
    analytics = AnalyticsService(sink: const _SilentSink());
    QuizSession.instance
      ..resetQuiz()
      ..theses = [
        Thesis(
          id: 1,
          title: 'Tese respondida',
          category: 'Economia',
          answer: ThesisAnswer.agree,
        ),
      ]
      ..candidates = [
        Party.fromCandidateJson({
          'id': 1,
          'name': 'Candidatura de teste',
          'party_acronym': 'PT',
        }),
      ]
      ..selectedCandidateIds = {'1'}
      ..results = const [
        CandidateResult(
          candidateId: '1',
          name: 'Candidatura de teste',
          party: 'PT',
          scorePercent: 80,
          rank: 1,
          matches: [],
          countedTheses: 1,
          answeredTheses: 1,
          comparableCategories: 1,
          documentedTheses: 1,
          documentedCategories: 1,
          rankingStatus: 'eligible',
          rankingEligible: true,
        ),
      ];
  });

  tearDown(QuizSession.instance.resetQuiz);

  testWidgets('voltar desempilha o fluxo sem retornar aos resultados', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (_) => const Scaffold(body: Text('Início do aplicativo')),
          '/weighting': (_) => WeightingPage(analytics: analytics),
          '/party-selection': (_) => PartySelectionPage(
                session: QuizSession.instance,
                analytics: analytics,
              ),
          '/results': (_) => ResultsPage(analytics: analytics),
          '/comparison': (_) => ComparisonPage(
                session: QuizSession.instance,
                analytics: analytics,
              ),
        },
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in [
      '/weighting',
      '/party-selection',
      '/results',
      '/comparison',
    ]) {
      unawaited(navigator.pushNamed<void>(route));
      await tester.pumpAndSettle();
    }

    expect(find.byType(ComparisonPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(PartySelectionPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(WeightingPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Início do aplicativo'), findsOneWidget);
    expect(find.byType(ResultsPage), findsNothing);
  });
}
