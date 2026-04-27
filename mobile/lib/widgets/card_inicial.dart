import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import 'botao_contorno.dart';

class CardInicial extends StatelessWidget {
  const CardInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final telaGrande = largura > 700;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: telaGrande ? 36 : 24,
            vertical: telaGrande ? 36 : 28,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bem-vindo ao\nVotingAdvice',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: telaGrande ? 32 : 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Para uma melhor experiência, responda algumas perguntas para descobrir com qual figura política ou partido você mais se parece.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: telaGrande ? 16 : 15,
                  height: 1.6,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Deseja responder esse quiz?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: telaGrande ? 16 : 15,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              BotaoContorno(
                texto: 'Sim, eu quero',
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.tutorial);
                },
              ),
              const SizedBox(height: 12),
              const BotaoContorno(
                texto: 'Não quero',
                onPressed: null,
              ),
            ],
          ),
        );
      },
    );
  }
}
