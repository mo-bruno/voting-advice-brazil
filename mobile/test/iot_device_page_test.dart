import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guia_eleitoral/core/api/api_client.dart';
import 'package:guia_eleitoral/core/device/device_identity_store.dart';
import 'package:guia_eleitoral/features/iot/iot_device_page.dart';
import 'package:guia_eleitoral/shared/iot_device_session.dart';
import 'package:guia_eleitoral/shared/models/iot_device.dart';
import 'package:guia_eleitoral/shared/models/political_actor.dart';
import 'package:guia_eleitoral/shared/political_actor_session.dart';

class _StubApiClient extends ApiClient {
  _StubApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<IotDevice?> fetchIotDevice({required String anonymousId}) async => null;

  @override
  Future<PoliticalActor?> fetchFollowedPoliticalActor({
    required String anonymousId,
  }) async =>
      null;
}

class _StubIdentityStore extends DeviceIdentityStore {
  _StubIdentityStore() : super();

  @override
  Future<String> getOrCreateDeviceId() async => 'anon-test';
}

IotDeviceSession _stubSession() => IotDeviceSession.testOnly(
      api: _StubApiClient(),
      deviceIdentityStore: _StubIdentityStore(),
    );

PoliticalActorSession _stubActorSession() => PoliticalActorSession.testOnly(
      api: _StubApiClient(),
      deviceIdentityStore: _StubIdentityStore(),
    );

void main() {
  testWidgets('shows disconnected state and connect action', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final session = _stubSession();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/iot-pairing': (_) => const SizedBox()},
        home: IotDevicePage(
          session: session,
          actorSession: _stubActorSession(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MEU FAROL'), findsOneWidget);
    expect(find.text('Nenhum Farol conectado.'), findsOneWidget);
    expect(find.text('CONECTAR FAROL'), findsOneWidget);
  });

  testWidgets('shows linked status with no deputy selected', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final session = _stubSession()
      ..device = IotDevice(
        deviceToken: '550e8400-e29b-41d4-a716-446655440000',
        status: 'linked',
        linkedAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
        lastSeenAt: null,
      );
    final actorSession = _stubActorSession();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/political-actors': (_) => const SizedBox()},
        home: IotDevicePage(session: session, actorSession: actorSession),
      ),
    );

    expect(find.text('Farol conectado'), findsOneWidget);
    expect(find.text('550E8400'), findsOneWidget);
    expect(find.text('Nenhum deputado selecionado.'), findsOneWidget);
    expect(find.text('ESCOLHER DEPUTADO'), findsOneWidget);
  });

  testWidgets('shows linked status with deputy being monitored', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final session = _stubSession()
      ..device = IotDevice(
        deviceToken: '550e8400-e29b-41d4-a716-446655440000',
        status: 'linked',
        linkedAt: DateTime(2026, 5, 22),
        updatedAt: DateTime(2026, 5, 22),
        lastSeenAt: null,
      );
    final actorSession = _stubActorSession()
      ..replaceFollowedActor(
        PoliticalActor(
          id: 1,
          source: 'camara',
          sourceId: '12345',
          displayName: 'João da Silva',
          party: 'PT',
          state: 'SP',
          role: 'federal_deputy',
          status: 'exercising',
          photoUrl: null,
          sourceUrl: null,
          lastIndexedAt: DateTime(2026, 5, 1),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/political-actors': (_) => const SizedBox()},
        home: IotDevicePage(session: session, actorSession: actorSession),
      ),
    );

    expect(find.text('Farol conectado'), findsOneWidget);
    expect(find.text('550E8400'), findsOneWidget);
    expect(find.text('MONITORANDO'), findsOneWidget);
    expect(find.text('João da Silva'), findsOneWidget);
    expect(find.text('TROCAR DEPUTADO'), findsOneWidget);
  });
}
