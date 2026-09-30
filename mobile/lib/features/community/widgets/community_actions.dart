import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

Future<String?> chooseReportReason(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('POR QUE DENUNCIAR?'),
              ),
              for (final item in const {
                'desinformacao': 'Desinformação',
                'discurso_de_odio': 'Discurso de ódio',
                'spam': 'Spam',
                'outro': 'Outro',
              }.entries)
                ListTile(
                    title: Text(item.value),
                    onTap: () => Navigator.pop(context, item.key)),
            ],
          ),
        ),
      ),
    );

Future<bool> confirmCommunityRemoval(BuildContext context,
        {required bool comment}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(comment ? 'Apagar este comentário?' : 'Apagar este post?'),
        content: Text(comment
            ? 'Seu texto será removido da discussão.'
            : 'O texto some, mas os comentários das outras pessoas continuam.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('APAGAR')),
        ],
      ),
    ) ??
    false;
