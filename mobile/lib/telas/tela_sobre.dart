import 'package:flutter/material.dart';
import '../widgets/topo_padrao.dart';

class TelaSobre extends StatelessWidget {
  const TelaSobre({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(
              mostrarVoltar: true,
              titulo: 'Sobre',
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth > 900;
                  final larguraMaxima = telaGrande ? 760.0 : 360.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: telaGrande ? 40 : 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: larguraMaxima),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(telaGrande ? 32 : 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D0D),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VotingAdvice',
                                style: TextStyle(
                                  fontSize: telaGrande ? 34 : 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'O VotingAdvice é um projeto desenvolvido para ajudar o usuário a compreender melhor seu próprio posicionamento político de forma simples, visual e acessível.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'A proposta da aplicação é apresentar um quiz com perguntas sobre temas relevantes, permitindo que o usuário selecione as respostas com as quais mais concorda.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Com base nas respostas, o sistema compara o perfil do usuário com diferentes posicionamentos políticos e apresenta os resultados de compatibilidade.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Objetivo principal',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Oferecer uma experiência interativa que ajude o usuário a refletir sobre suas opiniões e entender melhor com quais posições políticas ele mais se identifica.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
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
