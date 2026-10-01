import 'dart:async';

import 'package:flutter/material.dart';

import 'analytics_service.dart';

const communityPostRoute = '/comunidade/post';
const communityCreateRoute = '/comunidade/criar';
const resultShareRoute = '/results/share';

class AnalyticsNavigationIntent {
  AnalyticsSource? _next;

  void mark(AnalyticsSource source) => _next = source;

  AnalyticsSource consumeOr(AnalyticsSource fallback) {
    final source = _next ?? fallback;
    _next = null;
    return source;
  }
}

class AnalyticsNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  AnalyticsNavigationObserver({
    required AnalyticsService analytics,
    required AnalyticsNavigationIntent intent,
    this.politicianFollowEnabled = false,
  })  : _analytics = analytics,
        _intent = intent;

  final AnalyticsService _analytics;
  final AnalyticsNavigationIntent _intent;
  final bool politicianFollowEnabled;

  static const _screens = <String, AnalyticsScreen>{
    '/quiz': AnalyticsScreen.quizQuestions,
    '/weighting': AnalyticsScreen.weighting,
    '/party-selection': AnalyticsScreen.candidateSelection,
    '/results': AnalyticsScreen.results,
    '/comparison': AnalyticsScreen.comparison,
    '/political-actors': AnalyticsScreen.followValidation,
    '/comunidade': AnalyticsScreen.communityFeed,
    communityPostRoute: AnalyticsScreen.communityPost,
    communityCreateRoute: AnalyticsScreen.communityCreate,
    resultShareRoute: AnalyticsScreen.resultShare,
    '/privacidade': AnalyticsScreen.privacy,
  };

  static AnalyticsScreen? screenFor(String? routeName) => _screens[routeName];

  AnalyticsScreen? _screenForRoute(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (politicianFollowEnabled && name == '/political-actors') return null;
    return screenFor(name);
  }

  void _track(Route<dynamic>? route, AnalyticsSource source) {
    final screen = _screenForRoute(route);
    if (screen == null) return;
    unawaited(
      _analytics
          .screenViewed(screen: screen, source: source)
          .catchError((_) {}),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_screenForRoute(route) == null) return;
    _track(route, _intent.consumeOr(AnalyticsSource.route));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_screenForRoute(newRoute) == null) return;
    _track(newRoute, _intent.consumeOr(AnalyticsSource.route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is! PageRoute<dynamic>) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (previousRoute?.isCurrent ?? false) {
        _track(previousRoute, AnalyticsSource.back);
      }
    });
  }
}
