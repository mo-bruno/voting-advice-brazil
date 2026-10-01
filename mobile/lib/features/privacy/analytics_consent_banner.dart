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
    const decisionStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 48)),
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
                  'Se você aceitar, enviamos somente métricas de uso e desempenho. Não enviamos respostas do quiz, preferências políticas ou textos e não usamos publicidade.',
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
                    ElevatedButton(
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
