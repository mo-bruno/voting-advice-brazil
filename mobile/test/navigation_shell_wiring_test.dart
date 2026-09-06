import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/shared/widgets/app_drawer.dart';

/// Sink de analytics que nao chama o Firebase.
class _SilentSink implements AnalyticsSink {
  const _SilentSink();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

/// Tela de mentira, para o shell nao montar as reais (que precisam de Firebase
/// e de rede — ver o comentario em `main_shell_test.dart`).
class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

List<Widget Function()> _stubs() => [
      () => const _Stub('tela-inicio'),
      () => const _Stub('tela-acompanhar'),
      () => const _Stub('tela-quiz'),
      () => const _Stub('tela-comunidade'),
    ];

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('menu lateral', () {
    testWidgets('lista apenas os destinos que nao estao na barra',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(drawer: AppDrawer(), body: SizedBox()),
      ));
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Meu Farol'), findsOneWidget);

      // Os quatro destinos primarios vivem na barra inferior. Duplica-los aqui
      // empilharia uma segunda copia da tela sobre o shell.
      expect(find.text('Início'), findsNothing);
      expect(find.text('Responder quiz'), findsNothing);
      expect(find.text('Acompanhar político'), findsNothing);
      expect(find.text('Comunidade'), findsNothing);
    });
  });

  group('intro do quiz como aba', () {
    testWidgets('mostra o menu e nao a seta de voltar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: QuizIntroPage(
          analytics: AnalyticsService(sink: _SilentSink()),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });

  group('reinicio do quiz', () {
    testWidgets('volta ao shell na aba do quiz', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (context) => MainShell(
                initialTab: MainShell.tabFromArguments(
                  ModalRoute.of(context)?.settings.arguments,
                ),
                pageBuilders: _stubs(),
              ),
          '/resultados-falsos': (_) => const Scaffold(body: Text('resultados')),
        },
      ));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/resultados-falsos');
      await tester.pumpAndSettle();
      expect(find.byType(BottomNavigationBar), findsNothing);

      // O gesto que a ResultsPage executa ao reiniciar o quiz.
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
        arguments: MainShellTab.quiz,
      );
      await tester.pumpAndSettle();

      // A barra volta E a aba certa esta selecionada. Antes desta correcao o
      // usuario ficava numa /quiz-intro solta, sem barra e sem volta.
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('tela-quiz'), findsOneWidget);
    });
  });
}
