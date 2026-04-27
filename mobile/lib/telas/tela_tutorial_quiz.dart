import 'package:flutter/material.dart';

import '../config/quiz_config.dart';
import '../core/layout/app_scaffold.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';
import '../widgets/botao_contorno.dart';

class TelaTutorialQuiz extends StatelessWidget {
  const TelaTutorialQuiz({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      mostrarVoltar: true,
      larguraMaxima: 360,
      larguraMaximaTelaGrande: 520,
      paddingTelaGrande: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 24,
      ),
      bodyBuilder: (context, telaGrande) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: telaGrande ? 32 : 24,
            vertical: telaGrande ? 32 : 28,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Neste teste, você responderá a ${QuizConfig.totalPerguntas} perguntas para descobrir com quais posicionamentos políticos mais combina.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: telaGrande ? 18 : 16,
                  height: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              const _ItemTutorial(
                icone: Icons.check_rounded,
                texto: 'Concordar com a afirmação',
              ),
              const SizedBox(height: 12),
              const _ItemTutorial(
                icone: Icons.close_rounded,
                texto: 'Negar a afirmação',
              ),
              const SizedBox(height: 12),
              const _ItemTutorial(
                icone: Icons.remove_rounded,
                texto: 'Responder neutro',
              ),
              const SizedBox(height: 28),
              BotaoContorno(
                texto: 'Iniciar',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.perguntaQuiz);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemTutorial extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _ItemTutorial({
    required this.icone,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(icone, color: AppColors.textPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
