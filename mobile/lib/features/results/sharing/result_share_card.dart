import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'result_share_data.dart';
import 'result_share_palette.dart';
import 'result_share_pattern.dart';

/// A mesma composição é usada na prévia e no PNG. O tamanho lógico fixo
/// permite exportar em 1080 px, independentemente da largura do celular.
class ResultShareCard extends StatelessWidget {
  const ResultShareCard({
    super.key,
    required this.data,
    required this.format,
    this.palette = ResultSharePalette.blue,
    this.pattern = ResultSharePattern.beams,
  });

  final ResultShareData data;
  final ResultShareFormat format;
  final ResultSharePalette palette;
  final ResultSharePattern pattern;

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
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        width: 360,
        height: format.height,
        child: ClipRect(
          child: ColoredBox(
            color: palette.background,
            child: CustomPaint(
              painter: _SharePatternPainter(palette, pattern),
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
                        Icon(Icons.wb_twilight_rounded,
                            size: compactRanking ? 22 : 24,
                            color: palette.accent),
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
            story ? 'Fiz o quiz.\nMeu alinhamento.' : 'Fiz o quiz.',
            style: _type(story ? 40 : 30, bold: true),
          ),
          SizedBox(height: story ? 18 : 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${data.percent}%',
                style:
                    _type(story ? 112 : 76, bold: true, color: palette.accent)),
          ),
          Text('de afinidade com', style: _type(story ? 20 : 18)),
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
          const Spacer(flex: 2),
        ],
      );

  Widget _ranking(bool story) {
    final dense = data.displayResults.length > 5;
    final nameSize = story ? (dense ? 20.0 : 26.0) : (dense ? 16.0 : 22.0);
    final partySize = story ? 13.0 : (dense ? 10.0 : 12.0);
    final scoreSize = story ? (dense ? 28.0 : 34.0) : (dense ? 21.0 : 28.0);
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
          for (final (index, result) in data.displayResults.indexed)
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 23,
                    child: Text('${index + 1}',
                        style: _type(story ? 19 : 16, color: palette.accent)),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fitLine(result.name, _type(nameSize, bold: true)),
                        _fitLine(result.abbreviation, _type(partySize)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${ResultShareData.formatPercent(result.scorePercent)}%',
                      style:
                          _type(scoreSize, bold: true, color: palette.accent)),
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
  const _SharePatternPainter(this.palette, this.pattern);

  final ResultSharePalette palette;
  final ResultSharePattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case ResultSharePattern.beams:
        _paintBeams(canvas, size);
      case ResultSharePattern.orbits:
        _paintOrbits(canvas, size);
      case ResultSharePattern.diagonals:
        _paintDiagonals(canvas, size);
      case ResultSharePattern.steps:
        _paintSteps(canvas, size);
    }
  }

  Paint get _outline => Paint()
    ..color = palette.circle
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  // O feixe nasce no rodapé e se abre em direção ao alto, como um farol.
  void _paintBeams(Canvas canvas, Size size) {
    final beam = Path()
      ..moveTo(size.width * .73, size.height * 1.08)
      ..lineTo(size.width * .42, -size.height * .1)
      ..lineTo(size.width * 1.45, -size.height * .1)
      ..close();
    canvas.drawPath(beam, Paint()..color = palette.beam);
    final edge = Path()
      ..moveTo(size.width * .73, size.height * 1.08)
      ..lineTo(size.width * .96, 0)
      ..lineTo(size.width * 1.45, 0)
      ..close();
    canvas.drawPath(edge, Paint()..color = palette.edge);
    canvas.drawCircle(
      Offset(size.width * .99, size.height * .29),
      size.width * .156,
      _outline,
    );
  }

  void _paintOrbits(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * 1.12, size.height * .27),
      size.width * .7,
      Paint()..color = palette.beam,
    );
    canvas.drawCircle(
      Offset(size.width * 1.1, size.height * .86),
      size.width * .8,
      Paint()..color = palette.edge,
    );
    final center = Offset(size.width * 1.03, size.height * .2);
    for (final radius in [.22, .36]) {
      canvas.drawCircle(center, size.width * radius, _outline);
    }
  }

  void _paintDiagonals(Canvas canvas, Size size) {
    final beam = Path()
      ..moveTo(size.width * .82, -size.height * .08)
      ..lineTo(size.width * 1.32, -size.height * .08)
      ..lineTo(size.width * .26, size.height * 1.08)
      ..lineTo(-size.width * .24, size.height * 1.08)
      ..close();
    canvas.drawPath(beam, Paint()..color = palette.beam);
    final edge = Path()
      ..moveTo(size.width * 1.42, -size.height * .08)
      ..lineTo(size.width * 1.66, -size.height * .08)
      ..lineTo(size.width * .6, size.height * 1.08)
      ..lineTo(size.width * .36, size.height * 1.08)
      ..close();
    canvas.drawPath(edge, Paint()..color = palette.edge);
    canvas.drawLine(
      Offset(size.width * 1.08, size.height * .27),
      Offset(size.width * .34, size.height * 1.08),
      _outline,
    );
  }

  void _paintSteps(Canvas canvas, Size size) {
    final steps = Path()
      ..moveTo(size.width * .76, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .12, size.height)
      ..lineTo(size.width * .12, size.height * .9)
      ..lineTo(size.width * .32, size.height * .9)
      ..lineTo(size.width * .32, size.height * .69)
      ..lineTo(size.width * .52, size.height * .69)
      ..lineTo(size.width * .52, size.height * .47)
      ..lineTo(size.width * .76, size.height * .47)
      ..close();
    canvas.drawPath(steps, Paint()..color = palette.beam);
    final edge = Path()
      ..moveTo(size.width, size.height * .55)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .56, size.height)
      ..lineTo(size.width * .56, size.height * .78)
      ..lineTo(size.width * .8, size.height * .78)
      ..lineTo(size.width * .8, size.height * .55)
      ..close();
    canvas.drawPath(edge, Paint()..color = palette.edge);
    canvas.drawRect(
      Rect.fromLTWH(size.width * .86, size.height * .19, size.width * .23,
          size.width * .23),
      _outline,
    );
  }

  @override
  bool shouldRepaint(_SharePatternPainter oldDelegate) =>
      oldDelegate.palette != palette || oldDelegate.pattern != pattern;
}
