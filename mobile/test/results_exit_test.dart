import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_controller.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_page.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/features/weighting/weighting_page.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/analytics_test_support.dart';

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

  List<Thesis> tesesEmAndamento() => [
        Thesis(
          id: 101,
          title: 'Tese 1',
          category: 'Economia',
          answer: ThesisAnswer.agree,
        ),
        Thesis(
          id: 102,
          title: 'Tese 2',
          category: 'Economia',
          answer: ThesisAnswer.neutral,
        ),
        Thesis(
          id: 103,
          title: 'Tese 3',
          category: 'Economia',
          answer: ThesisAnswer.disagree,
        ),
        Thesis(
          id: 104,
          title: 'Tese 4',
          category: 'Economia',
          answer: ThesisAnswer.skipped,
        ),
        Thesis(id: 105, title: 'Tese 5', category: 'Economia'),
      ];

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

    testWidgets('registra restart generico antes de limpar um fluxo incompleto',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      QuizSession.instance
        ..theses = tesesEmAndamento()
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 2)),
        );
      await pumpIntro(tester, sink);

      await tester.tap(find.text('COMEÇAR PERGUNTAS'));
      await tester.pumpAndSettle();

      final abandoned = lastNamed(sink.calls, 'quiz_abandoned');
      expect(abandoned.parameters, {
        'stage': 'questions',
        'reason': 'restart',
        'total_answered': 3,
        'total_skipped': 1,
        'duration_ms': isA<int>(),
      });
      expect(
        abandoned.parameters!.values.whereType<String>(),
        everyElement(
          isNot(anyOf('agree', 'neutral', 'disagree', '101')),
        ),
      );
    });
  });

  group('abandono do funil', () {
    Future<void> pumpQuizRoute(
      WidgetTester tester,
      RecordingAnalyticsSink sink,
    ) async {
      final session = QuizSession.testOnly()
        ..theses = tesesEmAndamento()
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 2)),
        );
      addTearDown(session.dispose);
      final controller = QuizController(
        session: session,
        analytics: AnalyticsService(sink: sink),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => const Scaffold(body: Text('origem')),
            '/quiz': (_) => QuizPage(
                  iotEnabled: false,
                  controller: controller,
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/quiz');
      await tester.pumpAndSettle();
    }

    void expectBackAbandonment(
      RecordingAnalyticsSink sink,
      String stage,
    ) {
      final events = named(sink.calls, 'quiz_abandoned');
      expect(events, hasLength(1));
      expect(events.single.parameters, {
        'stage': stage,
        'reason': 'back',
        'total_answered': 3,
        'total_skipped': 1,
        'duration_ms': isA<int>(),
      });
    }

    testWidgets('saida explicita das perguntas registra uma vez sem bloquear',
        (tester) async {
      final blocker = Completer<void>();
      final sink = RecordingAnalyticsSink(block: blocker.future);
      await pumpQuizRoute(tester, sink);

      await tester.tap(find.byTooltip('Sair do quiz'));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expectBackAbandonment(sink, 'questions');
      blocker.complete();
    });

    testWidgets('voltar do navegador nas perguntas registra uma vez',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpQuizRoute(tester, sink);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
      expectBackAbandonment(sink, 'questions');
    });

    testWidgets('voltar da ponderacao registra o estagio correto',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      final session = QuizSession.testOnly()
        ..theses = tesesEmAndamento()
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 2)),
        );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => const Scaffold(body: Text('perguntas')),
            '/weighting': (_) => WeightingPage(
                  session: session,
                  analytics: AnalyticsService(sink: sink),
                ),
          },
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/weighting');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Voltar às perguntas'));
      await tester.pumpAndSettle();

      expectBackAbandonment(sink, 'weighting');
    });

    testWidgets('voltar da selecao registra o estagio correto', (tester) async {
      final sink = RecordingAnalyticsSink();
      final session = QuizSession.testOnly()
        ..theses = tesesEmAndamento()
        ..candidates = [
          Party.fromCandidateJson({
            'id': 88,
            'name': 'Candidatura de teste',
            'party_acronym': 'ABC',
          }),
        ]
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 2)),
        );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => const Scaffold(body: Text('ponderacao')),
            '/party': (_) => PartySelectionPage(
                  session: session,
                  analytics: AnalyticsService(sink: sink),
                ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/party');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Voltar à ponderação'));
      await tester.pumpAndSettle();

      expectBackAbandonment(sink, 'candidate_selection');
    });

    testWidgets(
        'perguntas voltam a ser abandonaveis apos retornar da ponderacao',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      final session = QuizSession.testOnly()
        ..theses = [Thesis(id: 1, title: 'Tese única', category: 'Economia')]
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 1)),
        );
      addTearDown(session.dispose);
      final controller = QuizController(
        session: session,
        analytics: AnalyticsService(sink: sink),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => const Scaffold(body: Text('origem')),
            '/quiz': (_) => QuizPage(
                  iotEnabled: false,
                  controller: controller,
                ),
            '/weighting': (_) => const Scaffold(body: Text('ponderacao')),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/quiz');
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONCORDO'));
      await tester.pumpAndSettle();
      expect(find.text('ponderacao'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sair do quiz'));
      await tester.pumpAndSettle();

      final abandoned = named(sink.calls, 'quiz_abandoned');
      expect(abandoned, hasLength(1));
      expect(abandoned.single.parameters?['stage'], 'questions');
      expect(abandoned.single.parameters?['reason'], 'back');
    });

    testWidgets('ponderacao volta a ser abandonavel apos retorno da selecao',
        (tester) async {
      final sink = RecordingAnalyticsSink();
      final session = QuizSession.testOnly()
        ..theses = tesesEmAndamento()
        ..markQuizStarted(
          DateTime.now().subtract(const Duration(seconds: 2)),
        );
      for (final thesis in session.theses) {
        thesis.answer = ThesisAnswer.agree;
      }
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          routes: {
            '/': (_) => const Scaffold(body: Text('perguntas')),
            '/weighting': (_) => WeightingPage(
                  session: session,
                  analytics: AnalyticsService(sink: sink),
                ),
            '/party-selection': (_) => const Scaffold(body: Text('selecao')),
          },
        ),
      );
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pushNamed('/weighting');
      await tester.pumpAndSettle();

      await tester.tap(find.text('CONTINUAR PARA SELEÇÃO'));
      await tester.pumpAndSettle();
      expect(find.text('selecao'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar às perguntas'));
      await tester.pumpAndSettle();

      final abandoned = named(sink.calls, 'quiz_abandoned');
      expect(abandoned, hasLength(1));
      expect(abandoned.single.parameters?['stage'], 'weighting');
      expect(abandoned.single.parameters?['reason'], 'back');
    });
  });
}
