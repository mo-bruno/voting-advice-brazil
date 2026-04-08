import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/quiz/quiz_page.dart';
import 'features/weighting/weighting_page.dart';
import 'features/party_selection/party_selection_page.dart';
import 'features/results/results_page.dart';
import 'features/comparison/comparison_page.dart';
import 'features/justification/justification_page.dart';

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
        '/quiz': (context) => const QuizPage(),
        '/weighting': (context) => const WeightingPage(),
        '/party-selection': (context) => const PartySelectionPage(),
        '/results': (context) => const ResultsPage(),
        '/comparison': (context) => const ComparisonPage(),
        '/justification': (context) => const JustificationPage(),
      },
    );
  }
}
