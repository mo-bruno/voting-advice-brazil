import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/quiz_affinity_tile.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  CandidateResult resultado(double score) {
    return CandidateResult(
      candidateId: '1',
      name: 'Ricardo Sampaio',
      party: 'PSB',
      scorePercent: score,
      rank: 1,
      matches: const [],
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    CandidateResult? top,
    VoidCallback? onOpenResults,
    VoidCallback? onStartQuiz,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          width: 304,
          child: QuizAffinityTile(
            top: top,
            onOpenResults: onOpenResults ?? () {},
            onStartQuiz: onStartQuiz ?? () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('sempre se identifica, com ou sem resultado', (tester) async {
    await pump(tester);

    expect(find.text('SUA MAIOR AFINIDADE'), findsOneWidget);
  });

  group('com resultado', () {
    testWidgets('mostra quem ficou em primeiro e o quanto', (tester) async {
      await pump(tester, top: resultado(87.0));

      expect(find.text('Ricardo Sampaio'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
    });

    testWidgets('arredonda a fracao em vez de despejar decimais',
        (tester) async {
      await pump(tester, top: resultado(86.7));

      expect(find.text('87%'), findsOneWidget);
    });

    testWidgets('tocar abre os resultados completos', (tester) async {
      var abriu = 0;
      await pump(
        tester,
        top: resultado(87.0),
        onOpenResults: () => abriu++,
      );

      await tester.tap(find.text('Ricardo Sampaio'));
      await tester.pump();

      expect(abriu, 1);
    });
  });

  group('sem resultado', () {
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
