// lib/main.dart
//
// Ponto de entrada da aplicação. Sua única responsabilidade é inicializar o
// framework Flutter (e o Firebase, quando disponível) e subir o widget raiz
// (MyApp). A configuração da aplicação fica separada em app.dart — princípio
// da responsabilidade única (SRP) visto em aula.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}
