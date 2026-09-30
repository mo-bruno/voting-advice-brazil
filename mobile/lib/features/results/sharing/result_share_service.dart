import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'result_share_data.dart';

class ResultShareService {
  ResultShareService({Future<ShareResult> Function(ShareParams)? share})
      : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams) _share;

  bool get canDownload => kIsWeb;

  XFile _file(Uint8List bytes, ResultShareFormat format) => XFile.fromData(
        bytes,
        mimeType: 'image/png',
        name: format.fileName,
      );

  Future<ShareResult> shareImage(
    Uint8List bytes,
    ResultShareFormat format,
    Rect origin,
  ) =>
      _share(ShareParams(
        files: [_file(bytes, format)],
        fileNameOverrides: [format.fileName],
        sharePositionOrigin: origin,
        // Envia somente o PNG. Texto + arquivo pode perder a imagem no destino.
        // A tela oferece salvar em um novo gesto quando o navegador recusa.
        downloadFallbackEnabled: false,
      ));

  Future<void> downloadImage(Uint8List bytes, ResultShareFormat format) {
    if (!canDownload) {
      throw UnsupportedError('Use o menu de compartilhamento para salvar.');
    }
    final file = _file(bytes, format);
    return file.saveTo(format.fileName);
  }

  Future<void> openNetwork(
    ResultShareData data,
    ResultShareNetwork network,
  ) async {
    final opened = await launchUrl(
      data.networkUri(network),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened) throw StateError('Não foi possível abrir a rede social.');
  }
}
