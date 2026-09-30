import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/device/device_identity_store.dart';
import '../../core/layout/app_scaffold.dart';
import '../../core/theme/app_theme.dart';
import 'community_processing_notice.dart';
import 'community_session.dart';
import 'models/community_models.dart';
import 'models/community_theme.dart';
import 'utils/community_errors.dart';
import 'utils/community_length_formatter.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key, this.apiClient, this.initialThemeSlug});

  /// Injetavel para teste, seguindo o padrao do feed.
  @visibleForTesting
  final ApiClient? apiClient;

  final String? initialThemeSlug;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool _loading = false;
  bool _allowPop = false;
  bool _exitDialogOpen = false;
  String? _error;
  String? _anonymousId;
  List<CommunityTheme> _themes = [];
  String? _selectedTheme;

  bool get _hasDraft => _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final id = await DeviceIdentityStore().getOrCreateDeviceId();
    if (!mounted) return;
    setState(() => _anonymousId = id);
    try {
      final themes = await _api.fetchThemes();
      if (mounted) {
        setState(() {
          _themes = themes;
          _selectedTheme =
              themes.any((theme) => theme.slug == widget.initialThemeSlug)
                  ? widget.initialThemeSlug
                  : null;
        });
      }
    } catch (_) {
      // Sem temas a tela continua util: o seletor e opcional.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestExit() async {
    if (_loading) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content:
              Text('Publicação em análise. Aguarde o resultado antes de sair.'),
        ));
      return;
    }
    if (_exitDialogOpen) return;
    if (_hasDraft) {
      _exitDialogOpen = true;
      FocusScope.of(context).unfocus();
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Descartar rascunho?'),
          content: const Text('Seu texto ainda não foi publicado.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      _exitDialogOpen = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _chooseTheme() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final availableHeight = MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: availableHeight * 0.7,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Tema da publicação'),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          title: const Text('Sem tema'),
                          selected: _selectedTheme == null,
                          onTap: () => Navigator.pop(context, ''),
                        ),
                        for (final theme in _themes)
                          ListTile(
                            title: Text(theme.nome),
                            selected: _selectedTheme == theme.slug,
                            onTap: () => Navigator.pop(context, theme.slug),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedTheme = selected.isEmpty ? null : selected);
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (_loading || content.isEmpty || content.runes.length > 500) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final anonymousId =
          _anonymousId ?? await DeviceIdentityStore().getOrCreateDeviceId();
      // A identidade pode terminar de carregar depois que a rota foi removida.
      if (!mounted) return;
      final json = await _api.createPost(
        content: content,
        anonymousId: anonymousId,
        themeSlug: _selectedTheme,
      );
      final post = PostSummary.fromJson(json);
      CommunitySession().invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _allowPop = true);
      Navigator.pop(context, post);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {
        _error = communityErrorMessage(
          error,
          fallback:
              'Erro ao publicar. Verifique sua conexão e tente novamente.',
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty &&
        _controller.text.runes.length <= 500 &&
        !_loading;
    final selectedTheme =
        _themes.where((theme) => theme.slug == _selectedTheme).firstOrNull;

    return PopScope<PostSummary>(
      canPop: _allowPop || (!_hasDraft && !_loading),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: AppScaffold(
        title: 'NOVA PUBLICAÇÃO',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: _requestExit,
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, semanticsLabel: 'Publicação em análise')),
            ),
        ],
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        border: Border.all(color: AppTheme.error),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_anonymousId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person_outline,
                            size: 20, color: AppTheme.onSurfaceVariant),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Publicação sob alias pseudônimo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Seu UUID local é uma credencial de posse; ele gera um alias público estável para suas publicações.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_loading) ...[
                  Semantics(
                    liveRegion: true,
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text('Publicação em análise. Aguarde...')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _controller,
                  enabled: !_loading,
                  maxLength: 500,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  inputFormatters: const [CommunityLengthFormatter(500)],
                  minLines: 6,
                  maxLines: 10,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.onSurface,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    counterText: '${_controller.text.runes.length}/500',
                    hintText:
                        'Compartilhe sua visão sobre política brasileira...',
                    hintStyle: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                    counterStyle: TextStyle(color: AppTheme.onSurfaceVariant),
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_themes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'TEMA (OPCIONAL)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _chooseTheme,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      side: const BorderSide(color: AppTheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedTheme?.nome ?? 'Sem tema',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      left:
                          BorderSide(color: AppTheme.outlineVariant, width: 2),
                    ),
                  ),
                  child: const Text(
                    'Todo post passa por uma verificação automática de relevância '
                    'e civilidade antes de aparecer no fórum.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const CommunityProcessingNotice.post(),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('PUBLICAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
