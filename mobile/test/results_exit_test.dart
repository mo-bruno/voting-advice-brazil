import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sair dos resultados deixou de ser o mesmo gesto que jogar o teste fora.
///
/// O botao do rodape descartava o quiz inteiro para poder navegar; quem so
/// queria sair da tela perdia o resultado junto. Agora sair e sair, e o
/// descarte acontece onde ele significa alguma coisa: ao COMECAR outro quiz.
class _SilentSink implements AnalyticsSink {
  const _SilentSink();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

/// Guarda os nomes dos eventos para as asserções de analytics.
class _SpySink implements AnalyticsSink {
  final List<String> eventos = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    eventos.add(name);
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    QuizSession.instance.resetQuiz();
  });

  const resultado = CandidateResult(
    candidateId: '1',
    name: 'Ricardo Sampaio',
    party: 'PSB',
    scorePercent: 87,
    rank: 1,
    countedTheses: 7,
    answeredTheses: 9,
    matches: [],
  );

  void comQuizRespondido() {
    QuizSession.instance.results = const [resultado];
    QuizSession.instance.theses = [
      Thesis(
        id: 1,
        title: 'Uma tese qualquer',
        category: 'Economia',
        answer: ThesisAnswer.agree,
      ),
    ];
    QuizSession.instance.selectedCandidateIds = {'1'};
  }

  Future<void> pumpResultados(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (context) => MainShell(
                initialTab: MainShell.tabFromArguments(
                  ModalRoute.of(context)?.settings.arguments,
                ),
                pageBuilders: [
                  (_) => const Scaffold(body: Text('tela-inicio')),
                  (_) => const Scaffold(body: Text('tela-acompanhar')),
                  (_) => const Scaffold(body: Text('tela-quiz')),
                  (_) => const Scaffold(body: Text('tela-comunidade')),
                ],
              ),
          '/results': (_) => const ResultsPage(),
        },
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/results');
    await tester.pumpAndSettle();
    tester.takeException();
  }

  group('saida da tela de resultados', () {
    testWidgets('oferece voltar ao inicio, nao refazer o quiz', (tester) async {
      comQuizRespondido();
      await pumpResultados(tester);

      expect(find.text('VOLTAR AO INÍCIO'), findsOneWidget);
      expect(find.text('REFAZER QUIZ'), findsNothing);
    });

    testWidgets('leva ao shell na aba Inicio', (tester) async {
      comQuizRespondido();
      await pumpResultados(tester);

      // O botao fica no fim de uma pagina longa: sem rolar ate ele o toque cai
      // no vazio e o teste passaria sem testar nada.
      await tester.ensureVisible(find.text('VOLTAR AO INÍCIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VOLTAR AO INÍCIO'));
      await tester.pumpAndSettle();

      expect(find.text('tela-inicio'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('preserva o teste realizado', (tester) async {
      // O ponto do pedido: sair da tela nao pode custar o resultado.
      comQuizRespondido();
      await pumpResultados(tester);

      // O botao fica no fim de uma pagina longa: sem rolar ate ele o toque cai
      // no vazio e o teste passaria sem testar nada.
      await tester.ensureVisible(find.text('VOLTAR AO INÍCIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VOLTAR AO INÍCIO'));
      await tester.pumpAndSettle();

      expect(QuizSession.instance.results, isNotEmpty);
      expect(QuizSession.instance.theses, isNotEmpty);
      expect(QuizSession.instance.selectedCandidateIds, isNotEmpty);
    });
  });

  group('comecar um quiz novo', () {
    Future<void> pumpIntro(WidgetTester tester, AnalyticsSink sink) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => QuizIntroPage(analytics: AnalyticsService(sink: sink)),
            '/quiz': (_) => const Scaffold(body: Text('tela do quiz')),
          },
        ),
      );
      await tester.pump();
    }

    testWidgets('descarta o teste anterior antes de comecar', (tester) async {
      // O descarte mudou de lugar, nao sumiu: e aqui que ele significa algo.
      comQuizRespondido();
      await pumpIntro(tester, const _SilentSink());

      await tester.tap(find.text('COMEÇAR PERGUNTAS'));
      await tester.pumpAndSettle();

      expect(QuizSession.instance.results, isEmpty);
      expect(QuizSession.instance.theses, isEmpty);
      expect(QuizSession.instance.selectedCandidateIds, isEmpty);
      expect(find.text('tela do quiz'), findsOneWidget);
    });

    testWidgets('marca o inicio do novo quiz depois de limpar', (tester) async {
      // `resetQuiz` zera `quizStartedAt`; limpar depois de marcar apagaria a
      // marcacao e a duracao do quiz sairia errada.
      comQuizRespondido();
      await pumpIntro(tester, const _SilentSink());

      await tester.tap(find.text('COMEÇAR PERGUNTAS'));
      await tester.pumpAndSettle();

      expect(QuizSession.instance.quizStartedAt, isNotNull);
    });

    testWidgets('so conta como refeito quando havia um teste antes', (
      tester,
    ) async {
      final espia = _SpySink();
      await pumpIntro(tester, espia);

      await tester.tap(find.text('COMEÇAR PERGUNTAS'));
      await tester.pumpAndSettle();

      expect(espia.eventos, contains('quiz_started'));
      expect(espia.eventos, isNot(contains('quiz_restarted')));
    });

    testWidgets('conta como refeito quando ja havia um resultado', (
      tester,
    ) async {
      final espia = _SpySink();
      comQuizRespondido();
      await pumpIntro(tester, espia);

      await tester.tap(find.text('COMEÇAR PERGUNTAS'));
      await tester.pumpAndSettle();

      expect(espia.eventos, contains('quiz_restarted'));
    });
  });
}
