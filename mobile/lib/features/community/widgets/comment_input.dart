import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../utils/community_length_formatter.dart';
import '../community_processing_notice.dart';

class CommentInput extends StatelessWidget {
  const CommentInput(
      {super.key,
      required this.controller,
      required this.sending,
      required this.onSend,
      required this.onChanged,
      this.error});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CommunityProcessingNotice.comment(),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                  controller: controller,
                  enabled: !sending,
                  maxLength: 300,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  inputFormatters: const [CommunityLengthFormatter(300)],
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                      counterText: '${controller.text.runes.length}/300',
                      labelText: 'Adicionar comentário',
                      hintText: 'Compartilhe sua opinião...',
                      isDense: true,
                      border: OutlineInputBorder()),
                  onChanged: (_) => onChanged(),
                )),
                const SizedBox(width: 4),
                sending
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))))
                    : IconButton(
                        tooltip: 'Enviar comentário',
                        icon: const Icon(Icons.send_rounded),
                        onPressed: controller.text.trim().isEmpty ||
                                controller.text.runes.length > 300
                            ? null
                            : onSend),
              ]),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(error!,
                            style: const TextStyle(color: AppTheme.error)))),
              Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: Text(
                      sending
                          ? 'Verificando o comentário...'
                          : 'Comentários passam por moderação automática.',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.onSurfaceVariant))),
            ]),
      ));
}
