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
    required this.analytics,
  }) : stopwatch = Stopwatch()..start();

  final int generation;
  final AnalyticsTrigger trigger;
  final AnalyticsService analytics;
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
    AnalyticsService? analytics,
  }) {
    _track(() => (analytics ?? _analytics).engagementAction(
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
    _track(() => attempt.analytics.operationResult(
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
      analytics: _analytics.bindToCurrentConsent(),
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

  Future<void> _shareImage(BuildContext buttonContext) async {
    final bytes = _png;
    if (bytes == null || _busy) return;
    final format = _format;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      await _service.shareImage(bytes, format, origin);
      _trackShare(
        AnalyticsTarget.nativeShare,
        outcome: AnalyticsOutcome.success,
        analytics: attemptAnalytics,
      );
      // O navegador pode retornar status desconhecido mesmo após compartilhar.
      // Cancelar ou voltar do menu não dispara outra ação nem confirma publicação.
    } catch (_) {
      _trackShare(
        AnalyticsTarget.nativeShare,
        outcome: AnalyticsOutcome.failed,
        analytics: attemptAnalytics,
      );
      _notify(
        _service.canDownload
            ? 'Não foi possível compartilhar neste navegador. Baixe a imagem para anexar no app.'
            : 'Não foi possível compartilhar a imagem. Tente novamente.',
        action: _service.canDownload
            ? SnackBarAction(
                label: 'Baixar',
                onPressed: () => _downloadImage(bytes, format),
              )
            : null,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadImage(Uint8List bytes, ResultShareFormat format) async {
    if (_busy) return;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    setState(() => _busy = true);
    try {
      await _service.downloadImage(bytes, format);
      _trackShare(
        AnalyticsTarget.download,
        outcome: AnalyticsOutcome.success,
        analytics: attemptAnalytics,
      );
      _notify('Download iniciado. Sua imagem está pronta para anexar.');
    } catch (_) {
      _trackShare(
        AnalyticsTarget.download,
        outcome: AnalyticsOutcome.failed,
        analytics: attemptAnalytics,
      );
      _notify('Não foi possível baixar a imagem. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNetwork(ResultShareNetwork network) async {
    if (_busy) return;
    final attemptAnalytics = _analytics.bindToCurrentConsent();
    final target = switch (network) {
      ResultShareNetwork.twitter => AnalyticsTarget.twitter,
      ResultShareNetwork.whatsapp => AnalyticsTarget.whatsapp,
    };
    try {
      await _service.openNetwork(_data, network);
      _trackShare(
        target,
        outcome: AnalyticsOutcome.success,
        analytics: attemptAnalytics,
      );
    } catch (_) {
      _trackShare(
        target,
        outcome: AnalyticsOutcome.failed,
        analytics: attemptAnalytics,
      );
      _notify(
          'Não foi possível abrir a rede social. Tente novamente ou use Compartilhar imagem.');
    }
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
                      label: Text(_busy
                          ? 'Aguarde…'
                          : _png == null
                              ? 'Preparando imagem…'
                              : 'Compartilhar imagem'),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Envie o banner para qualquer app disponível no menu do celular.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NetworkButton(
                      label: 'X',
                      detail: 'Texto e link',
                      icon: const Text('X',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      onPressed: _busy
                          ? null
                          : () => _openNetwork(ResultShareNetwork.twitter),
                    ),
                    _NetworkButton(
                      label: 'WhatsApp',
                      detail: 'Texto e link',
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      onPressed: _busy
                          ? null
                          : () => _openNetwork(ResultShareNetwork.whatsapp),
                    ),
                  ],
                ),
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
