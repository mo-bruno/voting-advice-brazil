// lib/core/layout/app_scaffold.dart
//
// Estrutura base reutilizável das telas do app. Em vez de cada página montar
// seu próprio Scaffold/AppBar, todas usam o AppScaffold: ele centraliza a
// estrutura (barra superior e área de conteúdo) e cada tela cuida apenas do
// `body`. Os parâmetros opcionais (`subtitle`, `leading`, `actions`,
// `floatingActionButton`) permitem que telas com necessidades específicas
// reutilizem a mesma estrutura sem recriá-la — separando estrutura de conteúdo.
//
// A gaveta NÃO nasce aqui: ela é uma só e vive no Scaffold do MainShell. O que
// nasce aqui é o botão que a abre, e a regra de quando ele dá lugar à seta de
// voltar (ver `_defaultLeading`).

import 'package:flutter/material.dart';

import '../branding/farol_wordmark.dart';
import '../shell/shell_drawer_scope.dart';
import 'responsive_layout.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.actions,
    this.floatingActionButton,
  });

  /// O botao da esquerda quando a tela nao pede um proprio, decidido por ONDE a
  /// tela esta e nao por qual tela e:
  ///
  /// - dentro do shell -> hamburguer, que abre a gaveta do shell;
  /// - empilhada       -> seta de voltar;
  /// - nenhum dos dois -> nada, porque uma seta na unica rota da pilha deixaria
  ///   o app em branco.
  ///
  /// Decidir aqui, e nao em cada tela, e o que impede o caso que ja aconteceu
  /// duas vezes: uma tela-aba empilhada sozinha, presa no hamburguer, sem barra
  /// inferior e sem caminho de volta.
  Widget? _defaultLeading(BuildContext context) {
    final openShellDrawer = ShellDrawerScope.maybeOf(context);
    if (openShellDrawer != null) {
      return IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Abrir menu',
        onPressed: openShellDrawer,
      );
    }
    if (Navigator.canPop(context)) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Voltar',
        onPressed: () => Navigator.pop(context),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final desktopTab = ResponsiveLayout.isDesktop(context) &&
        ShellDrawerScope.maybeOf(context) != null;
    final hideBrandBar = desktopTab &&
        (title == 'FAROL POLÍTICO' || title == 'FAROL POLITICO') &&
        subtitle == null &&
        leading == null &&
        (actions?.isEmpty ?? true);
    const titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    );
    final titleWidget = title == 'FAROL POLÍTICO' || title == 'FAROL POLITICO'
        ? FarolWordmark(label: title)
        : Text(title, style: titleStyle);

    return Scaffold(
      // Sem `drawer`: a gaveta e uma so e vive no Scaffold do MainShell, para
      // cobrir a tela inteira e nao pertencer a nenhuma aba.
      appBar: hideBrandBar
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: subtitle == null
                  ? titleWidget
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        titleWidget,
                        Text(subtitle!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
              leading:
                  leading ?? (desktopTab ? null : _defaultLeading(context)),
              actions: actions,
              centerTitle: false,
            ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
