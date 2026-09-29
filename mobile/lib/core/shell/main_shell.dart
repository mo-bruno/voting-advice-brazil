import 'package:flutter/material.dart';

import '../features/feature_flags.dart';
import '../../features/community/community_feed_page.dart';
import '../../features/home/home_page.dart';
import '../../features/political_actors/political_actor_search_page.dart';
import '../../features/quiz/quiz_intro_page.dart';
import '../../shared/widgets/app_drawer.dart';
import 'shell_drawer_scope.dart';
import '../layout/responsive_layout.dart';
import '../theme/app_theme.dart';

/// As abas da barra inferior. É a interface pública do shell: quem quiser abrir
/// o app numa aba específica passa um valor deste enum como `arguments` da
/// rota `/`.
enum MainShellTab { inicio, acompanhar, quiz, comunidade }

/// Casca persistente das quatro telas-destino.
///
/// O `Scaffold` daqui fornece a barra inferior E a gaveta — sem `appBar` e sem
/// `floatingActionButton`, que cada tela-destino traz.
///
/// A gaveta mora aqui porque é do app, não da aba: aqui ela cobre a tela
/// inteira, barra inclusive, e existe uma só. Quando cada tela trazia a sua,
/// ela nascia dentro da aba, a barra continuava tocável por cima dela, e trocar
/// de aba ali deixava a gaveta aberta na aba de trás, esperando o usuário
/// voltar. O botão que a abre está no AppBar de cada tela; `ShellDrawerScope`
/// é como ele chega até aqui.
///
/// Telas de detalhe e o fluxo do quiz empilham SOBRE esta rota, cobrindo a
/// barra. Não há navegador aninhado.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = MainShellTab.inicio,
    this.iotEnabled,
    this.pageBuilders,
  });

  final MainShellTab initialTab;

  /// Quando ausente, usa a flag de compilação da aplicação.
  final bool? iotEnabled;

  /// Injetável apenas em teste. O shell responde por trocar de aba e por não
  /// recriar o que já foi visitado — não pelo conteúdo das telas, que têm seus
  /// próprios testes. Montá-las de verdade aqui exigiria Firebase e rede, o que
  /// testaria as dependências delas em vez do comportamento daqui.
  @visibleForTesting
  final List<Widget Function(VoidCallback onStartQuiz)>? pageBuilders;

  /// Lê a aba de abertura dos `arguments` da rota. Argumento ausente ou de
  /// outro tipo cai em `inicio`, sem erro.
  static MainShellTab tabFromArguments(Object? arguments) =>
      arguments is MainShellTab ? arguments : MainShellTab.inicio;

  /// A ligação entre aba e tela. Separada do `build` para poder ser verificada
  /// sem montar nada.
  static Widget defaultPageFor(
    MainShellTab tab, {
    required VoidCallback onStartQuiz,
  }) =>
      switch (tab) {
        MainShellTab.inicio => HomePage(onStartQuiz: onStartQuiz),
        MainShellTab.acompanhar => const PoliticalActorSearchPage(),
        MainShellTab.quiz => const QuizIntroPage(),
        MainShellTab.comunidade => const CommunityFeedPage(),
      };

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab.index;

  /// A gaveta e do Scaffold daqui, mas quem a abre esta dentro da tela da aba,
  /// fundo demais para `Scaffold.of` chegar. A chave e o atalho.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tear-off de metodo de instancia: a identidade e estavel entre rebuilds, o
  /// que mantem `ShellDrawerScope.updateShouldNotify` falso.
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  /// Instanciação preguiçosa: uma aba nunca visitada não existe, logo não
  /// dispara request. Depois da primeira visita ela é mantida viva, e trocar de
  /// aba não a recria nem refaz a chamada de rede.
  late final List<Widget?> _pages = List<Widget?>.filled(
    MainShellTab.values.length,
    null,
  );

  Widget _pageFor(int index) {
    final builders = widget.pageBuilders;
    return _pages[index] ??= builders != null
        ? builders[index](_openQuiz)
        : MainShell.defaultPageFor(
            MainShellTab.values[index],
            onStartQuiz: _openQuiz,
          );
  }

  void _openQuiz() => _select(MainShellTab.quiz.index);

  void _select(int index) {
    // Tocar na aba já selecionada não faz nada: as telas de detalhe empilham
    // sobre o shell, não dentro dele, então não há pilha interna a desempilhar.
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    _pageFor(_index);
    final desktop = ResponsiveLayout.isDesktop(context);
    final iotEnabled = widget.iotEnabled ?? FeatureFlags.environment.iotEnabled;

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(iotEnabled: iotEnabled),
      appBar: desktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppTheme.outlineVariant)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: ResponsiveLayout.desktopContentWidth),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Abrir menu',
                          icon: const Icon(Icons.menu),
                          onPressed: _openDrawer,
                        ),
                        const SizedBox(width: 12),
                        const Text('FAROL POLÍTICO',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            )),
                        const Spacer(),
                        for (final (index, label) in [
                          'Início',
                          'Acompanhar',
                          'Quiz',
                          'Comunidade'
                        ].indexed)
                          Padding(
                            padding: const EdgeInsets.only(left: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                color: _index == index
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ))),
                              child: Semantics(
                                selected: _index == index,
                                child: TextButton(
                                  onPressed: () => _select(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 22),
                                    child: Text(label,
                                        style: const TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: ShellDrawerScope(
        openDrawer: _openDrawer,
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < MainShellTab.values.length; i++)
              LayoutBuilder(
                builder: (context, constraints) {
                  final wideTab = desktop && i != MainShellTab.inicio.index;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: wideTab
                          ? (constraints.maxWidth * 0.8).clamp(600.0, 960.0)
                          : constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Padding(
                        padding: EdgeInsets.only(top: wideTab ? 32 : 0),
                        child: _pages[i] ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: _select,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_search_rounded),
                  // "Acompanhar Político" nao cabe: 4 abas em 390px dao ~97px cada.
                  label: 'Acompanhar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.how_to_vote_rounded),
                  label: 'Quiz',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.forum_rounded),
                  label: 'Comunidade',
                ),
              ],
            ),
    );
  }
}
