import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/app_info.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/drawer_footer.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/farol_drawer_header.dart';
import 'package:guia_eleitoral/shared/widgets/drawer/farol_led_state.dart';

void main() {
  setUp(() {});

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: SizedBox(width: 304, child: child)),
    ));
    await tester.pump();
  }

  Gradient? halo(WidgetTester tester) {
    final finder = find.byKey(const Key('farol-drawer-halo'));
    if (finder.evaluate().isEmpty) return null;
    final container = tester.widget<Container>(finder);
    return (container.decoration as BoxDecoration).gradient;
  }

  group('cabecalho', () {
    testWidgets('mantem a marca em qualquer estado', (tester) async {
      await pump(tester, const FarolDrawerHeader(state: FarolLedState.absent));

      expect(find.text('FAROL\nPOLÍTICO'), findsOneWidget);
      expect(find.text('BRASIL 2026'), findsOneWidget);
    });

    testWidgets('o halo assume a cor do LED aceso', (tester) async {
      await pump(
        tester,
        const FarolDrawerHeader(state: FarolLedState.divergent),
      );

      final gradient = halo(tester);
      expect(gradient, isNotNull);
      expect(gradient!.colors.first.r, AppTheme.ledDivergent.r);
      expect(gradient.colors.first.g, AppTheme.ledDivergent.g);
      expect(gradient.colors.first.b, AppTheme.ledDivergent.b);
    });

    testWidgets('LED apagado nao pinta o cabecalho', (tester) async {
      // Um halo cinza nao seria "sem cor", seria uma cor a mais. Apagado, o
      // cabecalho volta a ser o mesmo de antes.
      await pump(tester, const FarolDrawerHeader(state: FarolLedState.offline));

      expect(halo(tester), isNull);
    });

    testWidgets('sem dispositivo tambem nao pinta', (tester) async {
      await pump(tester, const FarolDrawerHeader(state: FarolLedState.absent));

      expect(halo(tester), isNull);
    });
  });

  group('rodape', () {
    testWidgets('mostra versao e o identificador anonimo', (tester) async {
      await pump(
        tester,
        DrawerFooter(
          shortId: 'A3F9C21B',
          onAbout: () {},
          onPrivacy: () {},
        ),
      );

      expect(find.text('v$kAppVersion • ID A3F9C21B'), findsOneWidget);
    });

    testWidgets('sem id ainda resolvido, mostra so a versao', (tester) async {
      await pump(
        tester,
        DrawerFooter(shortId: null, onAbout: () {}, onPrivacy: () {}),
      );

      expect(find.text('v$kAppVersion'), findsOneWidget);
    });

    testWidgets('abre sobre e privacidade', (tester) async {
      var sobre = 0;
      var privacidade = 0;
      await pump(
        tester,
        DrawerFooter(
          shortId: 'A3F9C21B',
          onAbout: () => sobre++,
          onPrivacy: () => privacidade++,
        ),
      );

      await tester.tap(find.text('SOBRE'));
      await tester.tap(find.text('PRIVACIDADE'));
      await tester.pump();

      expect(sobre, 1);
      expect(privacidade, 1);
    });
  });

  group('versao publicada', () {
    test('kAppVersion acompanha o pubspec', () {
      // Sem package_info_plus no projeto, a versao e uma constante. Este teste
      // e o que impede a gaveta de anunciar uma versao que nao existe mais.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final declared =
          RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
              .firstMatch(pubspec)!
              .group(1);

      expect(kAppVersion, declared);
    });
  });
}
