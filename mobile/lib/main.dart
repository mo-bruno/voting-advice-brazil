// lib/main.dart
//
// Ponto de entrada da aplicação. Sua única responsabilidade é inicializar o
// framework Flutter, hidratar o consentimento e subir o widget raiz
// (MyApp). A configuração da aplicação fica separada em app.dart — princípio
// da responsabilidade única (SRP) visto em aula.

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/analytics/analytics_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analytics = AnalyticsDependencies.instance;
  await analytics.controller.hydrate();
  runApp(const MyApp());
}
