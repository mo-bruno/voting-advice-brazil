import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_processing_notice.dart';

class _SilentSink implements AnalyticsSink {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  testWidgets('intro explains processing before a reachable start action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: const TextScaler.linear(2),
      ),
      child: MaterialApp(
        home: QuizIntroPage(analytics: AnalyticsService(sink: _SilentSink())),
      ),
    ));
    expect(find.byType(QuizProcessingNotice), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    await tester.ensureVisible(find.text('COMEÇAR PERGUNTAS'));
    await tester.pump();
    expect(find.text('COMEÇAR PERGUNTAS').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
