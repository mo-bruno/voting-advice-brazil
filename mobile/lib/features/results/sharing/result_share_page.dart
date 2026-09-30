import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/layout/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import 'result_share_card.dart';
import 'result_share_controls.dart';
import 'result_share_data.dart';
import 'result_share_palette.dart';
import 'result_share_service.dart';

class ResultSharePage extends StatefulWidget {
  const ResultSharePage({super.key, required this.data, this.service});

  final ResultShareData data;
  final ResultShareService? service;

  @override
  State<ResultSharePage> createState() => _ResultSharePageState();
}

class _ResultSharePageState extends State<ResultSharePage> {
  static int? _lastBeamAngle;

  static double _drawBeamAngle() {
    // Uma composição por abertura. Distância mínima evita duas imagens
    // praticamente iguais em compartilhamentos consecutivos.
    final options = List.generate(61, (index) => index + 10)
        .where((angle) =>
            _lastBeamAngle == null || (angle - _lastBeamAngle!).abs() >= 8)
        .toList();
    final angle = options[Random().nextInt(options.length)];
    _lastBeamAngle = angle;
    return angle.toDouble();
  }

  final _cardKey = GlobalKey();
  late final _service = widget.service ?? ResultShareService();
  late ResultShareData _data = widget.data;
  ResultSharePalette _palette = ResultSharePalette
      .values[Random().nextInt(ResultSharePalette.values.length)];
  final double _beamAngle = _drawBeamAngle();
  ResultShareVariant _rankingVariant = ResultShareVariant.topFive;
  ResultShareFormat _format = ResultShareFormat.story;
  Uint8List? _png;
  PreparedResultShareImage? _prepared;
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
        final png = bytes.buffer.asUint8List();
        final prepared = await _service.prepareImage(png, _format);
        if (!mounted || generation != _generation) return;
        setState(() {
          _png = png;
          _prepared = prepared;
        });
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
      _prepared = null;
      _imageFailed = false;
    });
    _queueImage();
  }

  void _notify(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _shareImage(BuildContext buttonContext,
      {ResultShareNetwork? network}) async {
    final image = _prepared;
    if (image == null || _busy) return;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    var failed = false;
    try {
      final result = await _service.sharePrepared(image, network, origin,
          text: network == ResultShareNetwork.whatsapp ||
                  network == ResultShareNetwork.twitter
              ? '${_data.caption}\n${_data.siteUrl}'
              : null);
      failed = result.status == ShareResultStatus.unavailable;
      // Fechar o menu ou escolher um app não confirma uma publicação.
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && failed) _shareOptions(network: network, unavailable: true);
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
      await _service.openNetwork(_data, network, format: _format);
    } catch (_) {
      _notify('Não foi possível abrir a rede social. Use Compartilhar imagem '
          'ou Copiar link.');
    }
  }

  Future<bool> _copyImage() async {
    final image = _prepared;
    if (image == null || _busy) return false;
    setState(() => _busy = true);
    try {
      await _service.copyImage(image);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareOptions({ResultShareNetwork? network, bool unavailable = false}) {
    String? copyMessage;
    var copying = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Outras formas de compartilhar',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Text(
                  unavailable
                      ? 'O compartilhamento não está disponível desta forma. '
                          'Tente a imagem padrão, copie ou salve para adicionar no app.'
                      : 'Copie ou salve o banner e adicione no app. '
                          'Você também pode enviar apenas o texto e o link.',
                ),
                const SizedBox(height: 12),
                if (network == null || network == ResultShareNetwork.instagram)
                  const Text('Nos Stories, use o adesivo “Link” com o endereço '
                      'do site. A imagem copiada ou salva pode ser adicionada no editor.'),
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
                if (_service.canCopyImage) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: copying
                        ? null
                        : () async {
                            setSheetState(() => copying = true);
                            final copied = await _copyImage();
                            if (!sheetContext.mounted) return;
                            setSheetState(() {
                              copying = false;
                              copyMessage = copied
                                  ? 'Imagem copiada. Abra o app abaixo e cole na publicação ou conversa.'
                                  : 'Não foi possível copiar. Tente compartilhar ou baixar a imagem.';
                            });
                          },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    label: Text(copying ? 'Copiando imagem…' : 'Copiar imagem'),
                  ),
                  if (copyMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(copyMessage!, semanticsLabel: copyMessage),
                  ],
                ],
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
                for (final destination
                    in network == null ? ResultShareNetwork.values : [network])
                  TextButton.icon(
                    onPressed: () {
                      unawaited(_openNetwork(destination));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: Text(switch (destination) {
                      ResultShareNetwork.instagram =>
                        _format == ResultShareFormat.story
                            ? 'Abrir Instagram Stories'
                            : 'Abrir Instagram',
                      ResultShareNetwork.twitter => 'Abrir X com texto',
                      ResultShareNetwork.whatsapp => 'Abrir WhatsApp',
                    }),
                  ),
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
                                  beamAngle: _beamAngle,
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
                    Builder(
                        builder: (buttonContext) => _NetworkButton(
                              label: 'Instagram',
                              detail: _format == ResultShareFormat.story
                                  ? 'Story'
                                  : 'Post',
                              icon: const Icon(Icons.camera_alt_outlined),
                              onPressed: ready
                                  ? () => _shareImage(buttonContext,
                                      network: ResultShareNetwork.instagram)
                                  : null,
                            )),
                    Builder(
                        builder: (buttonContext) => _NetworkButton(
                              label: 'X / Twitter',
                              detail: 'Imagem',
                              icon: const Text('X',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700)),
                              onPressed: ready
                                  ? () => _shareImage(buttonContext,
                                      network: ResultShareNetwork.twitter)
                                  : null,
                            )),
                    Builder(
                      builder: (buttonContext) => _NetworkButton(
                        label: 'WhatsApp',
                        detail: 'Imagem',
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        onPressed: ready
                            ? () => _shareImage(buttonContext,
                                network: ResultShareNetwork.whatsapp)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Escolha o app no menu do celular para continuar com a imagem.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: ready ? () => _shareOptions() : null,
                  child: const Text('Mais opções'),
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
