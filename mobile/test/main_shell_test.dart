import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:guia_eleitoral/core/layout/app_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/shell/main_shell.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/home/home_page.dart';
import 'package:guia_eleitoral/features/political_actors/political_actor_search_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';

/// Telas de mentira, uma por aba.
///
/// O shell responde por trocar de aba e por manter viva a aba já visitada. As
/// telas reais dependem de Firebase e de rede; monta-las aqui testaria as
/// dependencias delas, nao o comportamento do shell. A ligacao entre aba e tela
/// real e verificada a parte, em `defaultPageFor`.
class _Stub extends StatefulWidget {
  const _Stub(this.label);

  final String label;

  @override
  State<_Stub> createState() => _StubState();
}

class _StubState extends State<_Stub> {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(widget.label)));
}

List<Widget Function(VoidCallback)> _stubs() => [
      (_) => const _Stub('tela-inicio'),
      (_) => const _Stub('tela-acompanhar'),
      (_) => const _Stub('tela-quiz'),
      (_) => const _Stub('tela-comunidade'),
    ];

List<Widget Function(VoidCallback)> _stubsWithQuizInvitation() => [
      (openQuiz) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: openQuiz,
                child: const Text('convite-quiz'),
              ),
            ),
          ),
      (_) => const _Stub('tela-acompanhar'),
      (_) => const _Stub('tela-quiz'),
      (_) => const _Stub('tela-comunidade'),
    ];

Widget _wrap({MainShellTab tab = MainShellTab.inicio}) => MaterialApp(
      theme: AppTheme.dark,
      home: MainShell(initialTab: tab, pageBuilders: _stubs()),
    );

void main() {
  testWidgets('desktop has one brand and menu, compact restores tab bar',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MainShell(pageBuilders: [
        for (var i = 0; i < 4; i++)
          (_) => const AppScaffold(
              title: 'FAROL POLÍTICO', body: Text('conteudo')),
      ]),
    ));
    expect(find.text('FAROL POLÍTICO'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
        isTrue);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(600, 900);
    await tester.pumpAndSettle();
    expect(find.text('FAROL POLÍTICO'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('desktop navigation switches tabs from the header',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_wrap());
    expect(find.byType(BottomNavigationBar), findsNothing);
    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    expect(find.text('tela-quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mostra as quatro abas', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Acompanhar'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(find.text('Comunidade'), findsOneWidget);
  });

  testWidgets('abre na Inicio por padrao', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('tela-inicio'), findsOneWidget);
  });

  testWidgets('aba nao visitada nao e construida', (tester) async {
    await tester.pumpWidget(_wrap());

    // O IndexedStack preguicoso nao instancia a tela antes da primeira visita,
    // o que evita que as tres telas de rede disparem request no boot.
    expect(find.text('tela-comunidade'), findsNothing);
    expect(find.text('tela-quiz'), findsNothing);
  });

  testWidgets('tocar numa aba troca a tela', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Comunidade'));
    await tester.pump();

    expect(find.text('tela-comunidade'), findsOneWidget);
  });

  testWidgets('convite da home troca para a aba Quiz', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MainShell(pageBuilders: _stubsWithQuizInvitation()),
      ),
    );

    await tester.tap(find.text('convite-quiz'));
    await tester.pump();

    expect(find.text('tela-quiz'), findsOneWidget);
    expect(find.text('convite-quiz'), findsNothing);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      MainShellTab.quiz.index,
    );
  });

  testWidgets('aba visitada nao e recriada ao voltar', (tester) async {
    await tester.pumpWidget(_wrap());

    await tester.tap(find.text('Comunidade'));
    await tester.pump();
    final primeiro = tester.state(find.byType(_Stub).last);

    await tester.tap(find.text('Início'));
    await tester.pump();
    await tester.tap(find.text('Comunidade'));
    await tester.pump();
    final segundo = tester.state(find.byType(_Stub).last);

    expect(identical(primeiro, segundo), isTrue);
  });

  testWidgets('tocar na aba ja selecionada nao recria nada', (tester) async {
    await tester.pumpWidget(_wrap());
    final antes = tester.state(find.byType(_Stub));

    await tester.tap(find.text('Início'));
    await tester.pump();

    expect(identical(antes, tester.state(find.byType(_Stub))), isTrue);
  });

  testWidgets('initialTab seleciona a aba de abertura', (tester) async {
    await tester.pumpWidget(_wrap(tab: MainShellTab.quiz));

    expect(find.text('tela-quiz'), findsOneWidget);
    expect(find.text('tela-inicio'), findsNothing);
  });

  testWidgets('rota empilhada sobre o shell cobre a barra', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      routes: {
        '/': (_) => MainShell(pageBuilders: _stubs()),
        '/detalhe': (_) => const Scaffold(body: Text('detalhe')),
      },
    ));
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/detalhe');
    await tester.pumpAndSettle();

    expect(find.text('detalhe'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  group('tabFromArguments', () {
    test('devolve a aba quando o argumento e um MainShellTab', () {
      expect(MainShell.tabFromArguments(MainShellTab.quiz), MainShellTab.quiz);
    });

    test('cai em inicio quando o argumento e nulo ou de outro tipo', () {
      expect(MainShell.tabFromArguments(null), MainShellTab.inicio);
      expect(MainShell.tabFromArguments('quiz'), MainShellTab.inicio);
      expect(MainShell.tabFromArguments(2), MainShellTab.inicio);
    });
  });

  group('defaultPageFor', () {
    test('cada aba aponta para a tela certa', () {
      expect(
        MainShell.defaultPageFor(MainShellTab.inicio, onStartQuiz: () {}),
        isA<HomePage>(),
      );
      expect(
        MainShell.defaultPageFor(
          MainShellTab.acompanhar,
          onStartQuiz: () {},
        ),
        isA<PoliticalActorSearchPage>(),
      );
      expect(
        MainShell.defaultPageFor(MainShellTab.quiz, onStartQuiz: () {}),
        isA<QuizIntroPage>(),
      );
      expect(
        MainShell.defaultPageFor(
          MainShellTab.comunidade,
          onStartQuiz: () {},
        ),
        isA<CommunityFeedPage>(),
      );
    });
  });
}
