import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class QuizProcessingNotice extends StatelessWidget {
  const QuizProcessingNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: const Text(
        'Suas respostas podem revelar opinião política. Ao tocar em VER RESULTADOS, você concorda com o envio à API e o processamento transitório para calcular a comparação. Na versão pública, elas não são armazenadas. Isso independe da sua escolha sobre métricas.',
      ),
    );
  }
}
