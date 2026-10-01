import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';
import 'package:guia_eleitoral/core/analytics/analytics_event_policy.dart';
import 'package:guia_eleitoral/core/analytics/consent_aware_analytics_sink.dart';
import 'package:guia_eleitoral/core/analytics/firebase_analytics_runtime.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/core/layout/app_scaffold.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/political_actors/politician_follow_validation_page.dart';

import 'helpers/analytics_test_support.dart';

const _legacyEventNames = <String>{
  'follow_waitlist_viewed',
  'follow_waitlist_prompt_viewed',
  'follow_waitlist_cta_clicked',
  'follow_waitlist_registered',
  'follow_waitlist_failed',
};

List<RecordedAnalyticsCall> _legacyCalls(RecordingAnalyticsSink sink) =>
    sink.calls.where((call) => _legacyEventNames.contains(call.name)).toList();

void _expectNoFunctionalIdentifier(RecordedAnalyticsCall call) {
  final parameters = call.parameters!;
  expect(
    parameters.keys,
    isNot(contains(anyOf('anonymous_id', 'device_id', 'hash'))),
  );
  expect(
    parameters.values,
    isNot(contains('550e8400-e29b-41d4-a716-446655440000')),
  );
}

void _expectParameters(
  RecordedAnalyticsCall call,
  Map<String, Object> expected,
) {
  for (final entry in expected.entries) {
    expect(call.parameters, containsPair(entry.key, entry.value));
  }
}

