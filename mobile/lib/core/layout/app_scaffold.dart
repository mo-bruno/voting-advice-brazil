// lib/core/layout/app_scaffold.dart
//
// Estrutura base reutilizável das telas do app. Em vez de cada página montar
// seu próprio Scaffold/AppBar, todas usam o AppScaffold: ele centraliza a
// estrutura (barra superior e área de conteúdo) e cada tela cuida apenas do
// `body`. Os parâmetros opcionais (`subtitle`, `leading`, `actions`,
// `floatingActionButton`) permitem que telas com necessidades específicas
// reutilizem a mesma estrutura sem recriá-la — separando estrutura de conteúdo.

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: subtitle == null
            ? Text(title, style: titleStyle)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
        leading: leading,
        actions: actions,
        centerTitle: false,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
