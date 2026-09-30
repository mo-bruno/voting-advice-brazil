import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_processing_notice.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/models/thesis.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

import 'helpers/analytics_test_support.dart';

class _SilentSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _CandidateApi extends ApiClient {
  _CandidateApi(
      {this.failFirstCandidateLoad = false, this.submitResults = const []});

  final bool failFirstCandidateLoad;
  final List<CandidateResult> submitResults;
  int candidateAttempts = 0;

  static final candidate = Party.fromCandidateJson({
    'id': 13,
    'name': 'Candidatura',
    'party_acronym': 'PT',
  });

  @override
  Future<List<Party>> fetchCandidates() async {
    candidateAttempts++;
    if (failFirstCandidateLoad && candidateAttempts == 1) {
      throw const ApiException('detalhe privado', statusCode: 503);
    }
    return [candidate];
  }

  @override
  Future<List<CandidateResult>> submitQuiz(
    List<Thesis> theses, {
    String? deviceId,
    Set<String> candidateIds = const {},
  }) async =>
      submitResults;
}

List<Thesis> _answeredTheses(int count) => List.generate(
      count,
      (index) => Thesis(
        id: index + 1,
        title: 'Tese ${index + 1}',
        category: 'Economia',
        answer: ThesisAnswer.agree,
      ),
    );

void main() {
  testWidgets(
      'selection shows processing notice above reachable results action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: const TextScaler.linear(2),
      ),
      child: MaterialApp(
        home: PartySelectionPage(
          session: session,
          analytics: AnalyticsService(sink: _SilentSink()),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(QuizProcessingNotice), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await tester.ensureVisible(find.text('VER RESULTADOS'));
    await tester.pump();
    expect(find.text('VER RESULTADOS').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('candidate retry reports one terminal per attempt',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final api = _CandidateApi(failFirstCandidateLoad: true);
    final session = QuizSession.testOnly(api: api);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PartySelectionPage(
          session: session,
          analytics: AnalyticsService(sink: sink),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.text('Não foi possível carregar os candidatos.'), findsOneWidget);
    await tester.tap(find.text('TENTAR NOVAMENTE'));
    await tester.pumpAndSettle();

    final operations = named(sink.calls, 'operation_result')
        .where((call) => call.parameters?['operation'] == 'candidate_load')
        .toList();
    expect(operations, hasLength(2));
    expect(
      operations.map((call) => call.parameters?['outcome']),
      ['failed', 'success'],
    );
    expect(
      operations.map((call) => call.parameters?['trigger']),
      ['initial', 'retry'],
    );
    expect(operations.first.parameters?['failure_type'], 'unavailable');
    expect(operations.first.parameters!.values,
        isNot(contains('detalhe privado')));
  });

  testWidgets('local submit validation reports blocked without completion',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final session = QuizSession.testOnly()
      ..theses = _answeredTheses(4)
      ..candidates = [_CandidateApi.candidate]
      ..selectedCandidateIds = {'13'};
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PartySelectionPage(
          session: session,
          analytics: AnalyticsService(sink: sink),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('VER RESULTADOS'));
    await tester.pumpAndSettle();

    expect(sink.names, isNot(contains('party_selection_completed')));
    expect(
      lastOperation(sink.calls).parameters,
      allOf(
        containsPair('operation', 'results_submit'),
        containsPair('outcome', 'blocked'),
        containsPair('failure_type', 'client'),
      ),
    );
  });

  testWidgets('successful submit navigation never waits for analytics',
      (tester) async {
    final blocker = Completer<void>();
    final sink = RecordingAnalyticsSink(block: blocker.future);
    const result = CandidateResult(
      candidateId: '13',
      name: 'Candidatura',
      party: 'PT',
      scorePercent: 80,
      rank: 1,
      countedTheses: 5,
      answeredTheses: 5,
      matches: [],
    );
    final session = QuizSession.testOnly(
      api: _CandidateApi(submitResults: const [result]),
    )
      ..theses = _answeredTheses(5)
      ..candidates = [_CandidateApi.candidate]
      ..selectedCandidateIds = {'13'};
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => PartySelectionPage(
                session: session,
                analytics: AnalyticsService(sink: sink),
              ),
          '/results': (_) => const Scaffold(body: Text('resultado aberto')),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('VER RESULTADOS'));
    await tester.pumpAndSettle();

    expect(find.text('resultado aberto'), findsOneWidget);
    expect(
      sink.names.where((name) => name == 'party_selection_completed'),
      hasLength(1),
    );
    expect(lastOperation(sink.calls).parameters?['outcome'], 'success');
    blocker.complete();
  });
}
