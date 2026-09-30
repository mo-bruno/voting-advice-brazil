import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/analytics/analytics_failure_classifier.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/layout/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import 'result_share_card.dart';
import 'result_share_controls.dart';
import 'result_share_data.dart';
import 'result_share_palette.dart';
import 'result_share_service.dart';

class ResultSharePage extends StatefulWidget {
  const ResultSharePage({
    super.key,
    required this.data,
    this.service,
    this.analytics,
    this.imageRenderer,
  });

  final ResultShareData data;
  final ResultShareService? service;
  final AnalyticsService? analytics;
  final Future<Uint8List> Function()? imageRenderer;

  @override
  State<ResultSharePage> createState() => _ResultSharePageState();
}

final class _RenderAttempt {
  _RenderAttempt({
    required this.generation,
    required this.trigger,
  }) : stopwatch = Stopwatch()..start();

  final int generation;
  final AnalyticsTrigger trigger;
  final Stopwatch stopwatch;
  bool isTerminal = false;
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
  late final AnalyticsService _analytics =
      widget.analytics ?? AnalyticsService();
  late ResultShareData _data = widget.data;
  ResultSharePalette _palette = ResultSharePalette
      .values[Random().nextInt(ResultSharePalette.values.length)];
  final double _beamAngle = _drawBeamAngle();
  ResultShareVariant _rankingVariant = ResultShareVariant.topFive;
  ResultShareFormat _format = ResultShareFormat.story;
  Uint8List? _png;
  bool _imageFailed = false;
  bool _fontsReady = false;
  bool _busy = false;
  int _generation = 0;
  _RenderAttempt? _renderAttempt;

  @override
  void initState() {
    super.initState();
    _queueImage(AnalyticsTrigger.initial);
  }

  @override
  void dispose() {
    _generation++;
    final attempt = _renderAttempt;
    if (attempt != null) {
      _finishRender(attempt, AnalyticsOutcome.stale);
    }
    super.dispose();
  }

  void _track(Future<void> Function() event) {
    try {
      unawaited(event().catchError((_) {}));
    } catch (_) {
      // Métricas nunca podem impedir a ação escolhida pela pessoa.
    }
  }

  void _trackShare(
    AnalyticsTarget target, {
    AnalyticsOutcome? outcome,
  }) {
    _track(() => _analytics.engagementAction(
          action: AnalyticsAction.share,
          surface: AnalyticsSurface.results,
          target: target,
          outcome: outcome,
        ));
  }

  void _finishRender(
    _RenderAttempt attempt,
    AnalyticsOutcome outcome, {
    AnalyticsFailureType? failureType,
  }) {
    if (attempt.isTerminal) return;
    attempt.isTerminal = true;
    attempt.stopwatch.stop();
    if (identical(_renderAttempt, attempt)) _renderAttempt = null;
    _track(() => _analytics.operationResult(
          operation: AnalyticsOperation.shareRender,
          outcome: outcome,
          trigger: attempt.trigger,
          failureType: failureType,
          durationMs: attempt.stopwatch.elapsedMilliseconds,
        ));
  }

  bool _isCurrent(_RenderAttempt attempt) =>
      mounted && !attempt.isTerminal && attempt.generation == _generation;

