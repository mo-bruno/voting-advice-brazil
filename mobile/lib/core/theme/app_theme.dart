import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF050505),
      fontFamily: 'Arial',
      pageTransitionsTheme: PageTransitionsTheme(
        builders: _pageTransitionsBuilders,
      ),
    );
  }

  static Map<TargetPlatform, PageTransitionsBuilder>
      get _pageTransitionsBuilders {
    const noTransitions = NoTransitionsBuilder();

    if (kIsWeb) {
      return const {
        TargetPlatform.android: noTransitions,
        TargetPlatform.iOS: noTransitions,
        TargetPlatform.windows: noTransitions,
        TargetPlatform.macOS: noTransitions,
        TargetPlatform.linux: noTransitions,
      };
    }

    return const {
      TargetPlatform.windows: noTransitions,
      TargetPlatform.macOS: noTransitions,
      TargetPlatform.linux: noTransitions,
    };
  }
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
