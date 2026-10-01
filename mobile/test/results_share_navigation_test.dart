import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_navigation.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_page.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

import 'helpers/analytics_test_support.dart';

void main() {
  setUp(() {
    QuizSession.instance.resetQuiz();
  });

  tearDown(() => QuizSession.instance.resetQuiz());

  testWidgets('compartilha o resultado visível e preserva o quiz ao voltar',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final analytics = AnalyticsService(sink: sink);
    await tester.runAsync(ResultShareCard.loadFonts);
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Candidata A',
        party: 'PSB',
        scorePercent: 90,
        rank: 1,
        matches: [],
        countedTheses: 10,
        answeredTheses: 30,
        comparableCategories: 5,
        rankingStatus: 'eligible',
        rankingEligible: true,
      ),
      CandidateResult(
        candidateId: '2',
        name: 'Candidata B',
        party: 'PSD',
        scorePercent: 72.5,
        rank: 2,
        matches: [],
        countedTheses: 10,
        answeredTheses: 30,
        comparableCategories: 5,
        rankingStatus: 'eligible',
        rankingEligible: true,
      ),
      CandidateResult(
        candidateId: '3',
        name: 'Candidata C',
        party: 'PSB',
        scorePercent: 0,
        rank: 3,
        matches: [],
        countedTheses: 10,
        answeredTheses: 30,
        comparableCategories: 5,
        rankingStatus: 'eligible',
        rankingEligible: true,
      ),
    ];
    QuizSession.instance.selectedCandidateIds = {'2', '3'};
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ResultsPage(analytics: analytics),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Compartilhar resultado'), findsOneWidget);
    await tester.tap(find.text('Compartilhar resultado'));
    await tester.pump();
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (named(sink.calls, 'operation_result').any(
        (call) => call.parameters?['operation'] == 'share_render',
      )) {
        break;
      }
    }
    await tester.pumpAndSettle();

    expect(find.text('Meu resultado em uma imagem.'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(ResultSharePage)))
          ?.settings
          .name,
      resultShareRoute,
    );
    expect(find.text('Candidata B'), findsOneWidget);
    expect(find.text('Candidata A'), findsNothing);
    final render = named(sink.calls, 'operation_result').singleWhere(
      (call) => call.parameters?['operation'] == 'share_render',
    );
    expect(render.parameters, containsPair('outcome', 'success'));
    expect(render.parameters, containsPair('trigger', 'initial'));
    expect(named(sink.calls, 'screen_viewed'), isEmpty,
        reason: 'screen_viewed pertence somente ao observer de navegação');
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    expect(find.text('Candidata C'), findsOneWidget);
    expect(find.text('Candidata A'), findsNothing);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsPage), findsOneWidget);
    expect(QuizSession.instance.results, hasLength(3));
    expect(QuizSession.instance.selectedCandidateIds, {'2', '3'});
  });

  testWidgets('mostra compartilhar antes de um ranking longo', (tester) async {
    QuizSession.instance.results = List.generate(
      10,
      (index) => CandidateResult(
        candidateId: '${index + 1}',
        name: 'Candidatura ${index + 1}',
        party: 'PARTIDO',
        scorePercent: 90 - index.toDouble(),
        rank: index + 1,
        matches: const [],
        countedTheses: 10,
        answeredTheses: 30,
        comparableCategories: 5,
        rankingStatus: 'eligible',
        rankingEligible: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const ResultsPage()),
    );
    await tester.pumpAndSettle();

    final share = find.ancestor(
      of: find.text('Compartilhar resultado'),
      matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
    );
    final firstResult = find.text('Candidatura 1');
    final screenHeight = tester.getSize(find.byType(Scaffold)).height;

    expect(share, findsOneWidget);
    expect(tester.getBottomRight(share).dy, lessThan(screenHeight));
    expect(share.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(share).dy,
      lessThan(tester.getTopLeft(firstResult).dy),
    );
  });

  testWidgets('não compartilha quando os resultados não têm base comparável',
      (tester) async {
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Candidata sem base',
        party: 'PSB',
        scorePercent: 0,
        rank: 1,
        matches: [],
        countedTheses: 0,
        answeredTheses: 30,
        rankingStatus: 'insufficient_documented_coverage',
        rankingEligible: false,
      )
    ];
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const ResultsPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Candidata sem base'), findsOneWidget);
    expect(find.text('Compartilhar resultado'), findsNothing);
  });

  testWidgets('não oferece compartilhar antes de calcular um resultado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const ResultsPage(),
    ));
    expect(find.text('Compartilhar resultado'), findsNothing);
  });
}
