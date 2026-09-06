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
    // Os quatro destinos primarios (Inicio, Acompanhar, Quiz, Comunidade) vivem
    // na barra inferior do MainShell. Aqui fica so o que nao esta la: o Meu
    // Farol e raro por natureza — so serve a quem tem o hardware, e o
    // pareamento e acao unica.
    final menuItems = <Map<String, dynamic>>[
      {
        'icon': Icons.lightbulb_rounded,
        'title': 'Meu Farol',
        'route': '/iot-device',
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
