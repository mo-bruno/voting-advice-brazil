import 'package:flutter/material.dart';

class IndicadorProgressoQuiz extends StatelessWidget {
  final int total;
  final int atual;

  const IndicadorProgressoQuiz({
    super.key,
    required this.total,
    required this.atual,
  });

  @override
  Widget build(BuildContext context) {
    const maxVisiveis = 11;

    int inicio = atual - (maxVisiveis ~/ 2);
    if (inicio < 0) inicio = 0;

    int fim = inicio + maxVisiveis;
    if (fim > total) {
      fim = total;
      inicio = fim - maxVisiveis;
      if (inicio < 0) inicio = 0;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(fim - inicio, (i) {
        final index = inicio + i;
        final selecionado = index == atual;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selecionado ? 18 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: selecionado ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selecionado ? Colors.white : Colors.white38,
            ),
          ),
        );
      }),
    );
  }
}
