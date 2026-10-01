import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_navigation.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

import 'helpers/analytics_test_support.dart';

List<(String, String)> _screenPairs(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'screen_viewed'))
        (
          call.parameters!['screen']! as String,
          call.parameters!['source']! as String,
        ),
    ];

void main() {
  test('navigation intent is consumed exactly once', () {
    final intent = AnalyticsNavigationIntent();
    intent.mark(AnalyticsSource.drawer);

    expect(intent.consumeOr(AnalyticsSource.route), AnalyticsSource.drawer);
    expect(intent.consumeOr(AnalyticsSource.route), AnalyticsSource.route);
  });

  testWidgets('push replace and pop emit only canonical screens',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final intent = AnalyticsNavigationIntent();
    final observer = AnalyticsNavigationObserver(
      analytics: AnalyticsService(sink: sink),
      intent: intent,
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/quiz': (_) => const Scaffold(body: Text('quiz')),
        '/weighting': (_) => const Scaffold(body: Text('weighting')),
        '/party-selection': (_) => const Scaffold(body: Text('selection')),
        '/results': (_) => const Scaffold(body: Text('results')),
      },
    ));

    intent.mark(AnalyticsSource.drawer);
    unawaited(navigatorKey.currentState!.pushNamed('/quiz'));
    await tester.pumpAndSettle();
    unawaited(navigatorKey.currentState!.pushNamed('/weighting'));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    unawaited(
      navigatorKey.currentState!.pushReplacementNamed('/party-selection'),
    );
    await tester.pumpAndSettle();

    expect(_screenPairs(sink.calls), [
      ('quiz_questions', 'drawer'),
      ('weighting', 'route'),
      ('quiz_questions', 'back'),
      ('candidate_selection', 'route'),
    ]);
    expect(
      sink.calls.expand((event) => event.parameters?.keys ?? const <String>[]),
      isNot(contains('route')),
    );

    final beforeDialog = sink.calls.length;
    unawaited(showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(title: Text('dialog')),
    ));
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sink.calls, hasLength(beforeDialog));

    navigatorKey.currentState!.pop();
    unawaited(navigatorKey.currentState!.pushNamed('/results'));
    await tester.pumpAndSettle();
    expect(_screenPairs(sink.calls).last, ('results', 'route'));
    expect(
      _screenPairs(sink.calls)
          .where((pair) => pair == ('candidate_selection', 'back')),
      isEmpty,
    );
  });

  testWidgets('enabled politician search is not mislabeled as validation',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final intent = AnalyticsNavigationIntent();
    final observer = AnalyticsNavigationObserver(
      analytics: AnalyticsService(sink: sink),
      intent: intent,
      politicianFollowEnabled: true,
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      routes: {
        '/': (_) => const SizedBox(),
        '/political-actors': (_) => const SizedBox(),
      },
    ));

    unawaited(navigatorKey.currentState!.pushNamed('/political-actors'));
    await tester.pumpAndSettle();

    expect(sink.calls, isEmpty);
  });

  test('only approved route names have screen mappings', () {
    expect(AnalyticsNavigationObserver.screenFor('/'), isNull);
    expect(AnalyticsNavigationObserver.screenFor('/candidate/13'), isNull);
    expect(
      AnalyticsNavigationObserver.screenFor(communityPostRoute),
      AnalyticsScreen.communityPost,
    );
    expect(
      AnalyticsNavigationObserver.screenFor(communityCreateRoute),
      AnalyticsScreen.communityCreate,
    );
    expect(
      AnalyticsNavigationObserver.screenFor(resultShareRoute),
      AnalyticsScreen.resultShare,
    );
  });
}
