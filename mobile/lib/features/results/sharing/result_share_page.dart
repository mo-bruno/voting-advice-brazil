import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/layout/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import 'result_share_card.dart';
import 'result_share_controls.dart';
import 'result_share_data.dart';
import 'result_share_palette.dart';
import 'result_share_pattern.dart';
import 'result_share_service.dart';

class ResultSharePage extends StatefulWidget {
  const ResultSharePage({super.key, required this.data, this.service});

  final ResultShareData data;
  final ResultShareService? service;

  @override
  State<ResultSharePage> createState() => _ResultSharePageState();
}

class _ResultSharePageState extends State<ResultSharePage> {
  static ResultSharePattern? _lastPattern;

  static ResultSharePattern _drawPattern() {
    final options = ResultSharePattern.values
        .where((pattern) => pattern != _lastPattern)
        .toList();
    final pattern = options[Random().nextInt(options.length)];
    _lastPattern = pattern;
    return pattern;
  }

  final _cardKey = GlobalKey();
  late final _service = widget.service ?? ResultShareService();
  late ResultShareData _data = widget.data;
  ResultSharePalette _palette = ResultSharePalette
      .values[Random().nextInt(ResultSharePalette.values.length)];
  final ResultSharePattern _pattern = _drawPattern();
  ResultShareVariant _rankingVariant = ResultShareVariant.topFive;
  ResultShareFormat _format = ResultShareFormat.story;
  Uint8List? _png;
  bool _imageFailed = false;
  bool _fontsReady = false;
  bool _busy = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _queueImage();
  }

  void _queueImage() {
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareImage(generation));
    });
  }

  Future<void> _prepareImage(int generation) async {
    try {
      await ResultShareCard.loadFonts();
      if (!mounted || generation != _generation) return;
      // Prepara o PNG antes do toque para preservar o gesto do usuário que
      // os navegadores exigem para abrir o menu nativo de compartilhamento.
      setState(() => _fontsReady = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _generation) return;
      final boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Imagem indisponível');
        if (!mounted || generation != _generation) return;
        setState(() => _png = bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _imageFailed = true);
      }
    }
  }

  void _selectFormat(ResultShareFormat format) {
    if (_format == format || _busy) return;
    _changeImage(() => _format = format);
  }

  void _selectVariant(ResultShareVariant variant) {
    if (_data.variant == variant || _busy) return;
    _changeImage(() {
      _data = _data.withVariant(variant);
      if (variant != ResultShareVariant.leader) _rankingVariant = variant;
    });
  }

  void _selectPalette(ResultSharePalette palette) {
    if (_palette == palette || _busy) return;
    _changeImage(() => _palette = palette);
  }

  void _changeImage(VoidCallback update) {
    setState(() {
      update();
      _png = null;
      _imageFailed = false;
    });
    _queueImage();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareImage(BuildContext buttonContext) async {
    final bytes = _png;
    if (bytes == null || _busy) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await _service.shareImage(bytes, _format, origin);
      // Fechar o menu ou escolher um app não confirma uma publicação.
    } catch (_) {
      if (_service.canDownload) {
        try {
          await _service.downloadImage(bytes, _format);
          _notify('Download iniciado. Anexe a imagem na rede social.');
        } catch (_) {
          _notify('Não foi possível baixar a imagem. Tente novamente.');
        }
      } else {
        _notify('Não foi possível compartilhar a imagem. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadImage() async {
    final bytes = _png;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.downloadImage(bytes, _format);
      _notify('Download iniciado. Sua imagem está pronta para anexar.');
    } catch (_) {
      _notify('Não foi possível baixar a imagem. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    try {
      await _service.copyLink(_data);
      _notify('Link copiado. Cole na publicação ou no adesivo de link.');
    } catch (_) {
      _notify('Não foi possível copiar. Selecione o endereço no fim da tela.');
    }
  }

  Future<void> _openNetwork(ResultShareNetwork network) async {
    try {
      await _service.openNetwork(_data, network);
    } catch (_) {
      _notify('Não foi possível abrir a rede social. Use Compartilhar imagem '
          'ou Copiar link.');
    }
  }

  void _instagramHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Leve para o Instagram',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                _service.canDownload
                    ? 'Compartilhe a imagem e escolha o Instagram, se ele '
                        'aparecer no menu. Você também pode baixar a imagem '
                        'e adicioná-la aos Stories ou ao feed.'
                    : 'Compartilhe a imagem e escolha o Instagram no menu '
                        'do celular. Se ele não aparecer, salve a imagem '
                        'pelo menu e adicione aos Stories ou ao feed.',
              ),
              const SizedBox(height: 12),
              const Text('Nos Stories, use o adesivo “Link” e cole o endereço '
                  'do site. O endereço dentro da imagem não é clicável.'),
              const SizedBox(height: 24),
              Builder(
                builder: (buttonContext) => ElevatedButton.icon(
                  onPressed: () {
                    unawaited(_shareImage(buttonContext));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: const Text('Compartilhar imagem'),
                ),
              ),
              if (_service.canDownload) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(_downloadImage());
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Baixar imagem'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(_copyLink());
                },
                icon: const Icon(Icons.link_rounded, size: 20),
                label: const Text('Copiar link'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = _png != null && !_busy;

    return AppScaffold(
      title: 'Compartilhar resultado',
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Meu resultado em uma imagem.',
                    style: textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Escolha o resultado, as cores e o formato.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                ResultShareControls(
                  data: _data,
                  format: _format,
                  palette: _palette,
                  rankingVariant: _rankingVariant,
                  enabled: !_busy && _fontsReady,
                  onVariantChanged: _selectVariant,
                  onFormatChanged: _selectFormat,
                  onPaletteChanged: _selectPalette,
                ),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: _format == ResultShareFormat.story ? 252 : 304,
                    child: AspectRatio(
                      aspectRatio: _format.aspectRatio,
                      child: FittedBox(
                        child: !_fontsReady
                            ? SizedBox(
                                width: 360,
                                height: _format.height,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : RepaintBoundary(
                                key: _cardKey,
                                child: ResultShareCard(
                                  data: _data,
                                  format: _format,
                                  palette: _palette,
                                  pattern: _pattern,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_format.resolution,
                    textAlign: TextAlign.center, style: textTheme.bodySmall),
                const SizedBox(height: 20),
                if (_imageFailed)
                  Column(
                    children: [
                      const Text('Não foi possível preparar a imagem.'),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _imageFailed = false);
                          _queueImage();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                else
                  Builder(
                    builder: (buttonContext) => ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      onPressed:
                          ready ? () => _shareImage(buttonContext) : null,
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: Text(_png == null
                          ? 'Preparando imagem…'
                          : 'Compartilhar imagem'),
                    ),
                  ),
                if (_service.canDownload) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: ready ? _downloadImage : null,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Baixar imagem'),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NetworkButton(
                      label: 'Instagram',
                      detail: 'Imagem',
                      icon: const Icon(Icons.camera_alt_outlined),
                      onPressed: ready ? _instagramHelp : null,
                    ),
                    _NetworkButton(
                      label: 'X / Twitter',
                      detail: 'Texto e link',
                      icon: const Text('X',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      onPressed: () => _openNetwork(ResultShareNetwork.twitter),
                    ),
                    _NetworkButton(
                      label: 'WhatsApp',
                      detail: 'Texto e link',
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      onPressed: () =>
                          _openNetwork(ResultShareNetwork.whatsapp),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Para enviar a imagem ao X ou WhatsApp, '
                  'use Compartilhar imagem${_service.canDownload ? ' ou Baixar imagem' : ''}.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                const Divider(color: AppTheme.outlineVariant),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.link_rounded, size: 20),
                  label: const Text('Copiar link'),
                ),
                SelectableText(_data.siteUrl,
                    textAlign: TextAlign.center, style: textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkButton extends StatelessWidget {
  const _NetworkButton({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
