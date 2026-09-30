import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CommunityProcessingNotice extends StatelessWidget {
  const CommunityProcessingNotice.post({super.key}) : action = 'PUBLICAR';

  const CommunityProcessingNotice.comment({super.key})
      : action = 'ENVIAR COMENTÁRIO';

  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Text(
        'Seu texto pode revelar opinião política e ficará público sob um alias '
        'pseudônimo estável. Ele será armazenado e enviado à NVIDIA NIM para '
        'moderação. Não inclua dados pessoais que não queira publicar. '
        'Ao tocar em $action, você concorda especificamente com esse uso.',
      ),
    );
  }
}
