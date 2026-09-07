// lib/shared/widgets/drawer/drawer_footer.dart
//
// Fecha a gaveta por baixo. O identificador anonimo esta aqui de proposito: o
// app promete nao guardar dado pessoal, e mostrar o unico identificador que
// existe e o que torna a promessa verificavel em vez de declarada.

import 'package:flutter/material.dart';

import '../../../core/app_info.dart';
import '../../../core/theme/app_theme.dart';

class DrawerFooter extends StatelessWidget {
  const DrawerFooter({
    super.key,
    required this.shortId,
    required this.onAbout,
    required this.onPrivacy,
  });

  /// `null` enquanto o identificador ainda esta sendo lido do disco. A linha
  /// encolhe em vez de piscar um espaco reservado.
  final String? shortId;
  final VoidCallback onAbout;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final id = shortId;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FooterLink(label: 'SOBRE', onTap: onAbout),
              const SizedBox(width: 18),
              _FooterLink(label: 'PRIVACIDADE', onTap: onPrivacy),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            id == null ? 'v$kAppVersion' : 'v$kAppVersion • ID $id',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: AppTheme.onSurface,
          ),
        ),
      ),
    );
  }
}
