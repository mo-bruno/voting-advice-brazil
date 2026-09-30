import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'result_share_data.dart';
import 'result_share_browser_stub.dart'
    if (dart.library.js_interop) 'result_share_browser.dart' as browser;

class PreparedResultShareImage {
  const PreparedResultShareImage(this.png, this.format, this.browserPayload);
  final Uint8List png;
  final ResultShareFormat format;
  final Object? browserPayload;
}

class ResultShareService {
  ResultShareService({Future<ShareResult> Function(ShareParams)? share})
      : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams) _share;

  bool get canDownload => kIsWeb;
  bool get canCopyImage => browser.canCopyImage;

  Future<PreparedResultShareImage> prepareImage(
          Uint8List png, ResultShareFormat format) async =>
      PreparedResultShareImage(png, format, await browser.prepare(png, format));

  Future<ShareResult> sharePrepared(
      PreparedResultShareImage image, ResultShareNetwork? network, Rect origin,
      {String? text}) {
    final payload = image.browserPayload;
    return payload != null
        ? browser.share(payload, network, text: text)
        : shareImage(image.png, image.format, origin, text: text);
  }

  Future<void> copyImage(PreparedResultShareImage image) {
    final payload = image.browserPayload;
    if (payload == null) throw UnsupportedError('Copiar imagem indisponível.');
    return browser.copyImage(payload);
  }

  XFile _file(Uint8List bytes, ResultShareFormat format) => XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: format.fileName,
      );

  Future<ShareResult> shareImage(
    Uint8List bytes,
    ResultShareFormat format,
    Rect origin, {
    String? text,
  }) =>
      _share(ShareParams(
        files: [_file(bytes, format)],
        text: text,
        fileNameOverrides: [format.fileName],
        sharePositionOrigin: origin,
        // A legenda é opcional: o botão geral envia só a imagem para manter
        // compatibilidade com destinos que rejeitam arquivo + texto.
        downloadFallbackEnabled: false,
      ));

  Future<void> downloadImage(Uint8List bytes, ResultShareFormat format) {
    if (!canDownload) {
      throw UnsupportedError('Use o menu de compartilhamento para salvar.');
    }
    final file = _file(bytes, format);
    return file.saveTo(format.fileName);
  }

  Future<void> copyLink(ResultShareData data) =>
      Clipboard.setData(ClipboardData(text: data.siteUrl));

  Future<void> openNetwork(
    ResultShareData data,
    ResultShareNetwork network, {
    ResultShareFormat format = ResultShareFormat.story,
  }) async {
    final opened = await launchUrl(
      data.networkUri(network, format: format),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw StateError('Não foi possível abrir a rede social.');
  }
}
