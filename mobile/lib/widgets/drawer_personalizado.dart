import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import 'item_menu.dart';

class DrawerPersonalizado extends StatelessWidget {
  const DrawerPersonalizado({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 290,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          border: Border(
            right: BorderSide(
              color: Color(0xFF1B1B1B),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF171717),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.how_to_vote_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VotingAdvice',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Escolha melhor com base no quiz',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Navegação',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ItemMenu(
                  icone: Icons.home_rounded,
                  titulo: 'Início',
                  subtitulo: 'Tela principal',
                  destacado: true,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, AppRoutes.inicial);
                  },
                ),
                ItemMenu(
                  icone: Icons.info_outline_rounded,
                  titulo: 'Sobre',
                  subtitulo: 'Sobre o projeto',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.sobre);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
