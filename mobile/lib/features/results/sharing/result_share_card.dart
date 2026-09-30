import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/branding/farol_mark.dart';
import '../../../core/branding/feixe_geometry.dart';
import 'result_share_data.dart';
import 'result_share_palette.dart';

/// A mesma composição é usada na prévia e no PNG. O tamanho lógico fixo
/// permite exportar em 1080 px, independentemente da largura do celular.
class ResultShareCard extends StatelessWidget {
  const ResultShareCard({
    super.key,
    required this.data,
    required this.format,
    this.palette = ResultSharePalette.blue,
    this.beamAngle = 38,
  });

  final ResultShareData data;
  final ResultShareFormat format;
  final ResultSharePalette palette;

  /// Graus abaixo da horizontal. Sorteado pela página, nunca durante o paint.
  final double beamAngle;

  static Future<void>? _fontLoading;

  static Future<void> loadFonts() => _fontLoading ??= (FontLoader(
        'BarlowCondensed',
      )
            ..addFont(
                rootBundle.load('assets/fonts/BarlowCondensed-SemiBold.ttf'))
            ..addFont(
                rootBundle.load('assets/fonts/BarlowCondensed-ExtraBold.ttf')))
          .load()
          .catchError((Object error, StackTrace stack) {
        _fontLoading = null;
        Error.throwWithStackTrace(error, stack);
      });

  TextStyle _type(double size, {bool bold = false, Color? color}) => TextStyle(
        fontFamily: 'BarlowCondensed',
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontSize: size,
        height: 1.05,
        color: color ?? palette.foreground,
        letterSpacing: 0,
        decoration: TextDecoration.none,
      );

  @override
  Widget build(BuildContext context) {
    final story = format == ResultShareFormat.story;
    final compactRanking = data.isRanking && !story;
    final top = story ? 48.0 : (compactRanking ? 20.0 : 24.0);
    final markSize = compactRanking ? 22.0 : 24.0;
    final beamOrigin =
        Offset(28, top) + feixeBeamOrigin * (markSize / feixeViewBox);
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: 360,
        height: format.height,
        child: ClipRect(
          child: ColoredBox(
            color: palette.background,
            child: CustomPaint(
              painter: _SharePatternPainter(palette, beamAngle, beamOrigin),
              child: Padding(
                // Margens maiores nos Stories deixam espaço para a interface
                // da rede social, sem cortar a marca nem o endereço.
                padding: EdgeInsets.fromLTRB(
                    28,
                    story ? 48 : (compactRanking ? 20 : 24),
                    28,
                    story ? 48 : (compactRanking ? 20 : 24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FarolMark(size: markSize, color: palette.mark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('farol político',
                                style: _type(compactRanking ? 20 : 22)),
                          ),
                        ),
                      ],
                    ),
                    if (data.isRanking)
                      Expanded(child: _ranking(story))
                    else
                      Expanded(child: _leader(story)),
                    _footer(compactRanking: compactRanking),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leader(bool story) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Text(
            story
                ? 'Fiz o quiz.\nMeu alinhamento'
                : 'Meu alinhamento',
            style: _type(story ? 40 : 30, bold: true),
          ),
          SizedBox(height: story ? 18 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(data.result.affinityLabel,
                style:
                    _type(story ? 76 : 54, bold: true, color: palette.accent)),
          ),
          Text('no ranking de afinidade', style: _type(story ? 20 : 18)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: story ? 72 : 46,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 304,
                child: Text(data.result.name,
                    style: _type(story ? 36 : 30, bold: true)),
              ),
            ),
          ),
          Text(data.result.abbreviation, style: _type(18)),
          SizedBox(height: story ? 18 : 10),
          _fitLine(
            'Base: ${data.result.coverageLabel}',
            _type(story ? 18 : 15),
          ),
          const Spacer(flex: 2),
        ],
      );

  Widget _ranking(bool story) {
    final dense = data.displayResults.length > 5;
    final nameSize = story ? (dense ? 20.0 : 26.0) : (dense ? 16.0 : 22.0);
    final basisSize = story ? (dense ? 11.0 : 13.0) : (dense ? 8.0 : 10.0);
    return Padding(
      padding: EdgeInsets.only(top: story ? 24 : 8, bottom: story ? 20 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(data.rankingTitle,
                style: _type(story ? 36 : 28, bold: true)),
          ),
          SizedBox(height: story ? 16 : 8),
          for (final result in data.displayResults)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text('${result.rank}º',
                        style: _type(story ? 19 : 16, color: palette.accent)),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fitLine(result.name, _type(nameSize, bold: true)),
                        _fitLine(
                          '${result.abbreviation} · Base: '
                          '${result.countedTheses}/${result.answeredTheses} '
                          'comparáveis · ${result.comparableCategories} cat.',
                          _type(basisSize),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fitLine(String text, TextStyle style) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: style),
      );

  Widget _footer({required bool compactRanking}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.editionLabel,
              style: _type(compactRanking ? 13 : 14, bold: true)),
          Text(
            'Entre os candidatos que comparei.',
            style: _type(compactRanking ? 11 : 12),
          ),
          SizedBox(height: compactRanking ? 8 : 10),
          _fitLine(data.siteLabel,
              _type(compactRanking ? 16 : 17, color: palette.accent)),
        ],
      );
}

/// A composição escolhida permanece igual na prévia e na imagem exportada.
class _SharePatternPainter extends CustomPainter {
  const _SharePatternPainter(this.palette, this.angle, this.origin);

  final ResultSharePalette palette;
  final double angle;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final length = size.longestSide * 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle * pi / 180);
    canvas.drawPath(
      Path()
        ..moveTo(0, -1)
        ..lineTo(length, -length * 210 / 950)
        ..lineTo(length, length * 210 / 950)
        ..lineTo(0, 1)
        ..close(),
      Paint()..color = palette.beamOverlay,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -1)
        ..lineTo(length, -length * 210 / 950)
        ..lineTo(length, -length * 52 / 950)
        ..close(),
      Paint()..color = palette.beamEdgeOverlay,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SharePatternPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.angle != angle ||
      oldDelegate.origin != origin;
}
