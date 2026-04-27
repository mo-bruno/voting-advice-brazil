import 'package:flutter/material.dart';
import '../config/quiz_config.dart';
import '../routes/app_routes.dart';
import '../widgets/botao_contorno.dart';
import '../widgets/topo_padrao.dart';

class TelaTutorialQuiz extends StatelessWidget {
  const TelaTutorialQuiz({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopoPadrao(mostrarVoltar: true),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final telaGrande = constraints.maxWidth > 900;
                  final larguraMaxima = telaGrande ? 520.0 : 360.0;

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
                          padding: EdgeInsets.symmetric(
                            horizontal: telaGrande ? 32 : 24,
                            vertical: telaGrande ? 32 : 28,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D0D),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Neste teste, você responderá a ${QuizConfig.totalPerguntas} perguntas para descobrir com quais posicionamentos políticos mais combina.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
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
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.perguntaQuiz,
                                  );
                                },
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
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
