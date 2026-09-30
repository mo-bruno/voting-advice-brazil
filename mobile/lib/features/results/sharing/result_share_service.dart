import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
