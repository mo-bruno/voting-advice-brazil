import 'package:flutter/material.dart';
import '../widgets/card_inicial.dart';
import '../widgets/drawer_personalizado.dart';
import '../widgets/topo_padrao.dart';

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerPersonalizado(),
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth >= 900;
                  final larguraMaxima = telaGrande ? 520.0 : 360.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: telaGrande ? 40 : 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: larguraMaxima),
                        child: const CardInicial(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
