import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/shell/shell_drawer_scope.dart';
import 'package:guia_eleitoral/features/community/community_feed_page.dart';
import 'package:guia_eleitoral/features/quiz/quiz_intro_page.dart';
import 'package:guia_eleitoral/features/political_actors/political_actor_search_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estas telas sao abas do MainShell, logo vivem na rota raiz. Uma seta de
/// voltar ali chama `Navigator.pop` sobre a unica rota da pilha e deixa o app
/// em branco — foi o bug relatado.
///
/// Elas usam sessions singleton e batem na rede no `initState`; em teste de
/// widget o HttpClient devolve 400. O erro e absorvido de proposito: o que
/// importa aqui e a moldura da AppBar, que renderiza em qualquer estado.
/// Sink de analytics que nao chama o Firebase.
class _SilentSink implements AnalyticsSink {
  const _SilentSink();

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAsRoot(WidgetTester tester, Widget page) async {
    // Envolvida pelo escopo do shell, como acontece de verdade: e dali que a
    // tela sabe que ha uma gaveta acima dela para o hamburguer abrir.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: ShellDrawerScope(openDrawer: () {}, child: page),
    ));
    await tester.pump();
    // A CommunityFeedPage nao trata a falha de rede: `_loadPage` nao tem
    // try/catch, entao a ApiException escapa como erro assincrono alguns
    // frames depois. Bug pre-existente e independente desta correcao; aqui ele
    // e absorvido para nao mascarar o que este teste verifica.
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();
  }

  group('como aba, na rota raiz', () {
    testWidgets('comunidade mostra o menu e nao a seta de voltar',
        (tester) async {
      await pumpAsRoot(tester, const CommunityFeedPage());

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('acompanhar mostra o menu e nao a seta de voltar',
        (tester) async {
      await pumpAsRoot(tester, const PoliticalActorSearchPage());

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });
  });

  group('quando empilhada', () {
    testWidgets('a intro do quiz ganha a seta de voltar', (tester) async {
      // Nada empilha esta tela hoje. O teste existe porque ela JA foi
      // empilhada — pela rota avulsa /quiz-intro — e, presa no hamburguer,
      // deixava o usuario sem caminho de volta. Se alguem empilhar de novo,
      // a tela se defende sozinha.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (_) => const Scaffold(body: Text('origem')),
          '/intro-empilhada': (_) => QuizIntroPage(
                analytics: AnalyticsService(sink: _SilentSink()),
              ),
        },
      ));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/intro-empilhada');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
    });

    testWidgets('acompanhar mantem a seta de voltar', (tester) async {
      // /political-actors continua sendo empilhada de dois lugares:
      // results_page.dart:127 e political_actor_profile_page.dart:117.
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        routes: {
          '/': (_) => const Scaffold(body: Text('origem')),
          '/political-actors': (_) => const PoliticalActorSearchPage(),
        },
      ));

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/political-actors');
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('origem'), findsOneWidget);
    });
  });
}
