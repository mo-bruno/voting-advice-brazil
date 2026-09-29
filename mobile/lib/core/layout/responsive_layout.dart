import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keep the compact experience on phones/tablets, including landscape mode.
abstract final class ResponsiveLayout {
  static const desktopContentWidth = 1240.0;

  static bool isDesktop(BuildContext context) {
    final platform = defaultTargetPlatform;
    return platform != TargetPlatform.android &&
        platform != TargetPlatform.iOS &&
        MediaQuery.sizeOf(context).width >= 1200;
  }
}
