import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/comparison/comparison_page.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/results/results_page.dart';
import 'package:guia_eleitoral/features/weighting/weighting_page.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _Api extends ApiClient {
  ApiException? submitError;
  ApiException? justificationError;
  List<CandidateResult> submitResults = [];
  List<Party> candidates = [];
  List<CandidateJustification>? justifications;

  @override
  Future<List<CandidateResult>> submitQuiz(
    List<Thesis> theses, {
    String? deviceId,
    Set<String> candidateIds = const {},
  }) async {
    if (submitError != null) throw submitError!;
    return submitResults;
  }

  @override
  Future<List<Party>> fetchCandidates() async => candidates;

  @override
  Future<List<CandidateJustification>> fetchCandidateJustifications(
    String candidateId,
  ) async {
    if (justificationError != null) throw justificationError!;
    return justifications ??
        const [
          CandidateJustification(
            thesisId: 1,
            thesisText: 'A tese comparada',
            theme: 'economia',
            themeName: 'Economia',
            position: 'concordo',
            justification: 'O plano propõe a medida.',
            quote: 'Trecho verificável',
            sourceRef: 'Documento oficial, páginas 4 e 8',
            sourceUrl: 'https://example.test/plano.pdf',
          ),
          CandidateJustification(
            thesisId: 2,
            thesisText: 'A tese condicional',
            theme: 'economia',
            themeName: 'Economia',
            position: 'sem_posicao',
            analyticalPosition: 'CONDICIONAL_OU_MISTA',
            justification: 'O plano sustenta a medida somente sob condições.',
          ),
        ];
  }
}

