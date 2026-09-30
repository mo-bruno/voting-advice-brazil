import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/quiz/quiz_processing_notice.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets('quiz notice explains transient political processing at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: QuizProcessingNotice()),
          ),
        ),
      ));
      expect(find.textContaining('podem revelar opinião política'),
          findsOneWidget);
      expect(find.textContaining('VER RESULTADOS'), findsOneWidget);
      expect(find.textContaining('não são armazenadas'), findsOneWidget);
      expect(find.textContaining('independe da sua escolha sobre métricas'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
