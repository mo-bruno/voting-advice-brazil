import 'package:flutter/material.dart';

import '../../core/analytics/analytics_consent_controller.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsConsentBanner extends StatelessWidget {
  const AnalyticsConsentBanner({
    super.key,
    required this.controller,
    required this.onLearnMore,
    required this.onGrantPersistenceFailure,
    required this.onDenialPersistenceFailure,
  });

  final AnalyticsConsentController controller;
  final VoidCallback onLearnMore;
  final VoidCallback onGrantPersistenceFailure;
  final VoidCallback onDenialPersistenceFailure;

  @override
  Widget build(BuildContext context) {
    final decisionStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      side: const BorderSide(color: AppTheme.primary),
    );
    return Material(
      color: AppTheme.surfaceContainer,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Métricas opcionais',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Usamos Google Analytics somente se você aceitar, para medir uso e desempenho. Ele pode receber um identificador pseudônimo, a página, navegador/dispositivo e eventos genéricos. Não enviamos suas respostas do quiz, candidatos, partidos ou afinidade e não usamos publicidade.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      style: decisionStyle,
                      onPressed: () async {
                        if (!await controller.deny()) {
                          onDenialPersistenceFailure();
                        }
                      },
                      child: Semantics(
                        label: 'Rejeitar métricas opcionais',
                        child: const Text('REJEITAR MÉTRICAS'),
                      ),
                    ),
                    OutlinedButton(
                      style: decisionStyle,
                      onPressed: () async {
                        if (!await controller.grant()) {
                          onGrantPersistenceFailure();
                        }
                      },
                      child: Semantics(
                        label: 'Aceitar métricas opcionais',
                        child: const Text('ACEITAR MÉTRICAS'),
                      ),
                    ),
                    TextButton(
                      onPressed: onLearnMore,
                      child: const Text('SAIBA MAIS'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
