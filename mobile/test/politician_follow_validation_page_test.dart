import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_service.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/core/layout/app_scaffold.dart';
import 'package:guia_eleitoral/core/theme/app_theme.dart';
import 'package:guia_eleitoral/features/political_actors/politician_follow_validation_page.dart';

void main() {
  setUp(() {});

  Future<void> pumpPage(
    WidgetTester tester, {
    required _FakeInterestApi api,
    required _RecordingSink sink,
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
    final sink = _RecordingSink();

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
    expect(sink.names, [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
    ]);
  });

  testWidgets('one tap registers once and shows the confirmation',
      (tester) async {
    final sink = _RecordingSink();
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
    expect(find.text('RETIRAR INTERESSE'), findsOneWidget);
    expect(sink.names, [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
      'follow_waitlist_cta_clicked',
      'follow_waitlist_registered',
    ]);
  });

  testWidgets('a failed registration stays actionable and can be retried',
      (tester) async {
    final sink = _RecordingSink();
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
    expect(sink.names.last, 'follow_waitlist_failed');
  });

  testWidgets('a stalled status check falls back to an actionable prompt',
      (tester) async {
    final sink = _RecordingSink();
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
    expect(sink.names, [
      'follow_waitlist_viewed',
      'follow_waitlist_prompt_viewed',
    ]);
  });

  testWidgets('logs a successful write even if the page was closed',
      (tester) async {
    final sink = _RecordingSink();
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
  });
}

class _FakeInterestApi extends ApiClient {
  _FakeInterestApi({
    required this.registered,
    this.status,
    this.registration,
    this.registrationError,
  }) : super(baseUrl: 'https://example.test/api/v1');

  bool registered;
  final Future<bool>? status;
  final Future<bool>? registration;
  final Object? registrationError;
  int registerCalls = 0;

  @override
  Future<bool> fetchPoliticianFollowInterest({
    required String anonymousId,
  }) async =>
      await (status ?? Future<bool>.value(registered));

  @override
  Future<bool> registerPoliticianFollowInterest({
    required String anonymousId,
  }) async {
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
    registered = false;
  }
}

class _FakeIdentityStore extends PoliticianFollowInterestIdentityStore {
  @override
  Future<String> getOrCreateInterestId() async =>
      '550e8400-e29b-41d4-a716-446655440000';
}

class _RecordingSink implements AnalyticsSink {
  final List<String> names = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    expect(parameters, isNull);
    names.add(name);
  }
}
