import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/features/party_selection/party_selection_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_processing_notice.dart';
import 'package:guia_eleitoral/shared/models/party.dart';
import 'package:guia_eleitoral/shared/quiz_session.dart';

class _SilentSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

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
}
