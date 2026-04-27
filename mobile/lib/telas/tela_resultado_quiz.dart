import 'package:flutter/material.dart';
import '../modelos/resultado_quiz.dart';
import '../widgets/quiz/botao_fixo_inferior.dart';
import '../widgets/quiz/card_resultado_quiz.dart';
import '../widgets/topo_padrao.dart';

class TelaResultadoQuiz extends StatelessWidget {
  final List<ResultadoQuiz> resultados;

  const TelaResultadoQuiz({
    super.key,
    required this.resultados,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(
              mostrarVoltar: true,
              titulo: 'Resultado',
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth > 900;
                  final larguraMaxima = telaGrande ? 760.0 : 430.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: larguraMaxima),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          telaGrande ? 40 : 24,
                          28,
                          telaGrande ? 40 : 24,
                          28,
                        ),
                        child: _ConteudoResultado(resultados: resultados),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF050505),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF242424),
                    width: 1,
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: const BotaoFixoInferior(
                    texto: 'IR PARA O SITE',
                    preenchido: true,
                    onPressed: null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConteudoResultado extends StatelessWidget {
  final List<ResultadoQuiz> resultados;

  const _ConteudoResultado({required this.resultados});

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return const _ResultadoVazio();
    }

    final resultadosOrdenados = [...resultados]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    final principal = resultadosOrdenados.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CabecalhoResultado(),
        const SizedBox(height: 24),
        Text(
          'Maior compatibilidade: ${principal.name}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
        ...resultadosOrdenados.map(
          (resultado) => CardResultadoQuiz(resultado: resultado),
        ),
      ],
    );
  }
}

class _CabecalhoResultado extends StatelessWidget {
  const _CabecalhoResultado();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'SEU\nRESULTADO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'PASSO 4 DE 4',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultadoVazio extends StatelessWidget {
  const _ResultadoVazio();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Não foi possível montar um resultado com as respostas enviadas.',
      style: TextStyle(
        color: Colors.white70,
        fontSize: 16,
        height: 1.5,
      ),
    );
  }
}
