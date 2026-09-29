import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

void main() {
  setUp(() {
    QuizSession.instance.resetQuiz();
  });

  tearDown(() => QuizSession.instance.resetQuiz());

  testWidgets('compartilha o resultado visível e preserva o quiz ao voltar',
      (tester) async {
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
      ),
    ];
    QuizSession.instance.selectedCandidateIds = {'2', '3'};
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const ResultsPage(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Compartilhar resultado'), findsOneWidget);
    await tester.tap(find.text('Compartilhar resultado'));
    await tester.pump();
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.text('Preparando imagem…').evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();

    expect(find.text('Meu resultado em uma imagem.'), findsOneWidget);
    expect(find.text('Candidata B'), findsOneWidget);
    expect(find.text('Candidata A'), findsNothing);
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
