import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guia_eleitoral/app.dart';

void main() {
  testWidgets('home page shows start button', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await tester.pumpWidget(const MyApp());

    expect(find.text('GUIA\nELEITORAL'), findsOneWidget);
    expect(find.text('COMEÇAR'), findsOneWidget);
  });
}
