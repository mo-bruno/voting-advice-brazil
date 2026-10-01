import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_card.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_data.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_page.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_palette.dart';
import 'package:guia_eleitoral/features/results/sharing/result_share_service.dart';
import 'package:guia_eleitoral/shared/models/candidate_result.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers/analytics_test_support.dart';

class _ShareDevice extends ResultShareService {
  _ShareDevice({
    this.failSharing = false,
    this.downloadSupported = true,
    this.shareStatus = ShareResultStatus.dismissed,
    this.failDownload = false,
    this.failCopy = false,
    this.failNetwork = false,
  });

  final bool failSharing;
  final bool downloadSupported;
  final ShareResultStatus shareStatus;
  final bool failDownload;
  final bool failCopy;
  final bool failNetwork;
  Uint8List? shared;
  String? sharedText;
  Uint8List? downloaded;
  int downloads = 0;
  String? copied;
  final networks = <ResultShareNetwork>[];
  ResultShareData? networkData;

  @override
  bool get canDownload => downloadSupported;

  @override
  Future<ShareResult> shareImage(
    Uint8List bytes,
    ResultShareFormat format,
    Rect origin, {
    String? text,
  }) async {
    if (failSharing) throw UnsupportedError('Sem menu nativo neste navegador');
    shared = bytes;
    sharedText = text;
    return ShareResult('', shareStatus);
  }

  @override
  Future<void> downloadImage(Uint8List bytes, ResultShareFormat format) async {
    if (failDownload) throw StateError('Falha no download');
    downloaded = bytes;
    downloads++;
  }

  @override
  Future<void> copyLink(ResultShareData data) async {
    if (failCopy) throw StateError('Falha ao copiar');
    copied = data.siteUrl;
  }

