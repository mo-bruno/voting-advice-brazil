import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

import 'result_share_data.dart';

class _Image {
  _Image(this.png, this.file, this.format, {this.instagram, this.whatsapp});
  final web.Blob png;
  final web.File file;
  final ResultShareFormat format;
  final web.File? instagram;
  final web.File? whatsapp;
}

bool get _appleMobile =>
    RegExp('iPhone|iPad|iPod').hasMatch(web.window.navigator.userAgent) ||
    (web.window.navigator.userAgent.contains('Macintosh') &&
        web.window.navigator.maxTouchPoints > 1);

bool get canCopyImage =>
    web.window.isSecureContext &&
    web.window.has('ClipboardItem') &&
    web.window.navigator.has('clipboard') &&
    web.window.navigator.clipboard.has('write');

Future<Object?> prepare(Uint8List bytes, ResultShareFormat format) async {
  final png = web.Blob(
      <JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final file = web.File(<JSAny>[png].toJS, format.fileName,
      web.FilePropertyBag(type: 'image/png'));
  if (!_appleMobile) return _Image(png, file, format);
  // Exclusive extensions are an iOS experiment. Build real JPEG data first;
  // PNG remains ready even if canvas conversion is unavailable.
  final url = web.URL.createObjectURL(png);
  try {
    final image = web.HTMLImageElement();
    final loaded = Completer<void>();
    image.onload = ((web.Event event) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS;
    image.onerror = ((web.Event event) {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('JPEG indisponível'));
      }
    }).toJS;
    image.src = url;
    await loaded.future.timeout(const Duration(seconds: 8));
    final canvas = web.HTMLCanvasElement()
      ..width = image.naturalWidth
      ..height = image.naturalHeight;
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    context.drawImage(image, 0, 0);
    final encoded = Completer<web.Blob?>();
    canvas.toBlob(
        ((web.Blob? blob) {
          if (!encoded.isCompleted) encoded.complete(blob);
        }).toJS,
        'image/jpeg',
        0.94.toJS);
    final jpeg = await encoded.future.timeout(const Duration(seconds: 8));
    if (jpeg == null || jpeg.type != 'image/jpeg') {
      return _Image(png, file, format);
    }
    final stem = format.fileName.replaceFirst(RegExp(r'\.png$'), '');
    web.File exclusive(String extension) => web.File(<JSAny>[jpeg].toJS,
        '$stem.$extension', web.FilePropertyBag(type: 'image/jpeg'));
    return _Image(png, file, format,
        instagram: exclusive('igo'), whatsapp: exclusive('wai'));
  } catch (_) {
    return _Image(png, file, format);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

Future<ShareResult> share(Object payload, ResultShareNetwork? network,
    {String? text}) async {
  final image = payload as _Image;
  final navigator = web.window.navigator;
  if (!navigator.has('share')) {
    throw UnsupportedError('Compartilhamento indisponível neste navegador.');
  }
  web.File file = image.file;
  final exclusive = switch (network) {
    ResultShareNetwork.instagram when image.format == ResultShareFormat.post =>
      image.instagram,
    ResultShareNetwork.whatsapp => image.whatsapp,
    _ => null,
  };
  if (exclusive != null &&
      navigator.has('canShare') &&
      navigator.canShare(web.ShareData(files: [exclusive].toJS))) {
    file = exclusive;
  }
  final data = web.ShareData(files: [file].toJS);
  // File + text can lose the image in iOS receivers. The caption remains
  // available via the explicit text/link action in the alternatives sheet.
  if (!_appleMobile && text != null) data.text = text;
  try {
    // This call occurs BEFORE the first await, in the original click gesture.
    await navigator.share(data).toDart;
    return const ShareResult('', ShareResultStatus.success);
  } catch (error) {
    String? name;
    try {
      name = (error as JSObject).getProperty<JSString?>('name'.toJS)?.toDart;
    } catch (_) {}
    if (name == 'AbortError') {
      return const ShareResult('', ShareResultStatus.dismissed);
    }
    rethrow;
  }
}

Future<void> copyImage(Object payload) {
  if (!canCopyImage) throw UnsupportedError('Copiar imagem indisponível.');
  final items = JSObject()
    ..setProperty('image/png'.toJS, (payload as _Image).png);
  // Use the prepared Blob, without awaiting PNG encoding or other APIs first.
  return web.window.navigator.clipboard
      .write([web.ClipboardItem(items)].toJS)
      .toDart;
}
