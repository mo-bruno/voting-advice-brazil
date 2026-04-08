import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF1A2A1A),
              Color(0xFF131313),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * 0.1,
                          ),
                          Text(
                            'GUIA\nELEITORAL',
                            style: textTheme.displayLarge?.copyWith(
                              fontSize: 52,
                              height: 0.95,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.primary,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'BRASIL 2026',
                              style: textTheme.titleLarge?.copyWith(
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/quiz');
                              },
                              child: const Text('COMEÇAR'),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            'UMA FERRAMENTA DE INFORMAÇÃO NEUTRA PARA FORTALECER A DEMOCRACIA BRASILEIRA.',
                            style: textTheme.bodyMedium?.copyWith(
                              letterSpacing: 0.5,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 64),
                          Text(
                            'PARCEIROS E INSTITUIÇÕES',
                            style: textTheme.labelMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          const _PartnersGrid(),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PartnersGrid extends StatelessWidget {
  const _PartnersGrid();

  @override
  Widget build(BuildContext context) {
    final partners = ['TSE', 'Observatório', 'Folha', 'Estadão', 'UNI-Brasil'];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: partners.map((name) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            name,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}