  @override
  Future<void> openNetwork(
      ResultShareData data, ResultShareNetwork network) async {
    if (failNetwork) throw StateError('Falha ao abrir rede');
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

  Future<void> pumpPage(
    WidgetTester tester,
    ResultShareService device, {
    ResultShareData? shareData,
    RecordingAnalyticsSink? sink,
    Future<Uint8List> Function()? imageRenderer,
    bool waitForRender = true,
  }) async {
    await tester.runAsync(ResultShareCard.loadFonts);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ResultSharePage(
        data: shareData ?? data,
        service: device,
        analytics: sink == null ? null : AnalyticsService(sink: sink),
        imageRenderer: imageRenderer,
      ),
    ));
    if (waitForRender) await waitForImage(tester);
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var attempt = 0; attempt < 40 && !condition(); attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
  }

  List<RecordedAnalyticsCall> shareRenders(RecordingAnalyticsSink sink) =>
      named(sink.calls, 'operation_result')
          .where((call) => call.parameters?['operation'] == 'share_render')
          .toList();

  void expectSafeParameters(RecordedAnalyticsCall call) {
    expect(
      call.parameters?.keys,
      isNot(contains(anyOf(<String>[
        'candidate_id',
        'candidate',
        'ranking',
        'party',
        'style',
        'caption',
        'url',
        'legend',
        'direction',
        'palette',
      ]))),
    );
    expect(
      call.parameters?.values.map((value) => value.toString()),
      isNot(contains(anyOf(
        'Marina de Albuquerque Silva',
        'PSD',
        'https://exemplo.com.br',
      ))),
    );
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

  testWidgets('render inicial emite um único terminal seguro de sucesso',
      (tester) async {
    final sink = RecordingAnalyticsSink();

    await pumpPage(
      tester,
      _ShareDevice(),
      sink: sink,
      imageRenderer: () async => Uint8List.fromList([1]),
    );

    final renders = shareRenders(sink);
    expect(renders, hasLength(1));
    expect(
      renders.single.parameters,
      allOf(
        containsPair('operation', 'share_render'),
        containsPair('outcome', 'success'),
        containsPair('trigger', 'initial'),
        contains('duration_ms'),
        hasLength(4),
      ),
    );
    expectSafeParameters(renders.single);
    expect(named(sink.calls, 'screen_viewed'), isEmpty);
    expect(named(sink.calls, 'engagement_action'), isEmpty,
        reason: 'renderizar ou exibir opções não é uma ação de destino');
  });

  testWidgets('render substituído emite stale e o novo refresh emite success',
      (tester) async {
    final first = Completer<Uint8List>();
    final sink = RecordingAnalyticsSink();
    var renderCalls = 0;
    Future<Uint8List> render() {
      renderCalls++;
      if (renderCalls == 1) return first.future;
      return Future.value(Uint8List.fromList([1]));
    }

    await pumpPage(
      tester,
      _ShareDevice(),
      sink: sink,
      imageRenderer: render,
      waitForRender: false,
    );
    await pumpUntil(tester, () => renderCalls == 1);
    final currentPalette =
        tester.widget<ResultShareCard>(find.byType(ResultShareCard)).palette;
    final nextPalette = ResultSharePalette.values
        .firstWhere((palette) => palette != currentPalette);
    await tester.tap(find.byTooltip(nextPalette.label));
    await pumpUntil(
      tester,
      () => renderCalls == 2 && shareRenders(sink).length == 2,
    );

    final renders = shareRenders(sink);
    expect(
      renders.map((call) => call.parameters?['outcome']),
      containsAll(<String>['stale', 'success']),
    );
    expect(
      renders.map((call) =>
          '${call.parameters?['trigger']}:${call.parameters?['outcome']}'),
      containsAll(<String>['initial:stale', 'refresh:success']),
    );
    for (final render in renders) {
      expect(render.parameters?['operation'], 'share_render');
      expectSafeParameters(render);
    }

    first.complete(Uint8List.fromList([2]));
    await tester.pump();
    expect(shareRenders(sink), hasLength(2),
        reason: 'a conclusão tardia não pode duplicar o terminal stale');
  });

  testWidgets('desmontar encerra render pendente uma vez como stale',
      (tester) async {
    final pending = Completer<Uint8List>();
    final sink = RecordingAnalyticsSink();
    var renderStarted = false;

    await pumpPage(
      tester,
      _ShareDevice(),
      sink: sink,
      imageRenderer: () {
        renderStarted = true;
        return pending.future;
      },
      waitForRender: false,
    );
    await pumpUntil(tester, () => renderStarted);
    await tester.pumpWidget(const SizedBox());

    final render = shareRenders(sink).single;
    expect(render.parameters, containsPair('trigger', 'initial'));
    expect(render.parameters, containsPair('outcome', 'stale'));
    pending.complete(Uint8List.fromList([1]));
    await tester.pump();
    expect(shareRenders(sink), hasLength(1));
  });

  testWidgets('bytes vazios falham e tentativa manual usa trigger retry',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    var renderCalls = 0;

    await pumpPage(
      tester,
      _ShareDevice(),
      sink: sink,
      imageRenderer: () async {
        renderCalls++;
        return renderCalls == 1 ? Uint8List(0) : Uint8List.fromList([1]);
      },
      waitForRender: false,
    );
    await pumpUntil(
      tester,
      () => find
          .text('Não foi possível preparar a imagem.')
          .evaluate()
          .isNotEmpty,
    );

    expect(
      shareRenders(sink).single.parameters,
      allOf(
        containsPair('trigger', 'initial'),
        containsPair('outcome', 'failed'),
        containsPair('failure_type', 'unknown'),
      ),
    );
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await waitForImage(tester);

    expect(
      shareRenders(sink).map((call) =>
          '${call.parameters?['trigger']}:${call.parameters?['outcome']}'),
      <String>['initial:failed', 'retry:success'],
    );
  });

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
    expect(find.text('Meu ranking de afinidade'), findsOneWidget);
    expect(find.text('Pessoa 5'), findsOneWidget);
    expect(find.text('Pessoa 6'), findsNothing);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1920);
    final topFiveImage = device.downloaded;

    await tap(tester, 'Top 10');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade'), findsOneWidget);
    expect(find.text('Pessoa 10'), findsOneWidget);
    expect(find.text('Pessoa 11'), findsNothing);
    await tap(tester, 'Post · 4:5');
    await waitForImage(tester);
    await tap(tester, 'Baixar imagem');
    expectPng(device.downloaded, 1080, 1350);
    expect(device.downloaded, isNot(topFiveImage));
    await tap(tester, 'WhatsApp');
    expect(device.sharedText, contains('10º. Pessoa 10'));
    expect(device.sharedText, isNot(contains('Pessoa 11')));

    await tap(tester, 'Maior alinhamento');
    await waitForImage(tester);
    expect(find.text('Pessoa 1'), findsOneWidget);
    expect(find.text('Pessoa 2'), findsNothing);
    await tap(tester, 'Ranking');
    await waitForImage(tester);
    expect(find.text('Meu ranking de afinidade'), findsOneWidget);
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
    expect(find.text('Meu ranking de afinidade'), findsOneWidget);
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
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice();
    await pumpPage(tester, device, sink: sink);
    await tap(tester, 'Compartilhar imagem');
    expectPng(device.shared, 1080, 1920);
    expect(device.downloads, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      named(sink.calls, 'engagement_action').single.parameters,
      {
        'action': 'share',
        'surface': 'results',
        'target': 'native_share',
        'outcome': 'success',
      },
    );
  });

  testWidgets(
      'resultados nativos resolvidos contam como tentativa bem-sucedida',
      (tester) async {
    for (final status in ShareResultStatus.values) {
      final sink = RecordingAnalyticsSink();
      final device = _ShareDevice(shareStatus: status);
      await pumpPage(
        tester,
        device,
        sink: sink,
        imageRenderer: () async => Uint8List.fromList([1]),
      );
      await tap(tester, 'Compartilhar imagem');

      expect(
        named(sink.calls, 'engagement_action').single.parameters,
        allOf(
          containsPair('target', 'native_share'),
          containsPair('outcome', 'success'),
        ),
        reason: 'status nativo resolvido: $status',
      );
      expect(device.downloads, 0);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('falha nativa não inicia download automático', (tester) async {
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice(failSharing: true);
    await pumpPage(tester, device, sink: sink);
    await tap(tester, 'Compartilhar imagem');
    expect(device.downloaded, isNull);
    expect(device.downloads, 0);
    expect(find.textContaining('Não foi possível compartilhar a imagem.'),
        findsOneWidget);
    final actions = named(sink.calls, 'engagement_action');
    expect(actions, hasLength(1));
    expect(
      actions.single.parameters,
      allOf(
        containsPair('target', 'native_share'),
        containsPair('outcome', 'failed'),
      ),
    );
    expect(engagementTargets(sink.calls), isNot(contains('download')));
  });

  testWidgets('WhatsApp envia o PNG e a legenda do ranking selecionado ao menu',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    ShareParams? sent;
    final service = ResultShareService(share: (params) async {
      sent = params;
      return const ShareResult('', ShareResultStatus.dismissed);
    });
    await pumpPage(tester, service, shareData: rankingData, sink: sink);
    await tap(tester, 'Ranking');
    await tap(tester, 'Post · 4:5');
    await waitForImage(tester);
    await tap(tester, 'WhatsApp');

    expect(sent, isNotNull);
    expectPng(await sent!.files!.single.readAsBytes(), 1080, 1350);
    expect(sent!.files!.single.mimeType, 'image/png');
    expect(sent!.fileNameOverrides, ['meu-resultado-farol-post.png']);
    expect(sent!.text, contains('5º. Pessoa 5 (PSD)'));
    expect(sent!.text, isNot(contains('Pessoa 6')));
    expect(sent!.text, contains('20 de 30 respostas comparáveis'));
    expect(sent!.text, endsWith('https://fpolitico.com.br'));
    expect(sent!.sharePositionOrigin!.isEmpty, isFalse);
    expect(sent!.downloadFallbackEnabled, isFalse);
    expect(find.byType(SnackBar), findsNothing,
        reason:
            'cancelar o menu não anuncia publicação nem aciona alternativa');
    expect(engagementTargets(sink.calls), ['whatsapp']);
    expect(
      lastEngagement(sink.calls).parameters,
      containsPair('outcome', 'success'),
    );
  });

  testWidgets('WhatsApp sem suporte não baixa e oferece abrir a mensagem',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice(failSharing: true);
    await pumpPage(tester, device, shareData: rankingData, sink: sink);
    await tap(tester, 'WhatsApp');
    expect(device.downloaded, isNull);
    expect(device.downloads, 0);
    expect(device.networks, isEmpty,
        reason:
            'abrir a mensagem exige um novo toque para evitar popup bloqueado');
    expect(find.text('Abrir WhatsApp'), findsOneWidget);
    expect(
      lastEngagement(sink.calls).parameters,
      allOf(
        containsPair('target', 'whatsapp'),
        containsPair('outcome', 'failed'),
      ),
    );
    expect(engagementTargets(sink.calls), isNot(contains('download')));

    await tap(tester, 'Ranking');
    await waitForImage(tester);
    await tap(tester, 'Abrir WhatsApp');
    expect(device.networks, [ResultShareNetwork.whatsapp]);
    expect(device.networkData, same(rankingData),
        reason: 'a mensagem deve corresponder à seleção do primeiro toque');
    expect(engagementTargets(sink.calls), ['whatsapp', 'whatsapp']);
  });

  testWidgets(
      'WhatsApp sem download oferece a mensagem sem tentar salvar arquivo',
      (tester) async {
    final device = _ShareDevice(failSharing: true, downloadSupported: false);
    await pumpPage(tester, device);
    await tap(tester, 'WhatsApp');
    expect(device.downloads, 0);
    expect(
        find.textContaining('Não foi possível enviar imagem e texto juntos.'),
        findsOneWidget);
    await tap(tester, 'Abrir WhatsApp');
    expect(device.networks, [ResultShareNetwork.whatsapp]);
  });

  testWidgets('atalho do X e ajuda do Instagram preservam o link',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice();
    await pumpPage(tester, device, sink: sink);
    await tap(tester, 'X / Twitter');
    expect(device.networks, [ResultShareNetwork.twitter]);
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
    expect(
      engagementTargets(sink.calls),
      ['twitter', 'copy_link', 'instagram_help', 'copy_link'],
    );
    final instagram = named(sink.calls, 'engagement_action')
        .singleWhere((call) => call.parameters?['target'] == 'instagram_help');
    expect(instagram.parameters, {
      'action': 'share',
      'surface': 'results',
      'target': 'instagram_help',
    });
  });

  testWidgets('download direto emite uma ação segura após o resultado',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice();
    await pumpPage(tester, device, sink: sink);

    await tap(tester, 'Baixar imagem');

    final action = lastEngagement(sink.calls);
    expect(action.parameters, {
      'action': 'share',
      'surface': 'results',
      'target': 'download',
      'outcome': 'success',
    });
    expectSafeParameters(action);
  });

  testWidgets('destinos diretos emitem failed quando a operação lança',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final device = _ShareDevice(
      failDownload: true,
      failCopy: true,
      failNetwork: true,
    );
    await pumpPage(tester, device, sink: sink);

    await tap(tester, 'Baixar imagem');
    await tap(tester, 'Copiar link');
    await tap(tester, 'X / Twitter');

    final actions = named(sink.calls, 'engagement_action');
    expect(
      actions.map((call) => call.parameters?['target']),
      ['download', 'copy_link', 'twitter'],
    );
    expect(
      actions.map((call) => call.parameters?['outcome']).toSet(),
      {'failed'},
    );
  });

  testWidgets('analytics pendente não bloqueia compartilhamento',
      (tester) async {
    final analyticsNeverCompletes = Completer<void>();
    final sink = RecordingAnalyticsSink(block: analyticsNeverCompletes.future);
    final device = _ShareDevice();
    await pumpPage(
      tester,
      device,
      sink: sink,
      imageRenderer: () async => Uint8List.fromList([1]),
    );

    await tester.ensureVisible(find.text('Compartilhar imagem'));
    await tester.tap(find.text('Compartilhar imagem'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(device.shared, isNotNull);
    expect(lastEngagement(sink.calls).parameters,
        containsPair('target', 'native_share'));
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
