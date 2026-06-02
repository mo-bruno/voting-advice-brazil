import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app applies a global constrained layout builder',
      (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.builder, isNotNull);
  });

  testWidgets('home page shows start button', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());

    expect(find.text('FAROL\nPOLÍTICO'), findsOneWidget);
    expect(find.text('COMEÇAR'), findsOneWidget);
    expect(find.text('MEU FAROL'), findsOneWidget);
  });
}
