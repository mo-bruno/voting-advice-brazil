import 'package:flutter/material.dart';

/// As cores são uma escolha visual da pessoa e não representam partidos.
enum ResultSharePalette {
  blue(
    'Azul',
    background: Color(0xFF2045D8),
    foreground: Color(0xFFF5FAFF),
    accent: Color(0xFFC6F5EA),
    beam: Color(0xFF3156E8),
    edge: Color(0xFF395DDF),
    circle: Color(0xFF5F7DF1),
  ),
  purple(
    'Roxo',
    background: Color(0xFF532B9C),
    foreground: Color(0xFFFCF7FF),
    accent: Color(0xFFFFE8AA),
    beam: Color(0xFF653CAD),
    edge: Color(0xFF744BBB),
    circle: Color(0xFFA785DB),
  ),
  green(
    'Verde',
    background: Color(0xFF075D50),
    foreground: Color(0xFFF4FFF8),
    accent: Color(0xFFE1F7B0),
    beam: Color(0xFF116C5D),
    edge: Color(0xFF1C7868),
    circle: Color(0xFF59A993),
  ),
  coral(
    'Coral',
    background: Color(0xFFFA9A87),
    foreground: Color(0xFF371E32),
    accent: Color(0xFF562C49),
    beam: Color(0xFFF9AA96),
    edge: Color(0xFFFABDAB),
    circle: Color(0xFFD77D76),
  ),
  red(
    'Vermelho',
    background: Color(0xFFAA2842),
    foreground: Color(0xFFFFFFFF),
    accent: Color(0xFFFFE4C0),
    beam: Color(0xFF9C253D),
    edge: Color(0xFF8F2237),
    circle: Color(0xFFC26477),
  ),
  orange(
    'Laranja',
    background: Color(0xFFFDAD60),
    foreground: Color(0xFF000000),
    accent: Color(0xFF68350C),
    beam: Color(0xFFFDB46D),
    edge: Color(0xFFFDBA79),
    circle: Color(0xFFB67D45),
  ),
  yellow(
    'Amarelo',
    background: Color(0xFFF8DD62),
    foreground: Color(0xFF000000),
    accent: Color(0xFF674711),
    beam: Color(0xFFF9E06F),
    edge: Color(0xFFF9E27B),
    circle: Color(0xFFB39F47),
  ),
  pink(
    'Rosa',
    background: Color(0xFFECA9D1),
    foreground: Color(0xFF000000),
    accent: Color(0xFF671B56),
    beam: Color(0xFFEEB0D5),
    edge: Color(0xFFEFB7D8),
    circle: Color(0xFFAA7A96),
  ),
  cyan(
    'Ciano',
    background: Color(0xFF93E6EB),
    foreground: Color(0xFF000000),
    accent: Color(0xFF075767),
    beam: Color(0xFF9CE8ED),
    edge: Color(0xFFA4EAEE),
    circle: Color(0xFF6AA6A9),
  ),
  black(
    'Preto',
    background: Color(0xFF181B24),
    foreground: Color(0xFFFFFFFF),
    accent: Color(0xFFD0DCF7),
    beam: Color(0xFF161921),
    edge: Color(0xFF14171E),
    circle: Color(0xFF595B61),
  ),
  white(
    'Branco',
    background: Color(0xFFF4F5F9),
    foreground: Color(0xFF000000),
    accent: Color(0xFF364BB7),
    beam: Color(0xFFF5F6F9),
    edge: Color(0xFFF6F7FA),
    circle: Color(0xFFB0B0B3),
  ),
  brown(
    'Marrom',
    background: Color(0xFF704738),
    foreground: Color(0xFFFFFFFF),
    accent: Color(0xFFFFE0A3),
    beam: Color(0xFF674134),
    edge: Color(0xFF5E3C2F),
    circle: Color(0xFF987B70),
  );

  const ResultSharePalette(
    this.label, {
    required this.background,
    required this.foreground,
    required this.accent,
    required this.beam,
    required this.edge,
    required this.circle,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color accent;
  final Color beam;
  final Color edge;
  final Color circle;
}
