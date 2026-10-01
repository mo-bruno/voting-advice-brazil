import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/community/community_processing_notice.dart';

void main() {
  for (final action in ['post', 'comment']) {
    testWidgets('$action notice names political publication and its action',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: action == 'post'
                  ? const CommunityProcessingNotice.post()
                  : const CommunityProcessingNotice.comment(),
            ),
          ),
        ),
      ));
      expect(
          find.textContaining('pode revelar opinião política'), findsOneWidget);
      expect(find.textContaining('alias pseudônimo estável'), findsOneWidget);
      expect(
        find.textContaining('avaliado pela moderação antes da publicação'),
        findsOneWidget,
      );
      expect(find.textContaining('NVIDIA NIM'), findsNothing);
      expect(find.textContaining('Não inclua dados pessoais'), findsOneWidget);
      expect(
        find.textContaining(action == 'post'
            ? 'Ao tocar em PUBLICAR'
            : 'Ao tocar em ENVIAR COMENTÁRIO'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
