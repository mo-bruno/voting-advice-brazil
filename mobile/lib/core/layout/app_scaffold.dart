import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../widgets/topo_padrao.dart';

typedef AppScaffoldBuilder = Widget Function(
  BuildContext context,
  bool telaGrande,
);

class AppScaffold extends StatelessWidget {
  final Widget? body;
  final AppScaffoldBuilder? bodyBuilder;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? footer;
  final Color backgroundColor;
  final bool safeArea;
  final bool mostrarTopo;
  final bool mostrarVoltar;
  final String titulo;
  final VoidCallback? onVoltar;
  final bool scrollable;
  final bool centralizarConteudo;
  final bool expandirConteudo;
  final double larguraMaxima;
  final double larguraMaximaTelaGrande;
  final EdgeInsets padding;
  final EdgeInsets paddingTelaGrande;

  const AppScaffold({
    super.key,
    this.body,
    this.bodyBuilder,
    this.appBar,
    this.drawer,
    this.bottomNavigationBar,
    this.footer,
    this.backgroundColor = AppColors.background,
    this.safeArea = true,
    this.mostrarTopo = true,
    this.mostrarVoltar = false,
    this.titulo = 'VotingAdvice',
    this.onVoltar,
    this.scrollable = true,
    this.centralizarConteudo = true,
    this.expandirConteudo = true,
    this.larguraMaxima = 430,
    this.larguraMaximaTelaGrande = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.paddingTelaGrande =
        const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
  }) : assert(
          body != null || bodyBuilder != null,
          'Informe body ou bodyBuilder.',
        ),
        assert(
          body == null || bodyBuilder == null,
          'Use apenas body ou bodyBuilder.',
        );

  const AppScaffold.plain({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.bottomNavigationBar,
    this.backgroundColor = AppColors.background,
    this.safeArea = true,
  })  : bodyBuilder = null,
        footer = null,
        mostrarTopo = false,
        mostrarVoltar = false,
        titulo = 'VotingAdvice',
        onVoltar = null,
        scrollable = false,
        centralizarConteudo = false,
        expandirConteudo = true,
        larguraMaxima = 430,
        larguraMaximaTelaGrande = 760,
        padding = EdgeInsets.zero,
        paddingTelaGrande = EdgeInsets.zero;

  Widget _buildBody(BuildContext context) {
    if (body != null) return body!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final telaGrande = constraints.maxWidth > 900;
        final largura = telaGrande ? larguraMaximaTelaGrande : larguraMaxima;
        final espaco = telaGrande ? paddingTelaGrande : padding;
        Widget content = bodyBuilder!(context, telaGrande);

        if (scrollable) {
          content = SingleChildScrollView(
            padding: espaco,
            child: content,
          );
        } else if (espaco != EdgeInsets.zero) {
          content = Padding(
            padding: espaco,
            child: content,
          );
        }

        if (centralizarConteudo) {
          content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: largura),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }

  Widget _buildPage(BuildContext context) {
    final children = <Widget>[
      if (mostrarTopo)
        TopoPadrao(
          mostrarVoltar: mostrarVoltar,
          titulo: titulo,
          onVoltar: onVoltar,
        ),
    ];

    final content = _buildBody(context);

    if (expandirConteudo) {
      children.add(Expanded(child: content));
    } else {
      children.add(content);
    }

    if (footer != null) {
      children.add(footer!);
    }

    return Column(children: children);
  }

  Widget _buildContent(BuildContext context) {
    return safeArea ? SafeArea(child: _buildPage(context)) : _buildPage(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor: backgroundColor,
      body: _buildContent(context),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
