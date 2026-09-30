import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_data.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_service.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test(
      'imagem preparada mantém o PNG e invoca compartilhamento no próprio gesto',
      () async {
    var invoked = false;
    final service = ResultShareService(share: (params) {
      invoked = true;
      expect(params.text, 'Legenda e link');
      return Future.value(const ShareResult('', ShareResultStatus.dismissed));
    });
    final png = Uint8List.fromList([137, 80, 78, 71]);
    final prepared = await service.prepareImage(png, ResultShareFormat.post);
    expect(prepared.png, same(png));
    expect(prepared.format, ResultShareFormat.post);
    final result = service.sharePrepared(prepared, ResultShareNetwork.twitter,
        const Rect.fromLTWH(0, 0, 100, 48),
        text: 'Legenda e link');
    expect(invoked, isTrue);
    expect((await result).status, ShareResultStatus.dismissed);
  });
  test('envia o PNG sozinho com nome, formato e origem do menu do iPad',
      () async {
    ShareParams? sent;
    final service = ResultShareService(share: (params) async {
      sent = params;
      return const ShareResult('', ShareResultStatus.dismissed);
    });
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final result = await service.shareImage(
      bytes,
      ResultShareFormat.post,
      const Rect.fromLTWH(20, 40, 200, 48),
    );
    expect(await sent!.files!.single.readAsBytes(), bytes);
    expect(sent!.files!.single.mimeType, 'image/png');
    expect(sent!.fileNameOverrides, ['meu-resultado-farol-post.png']);
    expect(sent!.sharePositionOrigin, const Rect.fromLTWH(20, 40, 200, 48));
    expect(sent!.text, isNull);
    expect(sent!.uri, isNull);
    expect(sent!.downloadFallbackEnabled, isFalse);
    expect(result.status, ShareResultStatus.dismissed);
  });
}
