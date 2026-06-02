// lib/shared/widgets/app_drawer.dart
//
// Menu lateral ("hamburguer") reutilizável e compartilhado por todas as telas.
// Os itens são definidos como dados (lista de mapas), e não como widgets fixos,
// o que permite gerá-los dinamicamente e facilita adicionar novos destinos no
// futuro. A navegação usa rotas nomeadas, desacoplando o menu das telas.

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = <Map<String, dynamic>>[
      {'icon': Icons.home_rounded, 'title': 'Início', 'route': '/'},
      {
        'icon': Icons.how_to_vote_rounded,
        'title': 'Responder quiz',
        'route': '/quiz-intro',
      },
      {
        'icon': Icons.person_search_rounded,
        'title': 'Acompanhar político',
        'route': '/political-actors',
      },
      {
        'icon': Icons.lightbulb_rounded,
        'title': 'Meu Farol',
        'route': '/iot-device'
      },
      {
        'icon': Icons.forum_rounded,
        'title': 'Comunidade',
        'route': '/comunidade'
      },
    ];

    return Drawer(
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppTheme.background),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'FAROL\nPOLÍTICO',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    height: 1.0,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'BRASIL 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          // O operador `...` (spread) expande o resultado do `map`, inserindo
          // um ListTile para cada item de navegação definido acima.
          ...menuItems.map((item) {
            final route = item['route'] as String;
            return ListTile(
              leading:
                  Icon(item['icon'] as IconData, color: AppTheme.onSurface),
              title: Text(
                item['title'] as String,
                style: const TextStyle(
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // fecha o menu lateral
                if (route == '/') {
                  // Volta para a tela inicial limpando a pilha de navegação.
                  Navigator.pushNamedAndRemoveUntil(
                      context, route, (_) => false);
                } else {
                  Navigator.pushNamed(context, route);
                }
              },
            );
          }),
        ],
      ),
    );
  }
}
