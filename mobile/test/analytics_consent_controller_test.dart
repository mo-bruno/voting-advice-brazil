import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:guia_eleitoral/core/analytics/analytics_consent_controller.dart';

class _MemoryConsentStore implements AnalyticsConsentStore {
  _MemoryConsentStore({this.saved, this.readError, this.writeError});

  String? saved;
  final Object? readError;
  final Object? writeError;
  final List<String> writes = [];

  @override
  Future<String?> read() async {
    if (readError case final error?) throw error;
    return saved;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    if (writeError case final error?) throw error;
    saved = value;
  }
}

class _RecordingEffects implements AnalyticsConsentEffects {
  _RecordingEffects({this.error});

  final Object? error;
  final List<bool> consentUpdates = [];

  @override
  Future<void> updateConsent({required bool granted}) async {
    consentUpdates.add(granted);
    if (error case final value?) throw value;
  }
}

class _BlockingConsentEffects implements AnalyticsConsentEffects {
  final List<bool> consentUpdates = [];
  final Completer<void> _blocked = Completer<void>();

  void completeConsentUpdate() => _blocked.complete();

  @override
  Future<void> updateConsent({required bool granted}) async {
    consentUpdates.add(granted);
    if (!granted) await _blocked.future;
  }
}

class _FailAfterHydrationEffects implements AnalyticsConsentEffects {
  final List<bool> consentUpdates = [];

  @override
  Future<void> updateConsent({required bool granted}) async {
    consentUpdates.add(granted);
    if (consentUpdates.length > 1) {
      throw StateError('effect failed after hydration');
    }
  }
}

class _FailOnceStore extends _MemoryConsentStore {
  bool failNext = true;

  @override
  Future<void> write(String value) async {
    if (failNext) {
      failNext = false;
      writes.add(value);
      throw StateError('disk unavailable');
    }
    await super.write(value);
  }
}

class _BlockedGrantStore extends _MemoryConsentStore {
  final Completer<void> _grantReleased = Completer<void>();

  void releaseGrant() => _grantReleased.complete();

  @override
  Future<void> write(String value) async {
    if (value == 'granted') await _grantReleased.future;
    await super.write(value);
  }
}

class _BlockedGrantEffects implements AnalyticsConsentEffects {
  final List<bool> consentUpdates = [];
  final Completer<void> _grantReleased = Completer<void>();

  void releaseGrant() => _grantReleased.complete();

  @override
  Future<void> updateConsent({required bool granted}) async {
    consentUpdates.add(granted);
    if (granted) await _grantReleased.future;
  }
}

