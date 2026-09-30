import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import 'community_processing_notice.dart';
import 'community_session.dart';
import 'models/community_theme.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.apiClient});

  /// Injetavel para teste, seguindo o padrao do feed.
  @visibleForTesting
  final ApiClient? apiClient;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _controller = TextEditingController();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool _loading = false;
  String? _error;
  String? _anonymousId;
  List<CommunityTheme> _themes = [];
  String? _selectedTheme;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = await DeviceIdentityStore().getOrCreateDeviceId();
    if (mounted) setState(() => _anonymousId = id);
    try {
      final themes = await _api.fetchThemes();
      if (mounted) setState(() => _themes = themes);
    } catch (_) {
      // Sem temas a tela continua util: o seletor e opcional.
    }
  }

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
      final anonymousId =
          _anonymousId ?? await DeviceIdentityStore().getOrCreateDeviceId();
      await _api.createPost(
        content: content,
        anonymousId: anonymousId,
        themeSlug: _selectedTheme,
      );
      CommunitySession().invalidate();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        final texto = e.toString();
        if (texto.contains('429')) {
          _error = 'Você publicou demais nos últimos minutos. '
              'Aguarde alguns instantes.';
        } else if (texto.contains('422')) {
          _error = 'Post rejeitado pela moderação. '
              'Revise o conteúdo e tente novamente.';
        } else if (texto.contains('503')) {
          _error = 'A moderação está indisponível no momento. '
              'Tente novamente em instantes.';
        } else {
          _error = 'Erro ao publicar. Verifique sua conexão e tente novamente.';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _controller.text.length;
    final canSubmit = charCount > 0 && !_loading;

    return AppScaffold(
      title: 'NOVA PUBLICAÇÃO',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_anonymousId != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person_outline,
                          size: 16, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Publicação sob alias pseudônimo',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurface)),
                          SizedBox(height: 2),
                          Text(
                              'Seu UUID local é uma credencial de posse; ele gera um alias público estável para suas publicações.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: 500,
              minLines: 5,
              maxLines: 12,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                  fontSize: 15, color: AppTheme.onSurface, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Compartilhe sua visão sobre política brasileira...',
                hintStyle:
                    TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 15),
                filled: true,
                fillColor: AppTheme.surfaceContainer,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppTheme.outlineVariant)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppTheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppTheme.primary)),
                counterStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                contentPadding: EdgeInsets.all(12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_themes.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('TEMA (OPCIONAL)',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _themes.map((t) {
                  final selected = _selectedTheme == t.slug;
                  return InkWell(
                    onTap: () => setState(
                        () => _selectedTheme = selected ? null : t.slug),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : Colors.transparent,
                        border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.outlineVariant),
                      ),
                      child: Text(t.nome.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              letterSpacing: 0.5,
                              color: selected
                                  ? AppTheme.background
                                  : AppTheme.onSurfaceVariant)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: AppTheme.outlineVariant, width: 2))),
              child: const Text(
                'Todo post passa por uma verificação automática de relevância '
                'e de checagem factual antes de aparecer no fórum.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: AppTheme.onSurfaceVariant),
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
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            const CommunityProcessingNotice.post(),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: canSubmit ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('PUBLICAR'),
            ),
          ],
        ),
      ),
    );
  }
}
