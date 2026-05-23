import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home page shows start button', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    expect(find.text('FAROL\nPOLÍTICO'), findsOneWidget);
    expect(find.text('COMEÇAR'), findsOneWidget);
    expect(find.text('MEU FAROL'), findsOneWidget);
  });
}
