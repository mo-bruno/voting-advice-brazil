import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/layout/app_scaffold.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/home/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A gaveta e do APP, nao da aba. Enquanto cada tela-destino trazia a sua, ela
/// nascia dentro da aba e abaixo da barra inferior: a barra continuava tocavel
/// por cima da gaveta aberta, e trocar de aba dali deixava a gaveta aberta na
/// aba antiga, esperando o usuario voltar.
class _Tab extends StatelessWidget {
  const _Tab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      AppScaffold(title: 'FAROL POLÍTICO', body: Center(child: Text(label)));
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'farol_politico_device_id': 'a3f9c21b-0000-4000-8000-000000000000',
    });
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MainShell(
        initialTab: MainShellTab.quiz,
        pageBuilders: [
          () => const _Tab('tela-inicio'),
          () => const _Tab('tela-acompanhar'),
          () => const _Tab('tela-quiz'),
          () => const _Tab('tela-comunidade'),
        ],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('o hamburguer de uma aba abre a gaveta do shell', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('MEU FAROL'), findsOneWidget);
  });

  testWidgets('a gaveta cobre a barra inferior', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Nascendo dentro da aba, a gaveta parava onde a barra comecava.
    expect(tester.getRect(find.byType(Drawer)).height, 844);
  });

  testWidgets('tocar na barra com a gaveta aberta nao troca de aba',
      (tester) async {
    // O caminho exato do bug relatado: a barra ficava alcancavel por cima da
    // gaveta, e o toque trocava de aba deixando a gaveta aberta na aba de tras.
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.home_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('tela-quiz'), findsOneWidget);
    expect(find.text('tela-inicio'), findsNothing);
  });

  testWidgets('a home tambem abre a gaveta do shell, e nao uma propria',
      (tester) async {
    // A HomePage monta o proprio Scaffold, com uma barra superior propria em
    // vez do AppScaffold — entao ela nao herda nada da correcao e precisa do
    // seu proprio teste.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MainShell(
        pageBuilders: [
          () => const HomePage(),
          () => const _Tab('tela-acompanhar'),
          () => const _Tab('tela-quiz'),
          () => const _Tab('tela-comunidade'),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException(); // a home busca noticias; em teste a rede da 400

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('MEU FAROL'), findsOneWidget);
    expect(tester.getRect(find.byType(Drawer)).height, 844);
  });

  testWidgets('uma tela empilhada nao mostra hamburguer sem gaveta atras',
      (tester) async {
    // Fora do shell nao ha gaveta para abrir. Uma tela empilhada que nao passa
    // `leading` — a WeightingPage e uma — precisa cair na seta de voltar, senao
    // vira o mesmo beco sem saida da /quiz-intro.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      routes: {
        '/': (_) => const Scaffold(body: Text('origem')),
        '/empilhada': (_) =>
            const AppScaffold(title: 'FAROL POLÍTICO', body: SizedBox()),
      },
    ));

    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/empilhada');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('origem'), findsOneWidget);
  });
}
