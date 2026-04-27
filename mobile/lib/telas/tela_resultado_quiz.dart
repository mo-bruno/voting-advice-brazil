import 'package:flutter/material.dart';
import '../core/layout/app_scaffold.dart';
import '../core/theme/app_theme.dart';
import '../modelos/resultado_quiz.dart';
import '../widgets/quiz/card_resultado_quiz.dart';

class TelaResultadoQuiz extends StatelessWidget {
  final List<ResultadoQuiz> resultados;

  const TelaResultadoQuiz({
    super.key,
    required this.resultados,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      mostrarVoltar: true,
      titulo: 'Resultado',
      larguraMaxima: 430,
      larguraMaximaTelaGrande: 760,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      paddingTelaGrande: const EdgeInsets.fromLTRB(40, 28, 40, 28),
      bodyBuilder: (context, telaGrande) {
        return _ConteudoResultado(resultados: resultados);
      },
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
            color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
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
              color: AppColors.textMuted,
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
        color: AppColors.textSecondary,
        fontSize: 16,
        height: 1.5,
      ),
    );
  }
}
