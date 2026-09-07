import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home renderiza a tela de noticias', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Smoke test do app inteiro: sobe pelo MyApp real, então a NewsSession
    // singleton tenta a rede de verdade — que em teste de widget devolve 400 e
    // leva a tela ao estado de erro. Por isso as asserções ficam na moldura,
    // que aparece em qualquer estado.
    expect(find.text('FAROL POLÍTICO'), findsOneWidget);
    expect(find.text('NOTÍCIAS DA SEMANA'), findsOneWidget);
    expect(find.text('VER TODAS AS NOTÍCIAS'), findsOneWidget);
  });
}
