@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default web pipeline sends each event through Firebase only', () async {
    setupFirebaseCoreMocks();
    FirebasePlatform.instance = MethodChannelFirebase();
    final app = await Firebase.initializeApp();

    final firebaseCalls = <String>[];
    FirebaseAnalyticsPlatform.instance =
        _RecordingAnalyticsPlatform(app, firebaseCalls);

    final gtagCalls = <String>[];
    void gtag(JSString command, JSString eventName, JSAny? parameters) {
      gtagCalls.add('${command.toDart}:${eventName.toDart}');
    }

    globalContext.setProperty('gtag'.toJS, gtag.toJS);
    addTearDown(() => globalContext.delete('gtag'.toJS));

    await AnalyticsService().quizStarted();

    expect(firebaseCalls, ['quiz_started']);
    expect(gtagCalls, isEmpty);
  });
}

class _RecordingAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  _RecordingAnalyticsPlatform(FirebaseApp app, this.calls)
      : super(appInstance: app);

  final List<String> calls;

  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) {
    return this;
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {
    calls.add(name);
  }
}
