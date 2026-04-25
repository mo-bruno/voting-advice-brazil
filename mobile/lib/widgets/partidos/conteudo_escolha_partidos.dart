import 'package:flutter/material.dart';

import '../../modelos/partido.dart';
import 'cabecalho_escolha_partidos.dart';
import 'card_partido.dart';
import 'seletor_todos_partidos.dart';

class ConteudoEscolhaPartidos extends StatelessWidget {
  final bool carregando;
  final String? erro;
  final List<Partido> partidos;
  final Set<String> selecionados;
  final bool telaGrande;
  final VoidCallback onAlternarTodos;
  final ValueChanged<String> onAlternarPartido;
  final ValueChanged<Partido> onMostrarDetalhe;

  const ConteudoEscolhaPartidos({
    super.key,
    required this.carregando,
    required this.erro,
    required this.partidos,
    required this.selecionados,
    required this.telaGrande,
    required this.onAlternarTodos,
    required this.onAlternarPartido,
    required this.onMostrarDetalhe,
  });

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final todosSelecionados =
        partidos.isNotEmpty && selecionados.length == partidos.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        telaGrande ? 40 : 24,
        28,
        telaGrande ? 40 : 24,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CabecalhoEscolhaPartidos(),
          const SizedBox(height: 24),
          const Text(
            'Selecione os partidos que você deseja comparar com suas respostas.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SeletorTodosPartidos(
            selecionado: todosSelecionados,
            totalSelecionados: selecionados.length,
            totalPartidos: partidos.length,
            onTap: onAlternarTodos,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: partidos.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: telaGrande ? 5 : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final partido = partidos[index];

              return CardPartido(
                partido: partido,
                selecionado: selecionados.contains(partido.sigla),
                onTap: () => onAlternarPartido(partido.sigla),
                onMostrarDetalhe: () => onMostrarDetalhe(partido),
              );
            },
          ),
        ],
      ),
    );
  }
}