void main() {
  test('missing or invalid persisted value hydrates as pending', () async {
    for (final value in <String?>[null, '', 'accepted', 'granted-v0']) {
      final controller = AnalyticsConsentController.testOnly(
        store: _MemoryConsentStore(saved: value),
        effects: _RecordingEffects(),
      );
      await controller.hydrate();
      expect(controller.state, AnalyticsConsent.pending);
    }
  });

  test('hydrates only the current granted and denied values', () async {
    for (final entry in {
      'granted': AnalyticsConsent.granted,
      'denied': AnalyticsConsent.denied,
    }.entries) {
      final effects = _RecordingEffects();
      final controller = AnalyticsConsentController.testOnly(
        store: _MemoryConsentStore(saved: entry.key),
        effects: effects,
      );
      await controller.hydrate();
      expect(controller.state, entry.value);
      expect(effects.consentUpdates, [entry.value == AnalyticsConsent.granted]);
    }
  });

  test('failed grant persistence keeps the protective prior state', () async {
    final controller = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(writeError: StateError('disk unavailable')),
      effects: _RecordingEffects(),
    );
    await controller.hydrate();
    expect(await controller.grant(), isFalse);
    expect(controller.state, AnalyticsConsent.pending);
  });

  test('deny closes the in-memory gate before awaiting dependencies', () async {
    final effects = _BlockingConsentEffects();
    final controller = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(saved: 'granted'),
      effects: effects,
    );
    await controller.hydrate();
    final result = controller.deny();
    expect(controller.state, AnalyticsConsent.denied);
    effects.completeConsentUpdate();
    expect(await result, isTrue);
  });

  test('read failure leaves hydration pending and reports a generic error',
      () async {
    final errors = <Object>[];
    final effects = _RecordingEffects();
    final controller = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(readError: StateError('read failed')),
      effects: effects,
      onError: errors.add,
    );
    await expectLater(controller.hydrate(), completes);
    expect(controller.state, AnalyticsConsent.pending);
    expect(effects.consentUpdates, isEmpty);
    expect(errors, hasLength(1));
  });

  test('granted hydration fails closed when its effect throws', () async {
    final errors = <Object>[];
    final controller = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(saved: 'granted'),
      effects: _RecordingEffects(error: StateError('effect failed')),
      onError: errors.add,
    );
    await expectLater(controller.hydrate(), completes);
    expect(controller.state, AnalyticsConsent.pending);
    expect(errors, hasLength(1));
  });

  test('effect failures do not redefine persistence success', () async {
    final grantErrors = <Object>[];
    final grantController = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(),
      effects: _RecordingEffects(error: StateError('grant effect failed')),
      onError: grantErrors.add,
    );
    await grantController.hydrate();
    expect(await grantController.grant(), isTrue);
    expect(grantController.state, AnalyticsConsent.pending);
    expect(grantErrors, hasLength(1));

    final denyErrors = <Object>[];
    final denyController = AnalyticsConsentController.testOnly(
      store: _MemoryConsentStore(saved: 'granted'),
      effects: _FailAfterHydrationEffects(),
      onError: denyErrors.add,
    );
    await denyController.hydrate();
    expect(await denyController.deny(), isTrue);
    expect(denyController.state, AnalyticsConsent.denied);
    expect(denyErrors, hasLength(1));
  });

  test('failed denial write keeps gate closed and can be retried', () async {
    final store = _FailOnceStore()..saved = 'granted';
    final effects = _RecordingEffects();
    final controller = AnalyticsConsentController.testOnly(
      store: store,
      effects: effects,
    );
    await controller.hydrate();
    expect(await controller.deny(), isFalse);
    expect(controller.state, AnalyticsConsent.denied);
    expect(controller.denialPersistenceFailed, isTrue);
    expect(effects.consentUpdates, [true, false]);
    expect(await controller.deny(), isTrue);
    expect(store.saved, 'denied');
    expect(controller.denialPersistenceFailed, isFalse);
  });

  test('failed grant write does not poison later denial', () async {
    final store = _FailOnceStore();
    final controller = AnalyticsConsentController.testOnly(
      store: store,
      effects: _RecordingEffects(),
    );
    await controller.hydrate();
    expect(await controller.grant(), isFalse);
    expect(await controller.deny(), isTrue);
    expect(store.saved, 'denied');
    expect(store.writes, ['granted', 'denied']);
  });

  test('deny overtakes a blocked grant write', () async {
    final store = _BlockedGrantStore();
    final effects = _RecordingEffects();
    final controller = AnalyticsConsentController.testOnly(
      store: store,
      effects: effects,
    );
    await controller.hydrate();
    final grant = controller.grant();
    await Future<void>.delayed(Duration.zero);
    final deny = controller.deny();
    expect(controller.state, AnalyticsConsent.denied);
    expect(effects.consentUpdates, [false]);
    store.releaseGrant();
    expect(await grant, isTrue);
    expect(await deny, isTrue);
    expect(store.saved, 'denied');
    expect(controller.state, AnalyticsConsent.denied);
    expect(effects.consentUpdates, [false]);
  });

  test('deny overtakes a blocked grant effect', () async {
    final store = _MemoryConsentStore();
    final effects = _BlockedGrantEffects();
    final controller = AnalyticsConsentController.testOnly(
      store: store,
      effects: effects,
    );
    await controller.hydrate();
    final grant = controller.grant();
    await Future<void>.delayed(Duration.zero);
    final deny = controller.deny();
    expect(controller.state, AnalyticsConsent.denied);
    expect(effects.consentUpdates, [true, false]);
    effects.releaseGrant();
    expect(await grant, isTrue);
    expect(await deny, isTrue);
    expect(store.saved, 'denied');
    expect(controller.state, AnalyticsConsent.denied);
    expect(effects.consentUpdates.last, isFalse);
  });
}
