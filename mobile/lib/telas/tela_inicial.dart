import 'package:flutter/material.dart';
import '../core/layout/app_scaffold.dart';
import '../widgets/card_inicial.dart';
import '../widgets/drawer_personalizado.dart';

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: const DrawerPersonalizado(),
      larguraMaxima: 360,
      larguraMaximaTelaGrande: 520,
      paddingTelaGrande: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 24,
      ),
      bodyBuilder: (context, telaGrande) => const CardInicial(),
    );
  }
}
