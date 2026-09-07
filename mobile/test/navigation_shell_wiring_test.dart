import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/shell/shell_drawer_scope.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_page.dart';

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

  // O contrato do menu lateral mudou de lista de links para painel de estado e
  // vive inteiro em app_drawer_test.dart — inclusive a verificacao de que ele
  // nao repete os quatro destinos da barra inferior.

  group('intro do quiz como aba', () {
    testWidgets('mostra o menu e nao a seta de voltar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: ShellDrawerScope(
          openDrawer: () {},
          child: QuizIntroPage(
            analytics: AnalyticsService(sink: _SilentSink()),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });

  group('saida do quiz pela seta de voltar', () {
    testWidgets('devolve o usuario ao shell, na aba de onde ele saiu',
        (tester) async {
      // Reproduz os passos relatados: abrir a aba Quiz, comecar as perguntas e
      // usar a seta de voltar. O gesto empilhava a rota avulsa /quiz-intro, que
      // monta a QuizIntroPage FORA do shell — sem barra inferior. E como ela e
      // uma tela-aba, o AppScaffold dela mostra o hamburguer no lugar da seta:
      // sem barra e sem volta, o usuario ficava preso.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (context) => MainShell(
                initialTab: MainShell.tabFromArguments(
                  ModalRoute.of(context)?.settings.arguments,
                ),
                pageBuilders: _stubs(),
              ),
          // /quiz-intro NAO e registrada de proposito: se a seta de voltar
          // tentar empilha-la de novo, o teste morre em "route not found" em
          // vez de passar despercebido.
          '/quiz': (_) => const QuizPage(),
        },
      ));

      await tester.tap(find.byIcon(Icons.how_to_vote_rounded));
      await tester.pumpAndSettle();
      expect(find.text('tela-quiz'), findsOneWidget);

      // O que a QuizIntroPage faz no "COMECAR PERGUNTAS".
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/quiz');
      await tester.pumpAndSettle();
      // A QuizPage busca as teses no initState; em teste a rede devolve 400.
      tester.takeException();
      expect(find.byType(BottomNavigationBar), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('tela-quiz'), findsOneWidget);
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