void main() {
  setUp(() {});

  Future<void> pumpPage(
    WidgetTester tester, {
    required _FakeInterestApi api,
    required RecordingAnalyticsSink sink,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PoliticianFollowValidationPage(
          apiClient: api,
          interestIdentityStore: _FakeIdentityStore(),
          analytics: AnalyticsService(sink: sink),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('uses the site shell and explains the anonymous validation',
      (tester) async {
    final sink = RecordingAnalyticsSink();

    await pumpPage(
      tester,
      api: _FakeInterestApi(registered: false),
      sink: sink,
    );

    expect(find.byType(AppScaffold), findsOneWidget);
    expect(find.text('ACOMPANHAR POLÍTICOS'), findsOneWidget);
    expect(find.text('Esta funcionalidade ainda está em validação.'),
        findsOneWidget);
    expect(find.textContaining('Não pedimos nome, e-mail ou telefone'),
        findsOneWidget);
    expect(find.text('TENHO INTERESSE'), findsOneWidget);
    expect(_legacyCalls(sink).map((call) => call.name), [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
    ]);
    expect(_legacyCalls(sink).map((call) => call.parameters),
        everyElement(isNull));

    final status = lastOperation(sink.calls);
    _expectParameters(status, {
      'operation': 'follow_status_load',
      'outcome': 'success',
      'trigger': 'initial',
    });
    expect(status.parameters!['duration_ms'], isA<int>());
    _expectNoFunctionalIdentifier(status);
  });

  testWidgets('one tap registers once and shows the confirmation',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final completion = Completer<bool>();
    final api = _FakeInterestApi(
      registered: false,
      registration: completion.future,
    );
    await pumpPage(tester, api: api, sink: sink);

    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.pump();

    expect(api.registerCalls, 1);
    completion.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('INTERESSE REGISTRADO'), findsOneWidget);
    expect(find.text('RETIRAR INTERESSE'), findsNothing);
    expect(find.textContaining('registro sem nome ou contato'), findsOneWidget);
    expect(find.textContaining('registro anônimo'), findsNothing);
    expect(_legacyCalls(sink).map((call) => call.name), [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
      'follow_waitlist_cta_clicked',
      'follow_waitlist_registered',
    ]);
    expect(_legacyCalls(sink).map((call) => call.parameters),
        everyElement(isNull));
    final registration = lastOperation(sink.calls);
    _expectParameters(registration, {
      'operation': 'follow_register',
      'outcome': 'success',
      'trigger': 'submit',
    });
    _expectNoFunctionalIdentifier(registration);
  });

  testWidgets('an existing registration is still a successful write outcome',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpPage(
      tester,
      api: _FakeInterestApi(
        registered: false,
        registration: Future<bool>.value(false),
      ),
      sink: sink,
    );

    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.pumpAndSettle();

    expect(find.text('INTERESSE REGISTRADO'), findsOneWidget);
    expect(sink.names, isNot(contains('follow_waitlist_registered')));
    final registration = lastOperation(sink.calls);
    _expectParameters(registration, {
      'operation': 'follow_register',
      'outcome': 'success',
      'trigger': 'submit',
    });
    _expectNoFunctionalIdentifier(registration);
  });

  testWidgets('a failed registration stays actionable and can be retried',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final api = _FakeInterestApi(
      registered: false,
      registrationError: const ApiException('offline'),
    );
    await pumpPage(tester, api: api, sink: sink);

    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.pumpAndSettle();

    expect(
        find.text('Não foi possível registrar seu interesse.'), findsOneWidget);
    expect(find.text('TENTAR NOVAMENTE'), findsOneWidget);
    expect(_legacyCalls(sink).map((call) => call.name),
        contains('follow_waitlist_failed'));
    expect(lastNamed(sink.calls, 'follow_waitlist_failed').parameters, isNull);
    final registration = lastOperation(sink.calls);
    _expectParameters(registration, {
      'operation': 'follow_register',
      'outcome': 'failed',
      'trigger': 'submit',
      'failure_type': 'unknown',
    });
    _expectNoFunctionalIdentifier(registration);
  });

  testWidgets('a failed status check emits only a generic failure type',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpPage(
      tester,
      api: _FakeInterestApi(
        registered: false,
        statusError: const ApiException(
          'private server detail',
          statusCode: 503,
        ),
      ),
      sink: sink,
    );

    final status = lastOperation(sink.calls);
    _expectParameters(status, {
      'operation': 'follow_status_load',
      'outcome': 'failed',
      'trigger': 'initial',
      'failure_type': 'unavailable',
    });
    _expectNoFunctionalIdentifier(status);
  });

  testWidgets('a stalled status check falls back to an actionable prompt',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final neverCompletes = Completer<bool>();

    await pumpPage(
      tester,
      api: _FakeInterestApi(
        registered: false,
        status: neverCompletes.future,
      ),
      sink: sink,
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('TENHO INTERESSE'), findsOneWidget);
    expect(find.textContaining('Não foi possível verificar'), findsOneWidget);
    expect(_legacyCalls(sink).map((call) => call.name), [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
    ]);
    _expectParameters(lastOperation(sink.calls), {
      'operation': 'follow_status_load',
      'outcome': 'failed',
      'trigger': 'initial',
      'failure_type': 'timeout',
    });
  });

  testWidgets('logs a successful write even if the page was closed',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final completion = Completer<bool>();
    final api = _FakeInterestApi(
      registered: false,
      registration: completion.future,
    );
    await pumpPage(tester, api: api, sink: sink);

    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(true);
    await tester.pump();

    expect(sink.names, contains('follow_waitlist_registered'));
    _expectParameters(lastOperation(sink.calls), {
      'operation': 'follow_register',
      'outcome': 'success',
      'trigger': 'submit',
    });
  });

  testWidgets('logs a status outcome even if the page was closed',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    final completion = Completer<bool>();
    await pumpPage(
      tester,
      api: _FakeInterestApi(registered: false, status: completion.future),
      sink: sink,
      settle: false,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    completion.complete(false);
    await tester.pump();

    _expectParameters(lastOperation(sink.calls), {
      'operation': 'follow_status_load',
      'outcome': 'success',
      'trigger': 'initial',
    });
  });

  testWidgets('denied metrics do not block interest registration',
      (tester) async {
    final runtime = _Runtime();
    final controller = AnalyticsConsentController.testOnly(
      store: _Store(),
      effects: runtime,
    );
    await controller.hydrate();
    await controller.deny();
    addTearDown(controller.dispose);
    final api = _FakeInterestApi(registered: false);
    const interestId = '550e8400-e29b-41d4-a716-446655440000';
    final sink = ConsentAwareAnalyticsSink(
      controller: controller,
      runtime: runtime,
      operationallyEnabled: true,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: PoliticianFollowValidationPage(
        apiClient: api,
        interestIdentityStore: _FakeIdentityStore(),
        analytics: AnalyticsService(sink: sink),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TENHO INTERESSE'));
    await tester.pumpAndSettle();
    expect(find.text('INTERESSE REGISTRADO'), findsOneWidget);
    expect(api.registerCalls, 1);
    expect(api.interestIds, everyElement(interestId));
    expect(find.text('RETIRAR INTERESSE'), findsNothing);
    expect(api.deleteCalls, 0);
    expect(runtime.events, isEmpty);
    expect(runtime.initializationCalls, 0);
  });
}

class _FakeInterestApi extends ApiClient {
  _FakeInterestApi({
    required this.registered,
    this.status,
    this.statusError,
    this.registration,
    this.registrationError,
  }) : super(baseUrl: 'https://example.test/api/v1');

  bool registered;
  final Future<bool>? status;
  final Future<bool>? registration;
  final Object? registrationError;
  final Object? statusError;
  int registerCalls = 0;
  int deleteCalls = 0;
  final List<String> interestIds = [];

  @override
  Future<bool> fetchPoliticianFollowInterest({
    required String anonymousId,
  }) async {
    interestIds.add(anonymousId);
    if (statusError != null) throw statusError!;
    return await (status ?? Future<bool>.value(registered));
  }

  @override
  Future<bool> registerPoliticianFollowInterest({
    required String anonymousId,
  }) async {
    interestIds.add(anonymousId);
    registerCalls++;
    if (registrationError != null) throw registrationError!;
    final isNew = await (registration ?? Future<bool>.value(true));
    registered = true;
    return isNew;
  }

  @override
  Future<void> deletePoliticianFollowInterest({
    required String anonymousId,
  }) async {
    interestIds.add(anonymousId);
    deleteCalls++;
    registered = false;
  }
}

class _Store implements AnalyticsConsentStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

class _Runtime implements AnalyticsRuntime {
  final List<SanitizedAnalyticsEvent> events = [];
  int initializationCalls = 0;

  @override
  Future<void> initializeForGrantedConsent() async {
    initializationCalls++;
  }

  @override
  Future<void> logEvent(SanitizedAnalyticsEvent event) async {
    events.add(event);
  }

  @override
  Future<void> updateConsent({required bool granted}) async {}
}

class _FakeIdentityStore extends PoliticianFollowInterestIdentityStore {
  @override
  Future<String> getOrCreateInterestId() async =>
      '550e8400-e29b-41d4-a716-446655440000';
}