void main() {
  late AnalyticsService analytics;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuizSession.instance.resetQuiz();
    analytics = AnalyticsService(sink: _SilentSink());
  });
  tearDown(() => QuizSession.instance.resetQuiz());

  List<Thesis> answers(int count) => List.generate(
        5,
        (i) => Thesis(
          id: i + 1,
          title: 'Tese ${i + 1}',
          category: 'Economia',
          answer: i < count ? ThesisAnswer.agree : ThesisAnswer.skipped,
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Map<String, WidgetBuilder> routes = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: page, routes: routes),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('intro explains the scope without exposing process details',
      (tester) async {
    await pump(tester, QuizIntroPage(analytics: analytics));
    expect(find.textContaining('20 teses'), findsOneWidget);
    expect(find.textContaining('13 planos'), findsOneWidget);
    expect(find.textContaining('fase beta'), findsOneWidget);
    expect(find.textContaining('por IA'), findsNothing);
    expect(find.textContaining('validação humana'), findsNothing);
    expect(find.textContaining('base comparável suficiente'), findsOneWidget);
    expect(find.textContaining('70 formulações'), findsNothing);
    expect(find.textContaining('30 teses'), findsNothing);
    expect(
        find.textContaining('não é uma recomendação de voto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero comparable answers never produces a top affinity', (
    tester,
  ) async {
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Sem evidência',
        party: 'DC',
        scorePercent: 0,
        rank: 0,
        countedTheses: 0,
        answeredTheses: 9,
        matches: [],
      ),
    ];
    await pump(tester, ResultsPage(analytics: analytics));
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('Fora do ranking desta edição'), findsOneWidget);
    expect(find.text('0 de 9 respostas comparáveis · 0 categorias'),
        findsOneWidget);
    expect(find.text('FORA DO RANKING DESTA EDIÇÃO BETA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('base insuficiente never becomes a zero affinity percent', (
    tester,
  ) async {
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Posições divergentes',
        party: 'DC',
        scorePercent: 0,
        rank: 1,
        countedTheses: 2,
        answeredTheses: 9,
        comparableCategories: 2,
        documentedTheses: 2,
        documentedCategories: 2,
        rankingStatus: 'insufficient_documented_coverage',
        rankingEligible: false,
        matches: [],
      ),
    ];
    await pump(tester, ResultsPage(analytics: analytics));
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('Fora do ranking desta edição'), findsOneWidget);
    expect(find.text('2 de 9 respostas comparáveis · 2 categorias'),
        findsOneWidget);
    expect(find.text('FORA DO RANKING DESTA EDIÇÃO BETA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equal ranks share the same placement without percentages', (
    tester,
  ) async {
    QuizSession.instance.results = List.generate(
      9,
      (index) => CandidateResult(
        candidateId: '${index + 1}',
        name: 'Candidatura ${index + 1}',
        party: 'DC',
        scorePercent: 50,
        rank: 1,
        countedTheses: 5 + index % 3,
        answeredTheses: 9,
        comparableCategories: 4,
        documentedTheses: 8,
        documentedCategories: 6,
        rankingStatus: 'eligible',
        rankingEligible: true,
        matches: const [],
      ),
    );
    await pump(tester, ResultsPage(analytics: analytics));
    expect(find.text('EMPATE NA MAIOR AFINIDADE'), findsNothing);
    expect(find.text('1º lugar'), findsNWidgets(9));
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('MAIOR AFINIDADE'), findsNothing);
    expect(QuizSession.instance.topAffinityResults, hasLength(9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('results show ranking, coverage and keep comparison details', (
    tester,
  ) async {
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: '1',
        name: 'Zilda',
        party: 'DC',
        scorePercent: 100,
        rank: 1,
        countedTheses: 9,
        answeredTheses: 30,
        comparableCategories: 6,
        rankingEligible: true,
        matches: [],
      ),
      CandidateResult(
        candidateId: '2',
        name: 'Ana',
        party: 'PT',
        scorePercent: 75,
        rank: 2,
        countedTheses: 8,
        answeredTheses: 9,
        comparableCategories: 4,
        rankingEligible: true,
        matches: [],
      ),
      CandidateResult(
        candidateId: '3',
        name: 'Maria',
        party: 'DC',
        scorePercent: 0,
        rank: 0,
        countedTheses: 0,
        answeredTheses: 9,
        comparableCategories: 0,
        rankingEligible: false,
        matches: [],
      ),
    ];
    await pump(tester, ResultsPage(analytics: analytics), routes: {
      '/comparison': (_) =>
          const Scaffold(body: Text('Detalhes da comparação')),
    });

    expect(find.text('MAIOR AFINIDADE'), findsNothing);
    expect(find.text('1º lugar'), findsOneWidget);
    expect(find.text('2º lugar'), findsOneWidget);
    expect(find.text('Fora do ranking desta edição'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('respostas comparáveis'), findsNWidgets(3));
    expect(find.textContaining('os percentuais não formam um ranking'),
        findsNothing);
    expect(find.text('CANDIDATURAS EM ORDEM ALFABÉTICA'), findsNothing);
    expect(find.text('PT'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Zilda')).dy,
        lessThan(tester.getTopLeft(find.text('Ana')).dy));
    expect(tester.getTopLeft(find.text('Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Maria')).dy));
    expect(QuizSession.instance.results.first.candidateId, '1');
    await tester.ensureVisible(find.text('COMPARAR RESPOSTAS'));
    await tester.tap(find.text('COMPARAR RESPOSTAS'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da comparação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'results sort selected candidates by rank with ineligible candidates last',
      (
    tester,
  ) async {
    QuizSession.instance.results = const [
      CandidateResult(
        candidateId: 'hidden',
        name: 'Candidatura não selecionada',
        party: 'DC',
        scorePercent: 100,
        rank: 1,
        rankingEligible: true,
        countedTheses: 9,
        answeredTheses: 30,
        matches: [],
      ),
      CandidateResult(
        candidateId: '1',
        name: 'Aline',
        party: 'DC',
        scorePercent: 0,
        rank: 0,
        rankingEligible: false,
        countedTheses: 0,
        answeredTheses: 30,
        matches: [],
      ),
      CandidateResult(
        candidateId: '2',
        name: 'Zélia',
        party: 'DC',
        scorePercent: 0,
        rank: 4,
        rankingEligible: true,
        countedTheses: 9,
        answeredTheses: 30,
        matches: [],
      ),
      CandidateResult(
        candidateId: '3',
        name: 'Bruno',
        party: 'DC',
        scorePercent: 75,
        rank: 2,
        rankingEligible: true,
        countedTheses: 8,
        answeredTheses: 30,
        matches: [],
      ),
      CandidateResult(
        candidateId: '4',
        name: 'Dária',
        party: 'DC',
        scorePercent: 100,
        rank: 1,
        rankingEligible: true,
        countedTheses: 9,
        answeredTheses: 30,
        matches: [],
      ),
      CandidateResult(
        candidateId: '5',
        name: 'Ana',
        party: 'DC',
        scorePercent: 75,
        rank: 0,
        rankingEligible: false,
        countedTheses: 4,
        answeredTheses: 30,
        matches: [],
      ),
    ];
    QuizSession.instance.selectedCandidateIds = {'1', '2', '3', '4', '5'};
    final originalResults = List.of(QuizSession.instance.results);

    await pump(tester, ResultsPage(analytics: analytics));

    const expectedOrder = ['Dária', 'Bruno', 'Zélia', 'Aline', 'Ana'];
    for (var i = 1; i < expectedOrder.length; i++) {
      expect(tester.getTopLeft(find.text(expectedOrder[i - 1])).dy,
          lessThan(tester.getTopLeft(find.text(expectedOrder[i])).dy));
    }
    expect(find.text('Candidatura não selecionada'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Fora do ranking desta edição'), findsNWidgets(2));
    expect(QuizSession.instance.results, orderedEquals(originalResults));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'comparison starts with alphabetical choice instead of API leader', (
    tester,
  ) async {
    final session = QuizSession.testOnly(api: _Api())
      ..results = const [
        CandidateResult(
          candidateId: '1',
          name: 'Zilda',
          party: 'DC',
          scorePercent: 100,
          rank: 1,
          countedTheses: 1,
          answeredTheses: 9,
          matches: [],
        ),
        CandidateResult(
          candidateId: '2',
          name: 'Ana',
          party: 'DC',
          scorePercent: 75,
          rank: 2,
          countedTheses: 8,
          answeredTheses: 9,
          comparableCategories: 4,
          matches: [],
        ),
      ];
    await pump(tester, ComparisonPage(session: session, analytics: analytics));
    expect(tester.getTopLeft(find.text('Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Zilda')).dy));
    await tester.tap(find.text('COMPARAR RESPOSTAS'));
    await tester.pumpAndSettle();
    expect(find.text('Ana: 8 de 9 respostas comparáveis · 4 categorias.'),
        findsOneWidget);
    expect(find.textContaining('Zilda:'), findsNothing);
    expect(session.results.first.candidateId, '1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('weighting permits continuing only after editing fifth answer', (
    tester,
  ) async {
    QuizSession.instance.theses = answers(4);
    await pump(
      tester,
      WeightingPage(analytics: analytics),
      routes: {
        '/party-selection': (_) => const Scaffold(body: Text('Seleção aberta')),
      },
    );
    final continueButton = find.widgetWithText(
      ElevatedButton,
      'CONTINUAR PARA SELEÇÃO',
    );
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);
    await tester.ensureVisible(find.byIcon(Icons.edit).last);
    await tester.tap(find.byIcon(Icons.edit).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CONCORDO').last);
    await tester.tap(find.text('CONCORDO').last);
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Seleção aberta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  QuizSession selectionSession(ApiClient api) => QuizSession.testOnly(api: api)
    ..theses = answers(5)
    ..selectedCandidateIds = {'1'}
    ..candidates = [
      Party.fromCandidateJson({
        'id': 1,
        'name': 'Candidata Teste',
        'party_acronym': 'DC',
        'official_status': 'AGUARDANDO JULGAMENTO',
        'source_snapshot': '20/09/2026 08:30:57',
      }),
    ];

  testWidgets('submission failure preserves candidate selection and retry', (
    tester,
  ) async {
    final api = _Api()..submitError = const ApiException('Falha de conexão.');
    final session = selectionSession(api);
    await pump(
      tester,
      PartySelectionPage(session: session, analytics: analytics),
    );
    await tester.tap(find.text('VER RESULTADOS'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível calcular o resultado'),
      findsOneWidget,
    );
    expect(find.text('Não foi possível carregar os candidatos.'), findsNothing);
    expect(find.text('Candidata Teste'), findsOneWidget);
    expect(session.selectedCandidateIds, {'1'});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'outdated thesis error offers a new quiz and clears old selection',
    (tester) async {
      final api = _Api()
        ..submitError = const ApiException(
          'Tese indisponível.',
          code: 'invalid_thesis_ids',
        );
      final session = selectionSession(api);
      await pump(
        tester,
        PartySelectionPage(session: session, analytics: analytics),
        routes: {'/quiz': (_) => const Scaffold(body: Text('Novo quiz'))},
      );
      await tester.ensureVisible(find.text('VER RESULTADOS'));
      await tester.pump();
      await tester.tap(find.text('VER RESULTADOS'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('As perguntas foram atualizadas'),
        findsOneWidget,
      );
      await tester.tap(find.text('REFAZER QUIZ'));
      await tester.pumpAndSettle();
      expect(find.text('Novo quiz'), findsOneWidget);
      expect(session.candidates, isEmpty);
      expect(session.theses, isEmpty);
      expect(session.selectedCandidateIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('comparison exposes evidence and opens exactly its source URL', (
    tester,
  ) async {
    final session = QuizSession.testOnly(api: _Api())
      ..results = const [
        CandidateResult(
          candidateId: '1',
          name: 'Candidata Teste',
          party: 'DC',
          scorePercent: 100,
          rank: 1,
          countedTheses: 1,
          answeredTheses: 2,
          matches: [
            ThesisMatch(
              thesisId: 1,
              thesisText: 'A tese comparada',
              themeId: 1,
              userAnswer: 'agree',
              candidatePosition: 'concordo',
              matchType: 'match',
            ),
            ThesisMatch(
              thesisId: 2,
              thesisText: 'A tese condicional',
              themeId: 1,
              userAnswer: 'neutral',
              candidatePosition: 'sem_posicao',
              candidateAnalysis: 'CONDICIONAL_OU_MISTA',
              matchType: 'skipped',
            ),
          ],
        ),
      ];
    Uri? opened;
    await pump(
      tester,
      ComparisonPage(
        session: session,
        analytics: analytics,
        openLink: (uri) async {
          opened = uri;
          return true;
        },
      ),
    );
    await tester.tap(find.text('COMPARAR RESPOSTAS'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Posição condicional ou mista'), findsOneWidget);
    expect(find.byTooltip('Neutro'), findsOneWidget);
    await tester.tap(find.text('1. A TESE COMPARADA'));
    await tester.pumpAndSettle();
    expect(find.text('Trecho do plano: “Trecho verificável”'), findsOneWidget);
    expect(
      find.text('Referência: Documento oficial, páginas 4 e 8'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('ABRIR FONTE OFICIAL'));
    await tester.tap(find.text('ABRIR FONTE OFICIAL'));
    await tester.pumpAndSettle();
    expect(opened.toString(), 'https://example.test/plano.pdf');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a withdrawn selection refreshes candidates and can be resubmitted',
    (tester) async {
      final api = _Api()
        ..submitResults = const [
          CandidateResult(
            candidateId: '2',
            name: 'Nova candidata',
            party: 'DC',
            scorePercent: 50,
            rank: 1,
            countedTheses: 3,
            answeredTheses: 5,
            matches: [],
          ),
        ]
        ..candidates = [
          Party.fromCandidateJson({
            'id': 2,
            'name': 'Nova candidata',
            'party_acronym': 'DC',
          }),
        ];
      final session = selectionSession(api);
      await pump(
        tester,
        PartySelectionPage(session: session, analytics: analytics),
        routes: {
          '/results': (_) => const Scaffold(body: Text('Resultado atualizado')),
        },
      );
      await tester.tap(find.text('VER RESULTADOS'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado atualizado'), findsNothing);
      expect(
        find.textContaining('A lista de candidaturas foi atualizada'),
        findsOneWidget,
      );
      expect(find.text('Candidata Teste'), findsNothing);
      expect(find.text('Nova candidata'), findsOneWidget);
      expect(session.results, isEmpty);
      expect(session.selectedCandidateIds, isEmpty);
      await tester.ensureVisible(find.text('Nova candidata'));
      await tester.pump();
      await tester.tap(find.text('Nova candidata'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('VER RESULTADOS'));
      await tester.pump();
      await tester.tap(find.text('VER RESULTADOS'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado atualizado'), findsOneWidget);
      expect(session.selectedCandidateIds, {'2'});
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['missing', 'text', 'position', 'withdrawn']) {
    testWidgets('comparison blocks incompatible evidence: $change', (
      tester,
    ) async {
      final api = _Api()
        ..justifications = change == 'missing'
            ? []
            : [
                CandidateJustification(
                  thesisId: 1,
                  thesisText: change == 'text'
                      ? 'Uma redação nova'
                      : 'A tese comparada',
                  theme: 'economia',
                  themeName: 'Economia',
                  position: change == 'position' ? 'discordo' : 'concordo',
                  justification: 'Resumo incompatível',
                  quote: 'Trecho incompatível',
                  sourceUrl: 'https://example.test/nova-fonte.pdf',
                ),
              ];
      if (change == 'withdrawn') {
        api.justificationError = const ApiException(
          'Candidatura não encontrada.',
          statusCode: 404,
        );
      }
      final session = selectionSession(api)
        ..results = const [
          CandidateResult(
            candidateId: '1',
            name: 'Candidata Teste',
            party: 'DC',
            scorePercent: 100,
            rank: 1,
            countedTheses: 1,
            answeredTheses: 5,
            matches: [
              ThesisMatch(
                thesisId: 1,
                thesisText: 'A tese comparada',
                themeId: 1,
                userAnswer: 'agree',
                candidatePosition: 'concordo',
                matchType: 'match',
              ),
            ],
          ),
        ];
      await pump(
        tester,
        ComparisonPage(session: session, analytics: analytics),
        routes: {
          '/party-selection': (_) =>
              const Scaffold(body: Text('Recalcular seleção')),
        },
      );
      await tester.tap(find.text('COMPARAR RESPOSTAS'));
      await tester.pumpAndSettle();
      expect(find.text('A comparação precisa ser atualizada.'), findsOneWidget);
      expect(find.textContaining('Trecho incompatível'), findsNothing);
      expect(find.text('ABRIR FONTE OFICIAL'), findsNothing);
      await tester.tap(find.text('RECALCULAR RESULTADO'));
      await tester.pumpAndSettle();
      expect(find.text('Recalcular seleção'), findsOneWidget);
      expect(session.totalAnswered, 5);
      expect(tester.takeException(), isNull);
    });
  }
}
