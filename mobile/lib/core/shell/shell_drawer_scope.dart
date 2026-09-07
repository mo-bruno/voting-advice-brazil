// lib/core/shell/shell_drawer_scope.dart
//
// Diz a uma tela que ela esta DENTRO do shell e, portanto, tem uma gaveta
// acima dela para abrir.
//
// A gaveta e do app, nao da aba: ela vive no Scaffold do MainShell, junto com a
// barra inferior, para cobrir a tela inteira. Mas o botao que a abre esta no
// AppBar de cada tela — vários niveis abaixo, dentro do Scaffold da propria
// tela. `Scaffold.of` dali resolve para o Scaffold de dentro, que nao tem
// gaveta nenhuma; este escopo e a ponte que faltava.
//
// Estar ausente tambem e informacao: uma tela empilhada e irma do shell na
// pilha de rotas, nunca sua descendente, entao nao acha este escopo. E assim
// que o AppScaffold sabe que ali o lugar do hamburguer e da seta de voltar.

import 'package:flutter/widgets.dart';

class ShellDrawerScope extends InheritedWidget {
  const ShellDrawerScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  /// `null` quando a tela nao esta dentro do shell.
  static VoidCallback? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShellDrawerScope>()
        ?.openDrawer;
  }

  @override
  bool updateShouldNotify(ShellDrawerScope oldWidget) {
    // O shell passa sempre o mesmo tear-off (ver `_MainShellState`), entao isto
    // e falso em todo rebuild e as telas nao se reconstroem a toa.
    return openDrawer != oldWidget.openDrawer;
  }
}
