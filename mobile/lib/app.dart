import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/comparison/comparison_page.dart';
import 'features/home/home_page.dart';
import 'features/party_selection/party_selection_page.dart';
import 'features/political_actors/political_actor_profile_page.dart';
import 'features/political_actors/political_actor_search_page.dart';
import 'features/quiz/quiz_intro_page.dart';
import 'features/quiz/quiz_page.dart';
import 'features/results/results_page.dart';
import 'features/iot/iot_device_page.dart';
import 'features/community/community_feed_page.dart';
import 'features/iot/iot_pairing_page.dart';
import 'features/weighting/weighting_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guia Eleitoral',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
        '/community': (context) => const CommunityFeedPage(),
        '/iot-device': (context) => const IotDevicePage(),
        '/iot-pairing': (context) => const IotPairingPage(),
      },
    );
  }
}
