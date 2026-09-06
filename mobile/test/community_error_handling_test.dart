import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/community/post_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A feature de comunidade chamava a API sem tratar falha em quatro pontos.
/// Em teste de widget o HttpClient devolve 400, o que reproduz exatamente a
/// falha de rede que o usuario veria com o backend fora do ar.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('detalhe do post mostra erro em vez de girar para sempre',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDetailPage(postId: 'qualquer'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Antes: `_loading` nunca virava false e a tela girava indefinidamente.
    // Adicionar so um `finally` seria pior — o build faz `_detail!.post` e
    // passaria a crashar. Por isso o estado de erro tem de existir.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Não foi possível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe do post permite tentar de novo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PostDetailPage(postId: 'qualquer'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TENTAR DE NOVO'), findsOneWidget);

    await tester.tap(find.text('TENTAR DE NOVO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('feed da comunidade nao estoura quando a api falha',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const CommunityFeedPage(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
