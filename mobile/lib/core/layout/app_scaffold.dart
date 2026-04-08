import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final int? currentNavIndex;
  final ValueChanged<int>? onNavTap;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showAppBar;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentNavIndex,
    this.onNavTap,
    this.actions,
    this.leading,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              leading: leading,
              actions: actions,
              centerTitle: false,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: body,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: currentNavIndex != null
          ? BottomNavigationBar(
              currentIndex: currentNavIndex!,
              onTap: onNavTap,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.quiz_outlined),
                  activeIcon: Icon(Icons.quiz),
                  label: 'Questões',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.balance_outlined),
                  activeIcon: Icon(Icons.balance),
                  label: 'Pesos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'Resultados',
                ),
              ],
              backgroundColor: AppTheme.surface,
            )
          : null,
    );
  }
}
