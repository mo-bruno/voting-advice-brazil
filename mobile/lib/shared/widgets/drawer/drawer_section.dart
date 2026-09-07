// lib/shared/widgets/drawer/drawer_section.dart
//
// As duas pecas repetidas pelos blocos da gaveta. Ficam aqui porque um bloco
// vazio e um bloco cheio precisam parecer o mesmo bloco: se cada um escrevesse
// seu proprio cabecalho, "ACOMPANHANDO" mudaria de tamanho conforme o estado.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// O cabecalho discreto de um bloco. O bloco do Farol nao usa este — ele tem o
/// seu, com a barra branca, porque e o unico que lidera a gaveta.
class DrawerSectionLabel extends StatelessWidget {
  const DrawerSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }
}

/// A saida de um bloco vazio. Deliberadamente mais leve que um botao: o bloco
/// do Farol e o unico com botao, entao o olho sabe por onde comecar.
class DrawerInlineAction extends StatelessWidget {
  const DrawerInlineAction({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}
