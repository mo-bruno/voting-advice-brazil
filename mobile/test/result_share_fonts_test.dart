import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('permite tentar novamente após uma falha temporária ao carregar fontes',
      () async {
    const semiBold = 'assets/fonts/BarlowCondensed-SemiBold.ttf';
    const extraBold = 'assets/fonts/BarlowCondensed-ExtraBold.ttf';
    final assets = {
      semiBold: await rootBundle.load(semiBold),
      extraBold: await rootBundle.load(extraBold),
    };
    var semiBoldRequests = 0;
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets',
        (message) async {
      final key = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (key == semiBold && ++semiBoldRequests == 1) return null;
      return assets[key];
    });
    addTearDown(() => binding.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null));

    await expectLater(
        ResultShareCard.loadFonts(), throwsA(isA<FlutterError>()));
    await expectLater(ResultShareCard.loadFonts(), completes);
    expect(semiBoldRequests, 2);
    await ResultShareCard.loadFonts();
    expect(semiBoldRequests, 2, reason: 'a fonte já carregada fica em cache');
  });
}
