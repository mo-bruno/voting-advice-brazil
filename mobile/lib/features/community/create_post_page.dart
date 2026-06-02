import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/theme/app_theme.dart';
import 'community_session.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anonymousId = await DeviceIdentityStore().getOrCreateDeviceId();
      await ApiClient().createPost(content: content, anonymousId: anonymousId);
      CommunitySession().invalidate();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().contains('422')
          ? 'Post rejeitado pela moderação. Revise o conteúdo e tente novamente.'
          : 'Erro ao publicar. Verifique sua conexão e tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _controller.text.length;
    final canSubmit = charCount > 0 && !_loading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nova publicação'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: canSubmit ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'PUBLICAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: canSubmit
                            ? AppTheme.primary
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    size: 14,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Publicação anônima — sua identidade é protegida',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: 500,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.onSurface,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  labelText: 'Publicacao',
                  hintText:
                      'Compartilhe sua visão sobre política brasileira...',
                  hintStyle: TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                  counterStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                  contentPadding: EdgeInsets.all(12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.error),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
