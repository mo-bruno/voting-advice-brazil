import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF050505);
  static const surface = Color(0xFF0D0D0D);
  static const surfaceAlt = Color(0xFF0F0F0F);
  static const surfaceMuted = Color(0xFF1A1A1A);
  static const divider = Color(0xFF242424);
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const textMuted = Colors.white54;
  static const borderStrong = Colors.white24;
  static const borderSoft = Colors.white12;
  static const borderControl = Colors.white38;
  static const scrim = Colors.black;
  static const transparent = Colors.transparent;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
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
