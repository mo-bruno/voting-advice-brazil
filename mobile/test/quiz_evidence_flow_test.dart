import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
            thesisText: 'A tese sem evidência',
            theme: 'economia',
            themeName: 'Economia',
            position: 'sem_posicao',
            justification: 'O plano não sustenta uma posição categórica.',
          ),
        ];
  }
}

void main() {
  late AnalyticsService analytics;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets('intro explains the complete review and evidence-based selection',
      (tester) async {
    await pump(tester, QuizIntroPage(analytics: analytics));
    expect(find.textContaining('70 formulações'), findsOneWidget);
    expect(find.textContaining('13 planos'), findsOneWidget);
    expect(find.textContaining('30 teses'), findsOneWidget);
    expect(find.textContaining('por IA, sem validação humana'), findsOneWidget);
    expect(find.textContaining('contraste documentado'), findsOneWidget);
    expect(find.textContaining('9 teses'), findsNothing);
    expect(find.textContaining('29 teses de rascunho'), findsNothing);
    expect(find.textContaining('está pendente'), findsNothing);
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
    expect(find.text('MAIOR AFINIDADE'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('Sem base comparável'), findsOneWidget);
    expect(find.text('0 de 9 respostas comparáveis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a real zero affinity keeps its percent and evidence count', (
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
        matches: [],
      ),
    ];
    await pump(tester, ResultsPage(analytics: analytics));
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('2 de 9 respostas comparáveis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equal percentages on different bases do not announce a tie', (
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
        countedTheses: index % 7 + 1,
        answeredTheses: 9,
        matches: const [],
      ),
    );
    await pump(tester, ResultsPage(analytics: analytics));
    expect(find.text('EMPATE NA MAIOR AFINIDADE'), findsNothing);
    expect(find.text('50.0%'), findsNWidgets(9));
    expect(find.text('MAIOR AFINIDADE'), findsNothing);
    expect(QuizSession.instance.topAffinityResults, hasLength(9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unequal evidence bases show all coverage without a winner', (
    tester,
  ) async {
    QuizSession.instance.results = const [
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
        matches: [],
      ),
    ];
    await pump(tester, ResultsPage(analytics: analytics), routes: {
      '/comparison': (_) =>
          const Scaffold(body: Text('Detalhes da comparação')),
    });

    expect(find.text('MAIOR AFINIDADE'), findsNothing);
    expect(find.text('100.0%'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Sem base comparável'), findsOneWidget);
    for (final count in [0, 1, 8]) {
      expect(find.text('$count de 9 respostas comparáveis'), findsOneWidget);
    }
    expect(tester.getTopLeft(find.text('Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Maria')).dy));
    expect(tester.getTopLeft(find.text('Maria')).dy,
        lessThan(tester.getTopLeft(find.text('Zilda')).dy));
    expect(QuizSession.instance.results.first.candidateId, '1');
    await tester.ensureVisible(find.text('COMPARAR RESPOSTAS'));
    await tester.tap(find.text('COMPARAR RESPOSTAS'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da comparação'), findsOneWidget);
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
          matches: [],
        ),
      ];
    await pump(tester, ComparisonPage(session: session, analytics: analytics));
    expect(tester.getTopLeft(find.text('Ana')).dy,
        lessThan(tester.getTopLeft(find.text('Zilda')).dy));
    await tester.tap(find.text('COMPARAR RESPOSTAS'));
    await tester.pumpAndSettle();
    expect(find.text('Ana: 8 de 9 respostas comparáveis.'), findsOneWidget);
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
              thesisText: 'A tese sem evidência',
              themeId: 1,
              userAnswer: 'neutral',
              candidatePosition: 'sem_posicao',
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
    expect(find.byTooltip('Sem evidência suficiente'), findsOneWidget);
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
      await tester.tap(find.text('Nova candidata'));
      await tester.pumpAndSettle();
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
