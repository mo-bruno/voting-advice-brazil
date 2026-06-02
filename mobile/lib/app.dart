import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/community/community_feed_page.dart';
import 'features/comparison/comparison_page.dart';
import 'features/home/home_page.dart';
import 'features/party_selection/party_selection_page.dart';
import 'features/political_actors/political_actor_profile_page.dart';
import 'features/political_actors/political_actor_search_page.dart';
import 'features/quiz/quiz_intro_page.dart';
import 'features/quiz/quiz_page.dart';
import 'features/results/results_page.dart';
import 'features/iot/iot_device_page.dart';
import 'features/iot/iot_pairing_page.dart';
import 'features/weighting/weighting_page.dart';

/// Largura máxima do conteúdo. Em telas largas (web/tablet) a interface é
/// centralizada e limitada a esta largura — o equivalente em Flutter da
/// "caixa limitada" do CSS (`max-width` + `margin: 0 auto`). Em celulares,
/// onde a tela é mais estreita, usa-se a largura total disponível.
const double kMaxContentWidth = 600;

/// Configuração global da aplicação: tema, rotas nomeadas e a camada de layout
/// aplicada a todas as telas (ver `builder`). Mantém a configuração separada do
/// ponto de entrada (main.dart).
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guia Eleitoral',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // O `builder` intercepta a construção de TODAS as telas e aplica uma
      // camada de layout global: área segura (SafeArea) + limite de largura
      // responsivo. Centralizar isso aqui evita repetir a mesma lógica em cada
      // página (princípio DRY) e garante consistência visual em todo o app.
      builder: (context, child) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth > kMaxContentWidth
                  ? kMaxContentWidth
                  : constraints.maxWidth;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          ),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/quiz-intro': (context) => const QuizIntroPage(),
        '/quiz': (context) => const QuizPage(),
        '/weighting': (context) => const WeightingPage(),
        '/party-selection': (context) => const PartySelectionPage(),
        '/results': (context) => const ResultsPage(),
        '/comparison': (context) => const ComparisonPage(),
        '/political-actors': (context) => const PoliticalActorSearchPage(),
        '/political-actor-profile': (context) =>
            const PoliticalActorProfilePage(),
        '/iot-device': (context) => const IotDevicePage(),
        '/iot-pairing': (context) => const IotPairingPage(),
        '/comunidade': (context) => const CommunityFeedPage(),
      },
    );
  }
}
