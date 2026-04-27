import 'package:flutter/material.dart';

import '../core/layout/app_scaffold.dart';
import '../core/theme/app_theme.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      mostrarVoltar: true,
      titulo: 'Sobre',
      larguraMaxima: 360,
      larguraMaximaTelaGrande: 760,
      paddingTelaGrande: const EdgeInsets.symmetric(
        horizontal: 40,
        vertical: 24,
      ),
      bodyBuilder: (context, telaGrande) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(telaGrande ? 32 : 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VotingAdvice',
                style: TextStyle(
                  fontSize: telaGrande ? 34 : 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              const _ParagrafoSobre(
                'O VotingAdvice é um projeto desenvolvido para ajudar o usuário a compreender melhor seu próprio posicionamento político de forma simples, visual e acessível.',
              ),
              const SizedBox(height: 16),
              const _ParagrafoSobre(
                'A proposta da aplicação é apresentar um quiz com perguntas sobre temas relevantes, permitindo que o usuário selecione as respostas com as quais mais concorda.',
              ),
              const SizedBox(height: 16),
              const _ParagrafoSobre(
                'Com base nas respostas, o sistema compara o perfil do usuário com diferentes posicionamentos políticos e apresenta os resultados de compatibilidade.',
              ),
              const SizedBox(height: 24),
              const Text(
                'Objetivo principal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const _ParagrafoSobre(
                'Oferecer uma experiência interativa que ajude o usuário a refletir sobre suas opiniões e entender melhor com quais posições políticas ele mais se identifica.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParagrafoSobre extends StatelessWidget {
  final String texto;

  const _ParagrafoSobre(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 15,
        height: 1.7,
        color: AppColors.textSecondary,
      ),
    );
  }
}