  void _queueImage(AnalyticsTrigger trigger) {
    final previous = _renderAttempt;
    if (previous != null) {
      _finishRender(previous, AnalyticsOutcome.stale);
    }
    final attempt = _RenderAttempt(
      generation: ++_generation,
      trigger: trigger,
    );
    _renderAttempt = attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
        return;
      }
      unawaited(_prepareImage(attempt));
    });
  }

  Future<Uint8List> _captureImage() async {
    final boundary =
        _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Imagem indisponível');
      return bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  }

  Future<void> _waitForNextFrame() {
    final frame = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => frame.complete());
    WidgetsBinding.instance.scheduleFrame();
    return frame.future;
  }

  Future<void> _waitForRouteTransition() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      return Future<void>.value();
    }
    final transition = Completer<void>();
    void onStatus(AnimationStatus status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeStatusListener(onStatus);
        if (!transition.isCompleted) transition.complete();
      }
    }

    animation.addStatusListener(onStatus);
    return transition.future;
  }

  Future<void> _prepareImage(_RenderAttempt attempt) async {
    try {
      await ResultShareCard.loadFonts();
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
        return;
      }
      // Prepara o PNG antes do toque para preservar o gesto do usuário que
      // os navegadores exigem para abrir o menu nativo de compartilhamento.
      if (!_fontsReady) setState(() => _fontsReady = true);
      await _waitForRouteTransition();
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
        return;
      }
      await _waitForNextFrame();
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
        return;
      }
      final bytes = await (widget.imageRenderer?.call() ?? _captureImage());
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
        return;
      }
      if (bytes.isEmpty) throw StateError('Imagem vazia');
      setState(() => _png = bytes);
      _finishRender(attempt, AnalyticsOutcome.success);
    } catch (error) {
      if (!_isCurrent(attempt)) {
        _finishRender(attempt, AnalyticsOutcome.stale);
      } else {
        setState(() => _imageFailed = true);
        _finishRender(
          attempt,
          AnalyticsOutcome.failed,
          failureType: classifyAnalyticsFailure(error),
        );
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
    _queueImage(AnalyticsTrigger.refresh);
  }

  void _notify(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _shareImage(BuildContext buttonContext,
      {bool forWhatsApp = false}) async {
    final bytes = _png;
    if (bytes == null || _busy) return;
    final sharedData = _data;
    final target =
        forWhatsApp ? AnalyticsTarget.whatsapp : AnalyticsTarget.nativeShare;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await _service.shareImage(bytes, _format, origin,
          text: forWhatsApp
              ? '${sharedData.caption}\n${sharedData.siteUrl}'
              : null);
      _trackShare(target, outcome: AnalyticsOutcome.success);
      // Fechar o menu ou escolher um app não confirma uma publicação.
    } catch (_) {
      _trackShare(target, outcome: AnalyticsOutcome.failed);
      final action = forWhatsApp
          ? SnackBarAction(
              label: 'Abrir WhatsApp',
              onPressed: () => unawaited(
                  _openNetwork(ResultShareNetwork.whatsapp, data: sharedData)),
            )
          : null;
      _notify(
          forWhatsApp
              ? 'Não foi possível enviar imagem e texto juntos. '
                  'Use Compartilhar imagem e abra a mensagem no WhatsApp.'
              : 'Não foi possível compartilhar a imagem. Tente novamente.',
          action: action);
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
      _trackShare(
        AnalyticsTarget.download,
        outcome: AnalyticsOutcome.success,
      );
      _notify('Download iniciado. Sua imagem está pronta para anexar.');
    } catch (_) {
      _trackShare(
        AnalyticsTarget.download,
        outcome: AnalyticsOutcome.failed,
      );
      _notify('Não foi possível baixar a imagem. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyLink() async {
    try {
      await _service.copyLink(_data);
      _trackShare(
        AnalyticsTarget.copyLink,
        outcome: AnalyticsOutcome.success,
      );
      _notify('Link copiado. Cole na publicação ou no adesivo de link.');
    } catch (_) {
      _trackShare(
        AnalyticsTarget.copyLink,
        outcome: AnalyticsOutcome.failed,
      );
      _notify('Não foi possível copiar. Selecione o endereço no fim da tela.');
    }
  }

  Future<void> _openNetwork(ResultShareNetwork network,
      {ResultShareData? data}) async {
    final target = switch (network) {
      ResultShareNetwork.twitter => AnalyticsTarget.twitter,
      ResultShareNetwork.whatsapp => AnalyticsTarget.whatsapp,
    };
    try {
      await _service.openNetwork(data ?? _data, network);
      _trackShare(target, outcome: AnalyticsOutcome.success);
    } catch (_) {
      _trackShare(target, outcome: AnalyticsOutcome.failed);
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
    _trackShare(AnalyticsTarget.instagramHelp);
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
                          _queueImage(AnalyticsTrigger.retry);
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
                    Builder(
                      builder: (buttonContext) => _NetworkButton(
                        label: 'WhatsApp',
                        detail: 'Imagem e texto',
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        onPressed: ready
                            ? () =>
                                _shareImage(buttonContext, forWhatsApp: true)
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'No menu, escolha o WhatsApp. Para enviar a imagem ao X, '
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
