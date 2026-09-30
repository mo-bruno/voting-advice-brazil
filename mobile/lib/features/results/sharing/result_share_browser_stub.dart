import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'result_share_data.dart';

bool get canCopyImage => false;

Future<Object?> prepare(Uint8List png, ResultShareFormat format) async => null;

Future<ShareResult> share(Object payload, ResultShareNetwork? network,
        {String? text}) =>
    throw UnsupportedError('Compartilhamento do navegador indisponível.');

Future<void> copyImage(Object payload) =>
    throw UnsupportedError('Copiar imagem indisponível.');
