import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

class VotingAdviceApp extends StatelessWidget {
  const VotingAdviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VotingAdvice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.inicial,
      routes: AppRoutes.routes,
    );
  }
}
