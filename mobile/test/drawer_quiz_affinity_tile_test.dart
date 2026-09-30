import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/quiz_affinity_tile.dart';

void main() {
  setUp(() {});

  CandidateResult resultado(double score) {
    return CandidateResult(
      candidateId: '1',
      name: 'Ricardo Sampaio',
      party: 'PSB',
      scorePercent: score,
      rank: 1,
      countedTheses: 7,
      answeredTheses: 9,
      matches: const [],
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    CandidateResult? top,
    VoidCallback? onOpenResults,
    VoidCallback? onStartQuiz,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 304,
            child: QuizAffinityTile(
              hasResults: top != null,
              onOpenResults: onOpenResults ?? () {},
              onStartQuiz: onStartQuiz ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sempre se identifica, com ou sem resultado', (tester) async {
    await pump(tester);

    expect(find.text('COMPARAÇÃO DOS PLANOS'), findsOneWidget);
  });

  group('com resultado', () {
    testWidgets('oferece resultados sem apresentar uma candidatura vencedora',
        (tester) async {
      await pump(tester, top: resultado(87.0));

      expect(find.text('Ricardo Sampaio'), findsNothing);
      expect(find.text('87%'), findsNothing);
      expect(find.text('SUA MAIOR AFINIDADE'), findsNothing);
      expect(find.text('Ver resultados'), findsOneWidget);
    });

    testWidgets('tocar abre os resultados completos', (tester) async {
      var abriu = 0;
      await pump(tester, top: resultado(87.0), onOpenResults: () => abriu++);

      await tester.tap(find.text('Ver resultados'));
      await tester.pump();

      expect(abriu, 1);
    });
  });

  group('sem resultado', () {
    testWidgets('sem evidência não anuncia maior afinidade ou zero por cento', (
      tester,
    ) async {
      await pump(
        tester,
        top: const CandidateResult(
          candidateId: '2',
          name: 'Sem evidência',
          party: 'DC',
          scorePercent: 0,
          rank: 0,
          countedTheses: 0,
          answeredTheses: 9,
          matches: [],
        ),
      );
      expect(find.text('SUA MAIOR AFINIDADE'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.text('Ver resultados'), findsOneWidget);
    });

    testWidgets('convida a fazer o quiz em vez de sumir', (tester) async {
      await pump(tester);

      expect(find.text('Você ainda não fez o quiz.'), findsOneWidget);
      expect(find.text('Descobrir minha afinidade'), findsOneWidget);
    });

    testWidgets('o convite leva ao quiz, nao aos resultados', (tester) async {
      var comecou = 0;
      var abriu = 0;
      await pump(
        tester,
        onStartQuiz: () => comecou++,
        onOpenResults: () => abriu++,
      );

      await tester.tap(find.text('Descobrir minha afinidade'));
      await tester.pump();

      expect(comecou, 1);
      expect(abriu, 0);
    });
  });
}
