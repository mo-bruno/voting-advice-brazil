import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/home/widgets/news_states.dart';

/// Os estados vazio e de erro das notícias sao centralizados por dentro — mas
/// isso so aparece se o bloco ocupar a largura toda. A home os coloca numa
/// Column com `crossAxisAlignment.start`, que da restricao FROUXA aos filhos:
/// sem largura propria o bloco encolhe ate o texto mais largo e encosta na
/// esquerda, com o texto centralizado dentro dele. Parece desalinhado porque
/// esta.
///
/// A coluna do teste e larga (1200px) de proposito: em 400px o titulo ja ocupa
/// a linha toda com a fonte de teste, e o bloco pareceria centralizado mesmo
/// encolhido. Numa largura que nenhum texto preenche, encolher fica visivel.
void main() {
  setUp(() {});

  Future<void> pumpNaColunaDaHome(WidgetTester tester, Widget estado) async {
    // A superficie padrao do teste tem 800px; sem alarga-la, o SizedBox de
    // 1200 seria recortado e a conta do centro nao fecharia.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          child: Column(
            // Igual a home monta (home_page.dart).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [estado],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('o erro fica no centro da coluna', (tester) async {
    await pumpNaColunaDaHome(tester, NewsError(onRetry: () {}));

    expect(
      tester.getCenter(find.byIcon(Icons.warning_amber_rounded)).dx,
      600,
    );
    expect(
      tester.getCenter(find.text('Não foi possível carregar as notícias')).dx,
      600,
    );
  });

  testWidgets('o botao de tentar de novo tambem', (tester) async {
    await pumpNaColunaDaHome(tester, NewsError(onRetry: () {}));

    expect(tester.getCenter(find.text('TENTAR DE NOVO')).dx, 600);
  });

  testWidgets('o estado vazio segue a mesma regra', (tester) async {
    await pumpNaColunaDaHome(tester, const NewsEmpty());

    expect(tester.getCenter(find.byIcon(Icons.article_outlined)).dx, 600);
  });
}
