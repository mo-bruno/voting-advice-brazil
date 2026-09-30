import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_data.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_page.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_palette.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_service.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:share_plus/share_plus.dart';

class _ShareDevice extends ResultShareService {
  _ShareDevice({this.failSharing = false});

  final bool failSharing;
  Uint8List? shared;
  Uint8List? downloaded;
  int downloads = 0;
  String? copied;
  final networks = <ResultShareNetwork>[];
  ResultShareData? networkData;

  @override
  bool get canDownload => true;

  @override
  Future<ShareResult> shareImage(
    Uint8List bytes,
    ResultShareFormat format,
    Rect origin,
  ) async {
    if (failSharing) throw UnsupportedError('Sem menu nativo neste navegador');
    shared = bytes;
    return const ShareResult('', ShareResultStatus.dismissed);
  }

  @override
  Future<void> downloadImage(Uint8List bytes, ResultShareFormat format) async {
    downloaded = bytes;
    downloads++;
  }

  @override
  Future<void> copyLink(ResultShareData data) async => copied = data.siteUrl;

  @override
  Future<void> openNetwork(
      ResultShareData data, ResultShareNetwork network) async {
    networks.add(network);
    networkData = data;
  }
}

void main() {
  final data = ResultShareData(
    results: const [
      CandidateResult(
        candidateId: '1',
        name: 'Marina de Albuquerque Silva',
        party: 'PSD',
        scorePercent: 87.5,
        rank: 1,
        matches: [],
        countedTheses: 10,
        answeredTheses: 30,
        comparableCategories: 5,
        documentedTheses: 14,
        documentedCategories: 8,
        rankingStatus: 'eligible',
        rankingEligible: true,
      )
    ],
    publicUrl: 'https://exemplo.com.br',
  );
  final rankingData = ResultShareData(
    results: List.generate(
        12,
        (index) => CandidateResult(
              candidateId: '${index + 1}',
              name: 'Pessoa ${index + 1}',
              party: 'PSD',
              scorePercent: 95 - index * 5,
              rank: index + 1,
              matches: const [],
              countedTheses: 20,
              answeredTheses: 30,
              comparableCategories: 6,
              documentedTheses: 20,
              documentedCategories: 6,
              rankingStatus: 'eligible',
              rankingEligible: true,
            )),
  );

  Future<Color> imageBackground(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      final bytes = (await frame.image.toByteData())!;
      return Color.fromARGB(bytes.getUint8(3), bytes.getUint8(0),
          bytes.getUint8(1), bytes.getUint8(2));
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  Future<int> whiteLogoPixels(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    try {
      final bytes = (await frame.image.toByteData())!;
      var count = 0;
      // Marca de 24 px no canto (28, 48), exportada em escala 3x.
      for (var y = 144; y < 216; y++) {
        for (var x = 84; x < 156; x++) {
          final offset = (y * frame.image.width + x) * 4;
          if (bytes.getUint8(offset) == 255 &&
              bytes.getUint8(offset + 1) == 255 &&
              bytes.getUint8(offset + 2) == 255) {
            count++;
          }
        }
      }
      return count;
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  Future<void> waitForImage(WidgetTester tester) async {
    // A rasterização/PNG usa a engine, fora do relógio virtual do widget test.
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      if (find.text('Preparando imagem…').evaluate().isEmpty) break;
    }
    expect(find.text('Não foi possível preparar a imagem.'), findsNothing);
    expect(find.text('Compartilhar imagem'), findsOneWidget);
  }

  Future<void> pumpPage(WidgetTester tester, _ShareDevice device,
      {ResultShareData? shareData}) async {
    await tester.runAsync(ResultShareCard.loadFonts);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ResultSharePage(data: shareData ?? data, service: device),
    ));
    await waitForImage(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  void expectPng(Uint8List? image, int width, int height) {
    expect(image, isNotNull);
    expect(image!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(image);
    expect(header.getUint32(16), width);
    expect(header.getUint32(20), height);
  }

  testWidgets('exporta Stories e Post nas dimensões certas após trocar formato',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1920);
    await tap(tester, 'Post · 4:5');
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1350);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oferece escolha de conteúdo e de cores para a imagem',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    expect(find.text('Maior alinhamento'), findsOneWidget);
    expect(find.text('Ranking'), findsOneWidget);
    for (final color in [
      'Azul',
      'Roxo',
      'Verde',
      'Coral',
      'Vermelho',
      'Laranja',
      'Amarelo',
      'Rosa',
      'Ciano',
      'Preto',
      'Branco',
      'Marrom'
    ]) {
      expect(find.byTooltip(color), findsOneWidget);
    }
    expect(find.text('Edição 2026'), findsOneWidget);
  });

  testWidgets('imagem mostra colocação e base comparável sem percentual',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);

    expect(find.text('1º lugar'), findsOneWidget);
    expect(
      find.text('Base: 10 de 30 respostas comparáveis · 5 categorias'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('exporta a marca branca sem herdar o acento da paleta',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    await tester.ensureVisible(find.byTooltip('Azul'));
    await tester.tap(find.byTooltip('Azul'));
    await tester.pump();
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expect(await tester.runAsync(() => whiteLogoPixels(device.downloaded!)),
        greaterThan(100));
  });

  testWidgets('a composição não muda ao personalizar e voltar às mesmas opções',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    final initialPalette =
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).palette;
    await tap(tester, 'Baixar imagem');
    final original = device.downloaded!;
    final otherPalette = initialPalette == ResultSharePalette.green
        ? ResultSharePalette.blue
        : ResultSharePalette.green;
    await tester.ensureVisible(find.byTooltip(otherPalette.label));
    await tester.tap(find.byTooltip(otherPalette.label));
    await tester.pump();
    await waitForImage(tester);
    await tap(tester, 'Post · 4:5');
    await waitForImage(tester);
    await tap(tester, 'Stories · 9:16');
    await waitForImage(tester);
    await tester.ensureVisible(find.byTooltip(initialPalette.label));
    await tester.tap(find.byTooltip(initialPalette.label));
    await tester.pump();
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expect(device.downloaded, orderedEquals(original));
    await tap(tester, 'Compartilhar imagem');
    expect(device.shared, orderedEquals(original));
  });

  testWidgets('um novo compartilhamento recebe outra direção dentro do card',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    final first =
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).beamAngle;
    expect(first, inInclusiveRange(10, 70));
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, device);
    final next =
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).beamAngle;
    expect(next, inInclusiveRange(10, 70));
    expect((next - first).abs(), greaterThanOrEqualTo(8));
  });

  testWidgets('exporta top 5 e top 10 e leva a seleção para a legenda',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device, shareData: rankingData);
    await tap(tester, 'Ranking');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade · Beta'), findsOneWidget);
    expect(find.text('Pessoa 5'), findsOneWidget);
    expect(find.text('Pessoa 6'), findsNothing);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1920);
    final topFiveImage = device.downloaded;

    await tap(tester, 'Top 10');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade · Beta'), findsOneWidget);
    expect(find.text('Pessoa 10'), findsOneWidget);
    expect(find.text('Pessoa 11'), findsNothing);
    await tap(tester, 'Post · 4:5');
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1350);
    expect(device.downloaded, isNot(topFiveImage));
    await tap(tester, 'WhatsApp');
    expect(device.networkData!.caption, contains('10º. Pessoa 10'));
    expect(device.networkData!.caption, isNot(contains('Pessoa 11')));

    await tap(tester, 'Maior alinhamento');
    await waitForImage(tester);
    expect(find.text('Pessoa 1'), findsOneWidget);
    expect(find.text('Pessoa 2'), findsNothing);
    await tap(tester, 'Ranking');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade · Beta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking curto mostra a quantidade real sem posições vazias',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device,
        shareData:
            ResultShareData(results: rankingData.results.take(3).toList()));
    await tap(tester, 'Ranking');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade · Beta'), findsOneWidget);
    expect(find.text('Pessoa 4'), findsNothing);
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Top 10'))
            .onSelected,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar numa paleta atualiza a cor do PNG exportado',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    await tester.ensureVisible(find.byTooltip('Roxo'));
    await tester.tap(find.byTooltip('Roxo'));
    await tester.pump();
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expect(await tester.runAsync(() => imageBackground(device.downloaded!)),
        const Color(0xFF532B9C));

    await tester.ensureVisible(find.byTooltip('Verde'));
    await tester.tap(find.byTooltip('Verde'));
    await tester.pump();
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expect(await tester.runAsync(() => imageBackground(device.downloaded!)),
        const Color(0xFF075D50));
    expect(find.text('Personalizar cores'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar o menu não baixa arquivo nem anuncia publicação',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    await tap(tester, 'Compartilhar imagem');
    expectPng(device.shared, 1080, 1920);
    expect(device.downloads, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('navegador sem compartilhamento recebe download da imagem',
      (tester) async {
    final device = _ShareDevice(failSharing: true);
    await pumpPage(tester, device);
    await tap(tester, 'Compartilhar imagem');
    expectPng(device.downloaded, 1080, 1920);
    expect(find.text('Download iniciado. Anexe a imagem na rede social.'),
        findsOneWidget);
  });

  testWidgets('atalhos usam a rede escolhida e permitem copiar o domínio',
      (tester) async {
    final device = _ShareDevice();
    await pumpPage(tester, device);
    await tap(tester, 'X / Twitter');
    await tap(tester, 'WhatsApp');
    expect(device.networks,
        [ResultShareNetwork.twitter, ResultShareNetwork.whatsapp]);
    await tap(tester, 'Copiar link');
    expect(device.copied, 'https://exemplo.com.br');
    await tap(tester, 'Instagram');
    expect(find.text('Leve para o Instagram'), findsOneWidget);
    expect(find.textContaining('adesivo “Link”'), findsOneWidget);
    await tester.tap(find.text('Copiar link').last);
    await tester.pumpAndSettle();
    expect(find.text('Leve para o Instagram'), findsNothing);
    expect(find.text('Link copiado. Cole na publicação ou no adesivo de link.'),
        findsOneWidget);
  });

  testWidgets('cabe em celular estreito com texto ampliado e nome longo',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final device = _ShareDevice();
    await tester.runAsync(ResultShareCard.loadFonts);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
        child: child!,
      ),
      home: ResultSharePage(data: rankingData, service: device),
    ));
    await waitForImage(tester);
    await tap(tester, 'Post · 4:5');
    await tap(tester, 'Ranking');
    await tap(tester, 'Top 10');
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1350);
    expect(tester.takeException(), isNull);
  });
}
