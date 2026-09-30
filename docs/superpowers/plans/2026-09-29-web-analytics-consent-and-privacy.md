# Web Analytics Consent and Privacy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Google Analytics opt-in on the Farol Político site, publish a truthful permanent privacy notice and preference controls, and stop the public quiz client from sending its functional UUID when IoT is disabled.

**Architecture:** Hydrate a versioned consent controller before mounting Flutter, keep Firebase entirely uninitialized for `pending` and `denied`, and route every default `AnalyticsService` event through a defensive allowlist plus one lazy Firebase runtime. A nonblocking global banner and `/privacidade` page share that controller; the existing responsive shell remains intact. Build-time public identity values are injected by CI, while the quiz uses its compile-time IoT flag to decide whether `device_id` is needed.

**Tech Stack:** Flutter 3.41.6, Dart, FlutterFire Core 4.7.0, Firebase Analytics 12.3.0, SharedPreferences 2.5.5, dart:js_interop, flutter_test, Chrome test runner, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-09-29-analytics-privacy-and-data-minimization-design.md`

## Global Constraints

- The published product is a Flutter Web site; Android remains safe but is not a release target, and iOS stays unconfigured.
- Consent states are exactly `pending`, `granted`, and `denied`, persisted under `farol_politico_analytics_consent_v1` and hydrated before `runApp`.
- `ANALYTICS_ENABLED` is a separate build-time operational kill switch, defaults to false, and never substitutes for consent. When false it keeps Google consent/collection denied and drops every event without erasing the person's saved choice.
- `pending` and `denied` must not initialize Firebase, create a Firebase Installation ID, load Google tags, write `_ga*`, or send cookieless pings.
- Events discarded before consent are never queued or replayed after consent.
- Web consent default is set before any Firebase `config` or event; only `analytics_storage` may become granted. `ad_storage`, `ad_user_data`, and `ad_personalization` remain denied.
- Firebase remains the only analytics event emitter. Never add `gtag('event')` or another parallel event call.
- Allowed custom events are the existing 23 generic names. Only four events accept non-negative numeric parameters: `thesis_answered`, `quiz_completed`, `weighting_completed`, and `party_selection_completed`.
- No analytics payload may contain thesis identifiers, positions, answers, parties, candidates, affinity, free text, shared content, the main UUID, the follow-interest UUID, or either hash.
- Rejection must be as visually prominent and as easy as acceptance. Navigation, closing, scrolling, and starting the quiz never imply analytics consent.
- Keep the current Flutter hash URL strategy: the named route is `/privacidade` in Dart and its direct browser URL is `/#/privacidade`. Do not add path-strategy/server-rewrite scope to this privacy change.
- The privacy page states that quiz answers can reveal political opinion, are processed transiently to calculate the requested result, and are not persisted in the public IoT-disabled deployment.
- The quiz introduction and the notice immediately above `VER RESULTADOS` state that pressing that action is the specific positive manifestation for transient processing of those potentially sensitive answers; no separate checkbox is added and analytics consent remains independent.
- `PRIVACY_CONTACT_EMAIL` is `privacidade@fpolitico.com.br`; the private forwarding destination must never enter the repository, build flags, UI, logs, or tests.
- `PRIVACY_CONTROLLER_NAME` must be a real civil name or legal entity name. Its current absence blocks production deployment, not local implementation or tests.
- Before production, record outside the repository whether the controller uses the applicable small-agent dispensation or has formally appointed an encarregado; the latter choice requires extending configuration/copy/tests with that person's published identity/contact before deploy.
- The validation interest is described as pseudonymous/“sem nome ou contato,” never anonymous, and retained until withdrawal, experiment closure, or 180 days after registration, whichever comes first.
- Do not add a consent-management vendor, ad products, Google Signals, login, a new scheduler, or new product instrumentation.

## Review Focus

- Consent is revoked while the shared Firebase initialization `Future` is pending: the pending custom event is dropped and denial is applied after initialization; Task 2 pins this.
- A stored consent value is missing, corrupt, or from another version: the controller stays `pending` and no Firebase object is constructed; Task 1 pins this.
- An event name or parameter bypasses a typed `AnalyticsService` method: the allowlist drops the event or strips the key and negative value before Firebase; Task 2 pins this.
- The site is 320 px wide, 390 px wide, 1440 px wide, or uses 200% text scaling: banner actions and privacy controls remain reachable without overflow or covering navigation, and the real pending banner leaves quiz/community actions scrollable and tappable; Tasks 4-7 pin this.
- Saving acceptance fails after a prior denial, or saving revocation fails after a prior grant: acceptance remains closed, while revocation closes the in-memory gate immediately and reports the persistence failure; Tasks 1, 4, and 5 pin this.

---

### Task 1: Build the versioned consent state machine

**Files:**
- Create: `mobile/lib/core/analytics/analytics_consent_controller.dart`
- Create: `mobile/test/analytics_consent_controller_test.dart`

**Interfaces:**
- Consumes: an injected `AnalyticsConsentStore` and `AnalyticsConsentEffects`.
- Produces: `enum AnalyticsConsent { pending, granted, denied }`, `AnalyticsConsentController.state`, `denialPersistenceFailed`, `hydrate()`, `grant()`, and `deny()`. Event routing is deliberately deferred to the independently testable sink in Task 2.

- [ ] **Step 1: Write fakes and failing hydration/persistence tests**

Define the public seams in the test first:

```dart
class _MemoryConsentStore implements AnalyticsConsentStore {
  _MemoryConsentStore({this.saved, this.readError, this.writeError});

  String? saved;
  final Object? readError;
  final Object? writeError;

  @override
  Future<String?> read() async {
    if (readError case final error?) throw error;
    return saved;
  }

  @override
  Future<void> write(String value) async {
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
```

Add tests with these names and exact expectations:

```dart
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
    expect(effects.consentUpdates, [
      entry.value == AnalyticsConsent.granted,
    ]);
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

test('read failure leaves hydration pending and reports a generic error', () async {
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
```

Use this exact fail-after-hydration fake:

```dart
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
```

The diagnostic assertions inspect only the number/type of `Object` errors;
they never add a stored value, event name, payload, UUID, or user-authored text
to the callback contract.

Also test that a failed `deny()` write returns false, leaves `state == denied`
for the running session, and exposes `denialPersistenceFailed == true`;
denial effects are still attempted when persistence fails. A second `deny()`
against a fail-once store must call the store again, return true, persist
`denied`, and clear that flag. Separately, make a grant write fail once and
prove a later denial still reaches the store: the write queue must not stay
poisoned by its predecessor's exception.

Finally, test that `deny()` invoked while a prior `grant()` write or effect is
blocked sends `effects.updateConsent(false)` before the blocked true effect is
released, then finishes with `denied` as the final controller, store, and
effects state. An assertion only about the final state is insufficient for
this race.

- [ ] **Step 2: Run the new file and verify it fails to compile because the contract is absent**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_consent_controller_test.dart
```

Expected: FAIL with missing `analytics_consent_controller.dart` and undefined consent types.

- [ ] **Step 3: Implement the store and controller state transitions**

Create the following public contract:

```dart
enum AnalyticsConsent { pending, granted, denied }

abstract interface class AnalyticsConsentStore {
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class AnalyticsConsentEffects {
  Future<void> updateConsent({required bool granted});
}

class SharedPreferencesAnalyticsConsentStore implements AnalyticsConsentStore {
  static const key = 'farol_politico_analytics_consent_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, value);
    if (!saved) throw StateError('analytics consent was not persisted');
  }
}
```

Implement `AnalyticsConsentController extends ChangeNotifier` with:

```dart
AnalyticsConsentController({
  required AnalyticsConsentStore store,
  required AnalyticsConsentEffects effects,
  void Function(Object error)? onError,
}) : _store = store,
     _effects = effects,
     _onError = onError;

@visibleForTesting
factory AnalyticsConsentController.testOnly({
  required AnalyticsConsentStore store,
  required AnalyticsConsentEffects effects,
  void Function(Object error)? onError,
}) = AnalyticsConsentController;

AnalyticsConsent _state = AnalyticsConsent.pending;
bool _denialPersistenceFailed = false;
AnalyticsConsent get state => _state;
bool get isGranted => _state == AnalyticsConsent.granted;
bool get denialPersistenceFailed => _denialPersistenceFailed;

Future<void> hydrate();
Future<bool> grant();
Future<bool> deny();
```

The normal public constructor is the production path; `testOnly` is only a
named redirect for readable tests and must delegate to it. Both accept the same
generic `void Function(Object error)? onError`; diagnostics receive no event
name, payload, UUID, or stored value. `hydrate()` recognizes only `granted` and
`denied` and catches both read and effect failures so startup always reaches
`runApp`. For a recognized grant, record/apply `effects.updateConsent(true)`
before publishing `state == granted`; an effect failure therefore leaves it
`pending`. For denial, close/publish denial first and then apply false, so an
effect failure remains fail-closed. Effects are contractually lazy and must not
initialize Firebase. Missing, invalid, or unreadable storage remains `pending`
and applies no effect.

Serialize store writes on their own private Future queue and assign every requested decision a monotonically increasing controller revision so the final persisted value follows request order. The queue tail must absorb each completed operation's error before chaining the next write, while the individual caller still receives `false`; one storage exception may never prevent a later `write`. Do **not** put consent effects behind that store queue. `deny()` increments the revision, sets/notifies `denied`, and invokes `effects.updateConsent(false)` immediately; the runtime contract records its newer revision and sets the Web queue denied synchronously before its first await. Persistence may then wait behind an older grant write. A grant persists first, applies true only while its controller revision is current, and publishes `granted` only after that effect was requested. A stale grant never reopens the gate.

The `bool` returned by `grant()`/`deny()` means persistence success only. SDK/bridge-effect errors are caught and sent to `onError`; they do not convert a successfully stored preference into a save failure or prevent the site from mounting. A failed grant write keeps the protective prior state. A failed denial write still leaves the in-memory gate closed, attempts denial effects, sets `denialPersistenceFailed`, and notifies listeners. A later successful denial (including a UI retry) clears that flag; hydration and a successful grant also clear stale failure state.

This task contains no event sink and no temporary no-op event implementation.

- [ ] **Step 4: Run the controller tests**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_consent_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the state machine**

```bash
git add \
  mobile/lib/core/analytics/analytics_consent_controller.dart \
  mobile/test/analytics_consent_controller_test.dart
git commit -m "feat: persist analytics consent state"
```

### Task 2: Add the strict event policy and lazy Firebase runtime

**Files:**
- Create: `mobile/lib/core/analytics/analytics_sink.dart`
- Create: `mobile/lib/core/analytics/analytics_event_policy.dart`
- Create: `mobile/lib/core/analytics/consent_aware_analytics_sink.dart`
- Create: `mobile/lib/core/analytics/analytics_dependencies.dart`
- Create: `mobile/lib/core/analytics/analytics_operational_config.dart`
- Create: `mobile/lib/core/analytics/firebase_analytics_runtime.dart`
- Create: `mobile/lib/core/analytics/analytics_consent_bridge.dart`
- Create: `mobile/lib/core/analytics/analytics_consent_bridge_stub.dart`
- Create: `mobile/lib/core/analytics/analytics_consent_bridge_web.dart`
- Create: `mobile/test/analytics_event_policy_test.dart`
- Create: `mobile/test/consent_aware_analytics_sink_test.dart`
- Create: `mobile/test/firebase_analytics_runtime_test.dart`
- Modify: `mobile/lib/core/analytics/analytics_service.dart`
- Modify: `mobile/test/analytics_service_test.dart`

**Interfaces:**
- Consumes: `AnalyticsConsentController.state`, `Firebase.initializeApp`, `DefaultFirebaseOptions.currentPlatform`, and the browser function `farolSetAnalyticsConsent(bool)`.
- Produces: `SanitizedAnalyticsEvent`, `AnalyticsEventPolicy.sanitize`, `AnalyticsRuntime`, `FirebaseAnalyticsRuntime`, `ConsentAwareAnalyticsSink`, and one production dependency graph shared by UI and `AnalyticsService()`.

- [ ] **Step 1: Write the failing allowlist tests**

Specify the complete event vocabulary:

```dart
const noParameterEvents = {
  'quiz_intro_viewed',
  'quiz_started',
  'quiz_restarted',
  'thesis_viewed',
  'thesis_skipped',
  'weighting_started',
  'weight_added',
  'weight_removed',
  'party_selection_viewed',
  'party_toggled',
  'results_viewed',
  'comparison_opened',
  'comparison_candidate_added',
  'candidate_positions_viewed',
  'follow_waitlist_viewed',
  'follow_waitlist_prompt_viewed',
  'follow_waitlist_cta_clicked',
  'follow_waitlist_registered',
  'follow_waitlist_failed',
};
```

Test each of the 19 names twice: once with `parameters == null`, and once with
this hostile map. In both cases the event survives but its output parameters
are exactly null:

```dart
const hostileParameters = {
  'candidate_id': '13',
  'stance': 'agree',
  'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
  'device_id': '550e8400-e29b-41d4-a716-446655440001',
  'free_text': 'conteúdo político',
  'count': 1,
};
```

Also test that an unknown event returns null and that the policy transforms this input:

```dart
final event = AnalyticsEventPolicy.sanitize(
  name: 'quiz_completed',
  parameters: {
    'total_answered': 24,
    'total_skipped': 6,
    'duration_ms': 83000,
    'candidate_id': '13',
    'affinity': 91.2,
    'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
  },
);

expect(event?.parameters, {
  'total_answered': 24,
  'total_skipped': 6,
  'duration_ms': 83000,
});
```

For `thesis_answered`, negative duration, string duration, decimal, `double.nan`, infinity, stance, and thesis ID must all be omitted. The current typed service emits integer counters/durations, so the policy accepts only `int >= 0`. The other allowed maps are:

```dart
const allowedParameterKeys = {
  'thesis_answered': {'time_to_answer_ms'},
  'quiz_completed': {'total_answered', 'total_skipped', 'duration_ms'},
  'weighting_completed': {'count_weighted'},
  'party_selection_completed': {'count_selected'},
};
```

For each of those four event names, add a table-driven case containing every
allowed key with a non-negative integer plus every hostile key above. Assert
that all and only its declared schema keys survive. Include a case where all
declared values are invalid and output parameters becomes null.

Also prove the sanitized object cannot be changed after validation: mutate the
caller's input map after `sanitize` and assert the event remains unchanged;
then attempt to assign/remove through `event.parameters!` and require
`UnsupportedError`. This guards the public event/runtime seam against adding a
forbidden key after sanitization.

- [ ] **Step 2: Run the policy test and verify the missing implementation**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_event_policy_test.dart
```

Expected: FAIL because the policy types do not exist.

- [ ] **Step 3: Implement the immutable sanitized event and policy**

Use this public shape:

```dart
class SanitizedAnalyticsEvent {
  SanitizedAnalyticsEvent({
    required this.name,
    Map<String, Object>? parameters,
  }) : parameters = parameters == null || parameters.isEmpty
           ? null
           : Map.unmodifiable(Map<String, Object>.of(parameters));

  final String name;
  final Map<String, Object>? parameters;
}

abstract final class AnalyticsEventPolicy {
  static SanitizedAnalyticsEvent? sanitize({
    required String name,
    Map<String, Object>? parameters,
  });
}
```

Return null for names outside the 23-item map. For allowed keys, copy only
values that are `int` and `>= 0`; return `parameters: null` when nothing
remains. Never mutate the caller's map, and expose only the constructor's
defensive unmodifiable copy.

- [ ] **Step 4: Write runtime and consent-aware sink tests before Firebase code**

Add tests proving:

```dart
test('pending and denied discard without initializing runtime', () async { /* both states */ });
test('operational kill switch discards even when consent is granted', () async { /* no init and effective consent false */ });
test('unknown granted event is dropped before runtime initialization', () async { /* init 0 */ });
test('discarded events are not replayed after grant', () async { /* grant then expect only new event */ });
test('concurrent granted events share one initialization', () async { /* two Futures, initializeCalls == 1 */ });
test('revocation during initialization drops the waiting event', () async { /* block init, deny, release, events empty */ });
test('stale grant effects cannot re-enable collection after revocation', () async { /* block true, request false, release, final false */ });
test('denial still disables collection when consent update throws', () async { /* both denial calls attempted */ });
test('reacceptance sends only events logged after reacceptance', () async { /* old denied event absent */ });
test('client construction failure is contained and a later event retries', () async { /* no first event */ });
test('granted consent failure leaves no ready client and later reapplies', () async { /* full retry */ });
test('collection enable failure leaves no ready client and later reapplies', () async { /* full retry */ });
test('missing Web bridge blocks initialization and a later event retries', () async { /* init 0, then bridge succeeds */ });
test('failed consent effect does not poison the next denial', () async { /* later false reaches SDK */ });
test('failed bridge on reacceptance keeps an existing client denied', () async { /* later bridge retry */ });
test('runtime re-sanitizes a directly constructed hostile event', () async { /* forbidden keys stripped */ });
test('runtime drops a directly constructed unknown event', () async { /* SDK receives nothing */ });
```

The fake runtime must expose completers so the sink test can revoke between initialization start and completion. Assert that failures are represented only by a generic diagnostic callback such as `void Function(Object error)`; event names, parameters, and UUID-like values are not passed to diagnostics. Keep the grant/deny ordering tests in `analytics_consent_controller_test.dart`.

For the missing-bridge regression, inject a mutable bridge seam that initially
returns `false`, grant consent, and log an allowed event. Assert
`initializeCalls == 0` and `events.isEmpty`. Change the seam to return `true`,
log a new event, and assert one initialization plus only that second event.
For queue recovery, make the first granted SDK consent call throw, then request
denial and assert both the denied consent call and collection-disable call were
attempted and became the final recorded state.

Exercise the three preparation failure points separately: client construction,
`applyConsent(granted: true)`, and `setCollectionEnabled(true)`. In each case
the first allowed event is absent and no event-ready client is observable. For
the latter two failures, assert fail-closed rollback attempts both
`applyConsent(false)` and `setCollectionEnabled(false)` independently before
returning, even if the first rollback call also throws. A subsequent explicit
denial must repeat both protections against that retained non-ready client.
Make the fake succeed, log a second allowed event, and assert that construction
(when applicable), granted consent, and collection enable run to completion
before exactly that second event is recorded; no partially prepared client may
skip the retry.

For reacceptance with an existing SDK client, start granted and emit one event,
deny, make the bridge return false, then grant and attempt another event.
Assert the second event is absent, no SDK grant/enable occurs after the failed
bridge, and the effective SDK state remains denied. Restore the bridge, log one
new event, and assert only this third event is added after consent and
collection are fully re-enabled.

For the direct-runtime bypass regression, prepare a granted/event-ready fake
client, bypass `ConsentAwareAnalyticsSink`, and call `runtime.logEvent` with a
publicly constructed event containing `candidate_id`, `stance`, and a UUID.
Assert the SDK receives only a newly sanitized allowed event with those keys
removed. Repeat with an unknown name and assert the SDK receives nothing. The
runtime is a second enforcement boundary, not a trusted caller of the sink.

- [ ] **Step 5: Run the runtime and sink tests and observe RED**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/consent_aware_analytics_sink_test.dart \
  test/firebase_analytics_runtime_test.dart
```

Expected: FAIL because the consent-aware sink, bridge, and Firebase runtime do
not exist. This RED run occurs before any of their implementation files are
created and pins lazy initialization, revocation races, fail-closed retries,
and the second sanitization boundary.

- [ ] **Step 6: Implement the Web/stub consent bridge**

`analytics_consent_bridge.dart` conditionally exports the Web implementation:

```dart
export 'analytics_consent_bridge_stub.dart'
    if (dart.library.js_interop) 'analytics_consent_bridge_web.dart';
```

The stub returns success without work. The Web file calls only the inline
browser function and converts a missing/mixed-cache function into `false`:

```dart
@JS('farolSetAnalyticsConsent')
external void _farolSetAnalyticsConsent(JSBoolean granted);

bool setWebAnalyticsConsent({required bool granted}) {
  try {
    _farolSetAnalyticsConsent(granted.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
```

The stub has the same signature and returns `true`. There is no Dart
`gtag('event')` function.

- [ ] **Step 7: Implement the lazy runtime with one initialization Future**

Define:

```dart
abstract interface class AnalyticsRuntime implements AnalyticsConsentEffects {
  Future<void> initializeForGrantedConsent();
  Future<void> logEvent(SanitizedAnalyticsEvent event);
}

abstract interface class AnalyticsSdkClient {
  Future<void> applyConsent({required bool granted});
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> logEvent(SanitizedAnalyticsEvent event);
}
```

Define `AnalyticsOperationalConfig.enabled` as `bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: false)`. `FirebaseAnalyticsRuntime` accepts injectable `bool operationallyEnabled`, `bool Function() isSupportedPlatform`, `Future<AnalyticsSdkClient> Function() initializeClient`, and `bool Function({required bool granted}) setWebConsent` seams. Production defaults take the kill switch from `AnalyticsOperationalConfig`, restrict support to Web/Android, initialize Firebase, and wrap `FirebaseAnalytics`; VM tests inject deterministic fakes and therefore exercise initialization/retry/order rather than a Linux no-op.

The runtime keeps `Future<void>? _initialization`, an
`AnalyticsSdkClient? _sdkClient` retained for protective disable calls, a
separate `_eventReady` boolean, one serialized consent-effects queue, a
monotonically increasing consent revision, the latest requested grant/denial
even when no client exists, and whether the latest Web consent queue update
succeeded. `initializeForGrantedConsent()` returns the same in-flight future to
all callers. It may return early only when `_sdkClient != null`, `_eventReady`,
the latest effective request is granted, and the Web bridge is ready; client
existence alone is insufficient. Before constructing or reusing the SDK client
it retries `setWebConsent` with the latest effective state; if the bridge
returns `false`, it clears event readiness and the in-flight initialization and
fails closed without calling `initializeClient` or granting/enabling the SDK.
Only after that queue update succeeds does it construct or reuse a candidate,
retain it in `_sdkClient` for fail-closed operations, and fully apply the
latest requested consent/collection state. `_eventReady` becomes true only
after a stable granted preparation succeeds:

```dart
final candidate = _sdkClient ?? await initializeClient();
_sdkClient = candidate;
await _applyLatestRequestedConsent(candidate);
_eventReady = _latestEffectiveGrant && _webConsentReady;
```

The production `initializeClient` closure performs `Firebase.initializeApp`
(or reuses `Firebase.app()`), obtains `FirebaseAnalytics.instanceFor(app:)`,
and returns `FirebaseAnalyticsSdkClient`. `_applyLatestRequestedConsent` takes
the candidate explicitly and rechecks the revision after each await; if a
newer denial arrived, it loops and applies denial plus collection-disabled to
that same candidate before publication.

Initialization must not force a stale granted state. Web starts from the inline default-denied queue and Android from disabled manifest metadata. A grant requested before the client exists records `true`; a revocation during initialization overwrites it with `false`; client creation applies whichever revision is newest. This is what prevents an older in-flight initialization from undoing revocation.

`FirebaseAnalyticsSdkClient.applyConsent` performs:

```dart
await analytics.setConsent(
  analyticsStorageConsentGranted: granted,
  adStorageConsentGranted: false,
  adUserDataConsentGranted: false,
  adPersonalizationSignalsConsentGranted: false,
);
```

The production `AnalyticsSdkClient` owns the Firebase-specific calls shown above; the runtime itself stays testable with a fake. On unsupported platforms it resolves without Firebase. If client construction fails, clear `_initialization` and event readiness so a later authorized event can construct again. If granted `applyConsent` or collection enable fails, synchronously clear event readiness, attempt a Web consent update to denied, then attempt `candidate.applyConsent(granted: false)` and `candidate.setCollectionEnabled(false)` independently so failure of either cannot skip the other. Retain `_sdkClient = candidate` for a later denial/retry, clear `_initialization`, and report a generic preparation/rollback error. `logEvent` may call the retained client only when operationally enabled, the latest effective request is granted, the bridge is ready, and `_eventReady` is true.

`updateConsent(granted:)` computes `effectiveGrant = operationallyEnabled && granted`, synchronously clears `_eventReady`, records that latest effective state with a new revision, and synchronously attempts the Web queue update before its first await. A `false` bridge result is reported as a generic effect error, marks the bridge unready, and can never be treated as permission to initialize or re-enable an existing client; startup and the rest of the site continue. It then serializes SDK effects. As with the store queue, its internal queue tail must recover after each operation so a failed grant/SDK call cannot suppress a later denial. If the SDK client exists and `effectiveGrant` is true, apply consent first and enable collection only if the bridge succeeded, the consent call succeeds, and the revision remains current; only then set `_eventReady`. For denial, attempt `applyConsent(false)` and `setCollectionEnabled(false)` independently against `_sdkClient` even when it never became event-ready, so failure of either cannot skip the other; report an error only after both protections were attempted. Before completing, a stale grant must observe the newer revision and refrain from becoming the final state; the newest request is applied last. It must not initialize Firebase by itself. A denial request or disabled kill switch always leaves event readiness false and the SDK consent/collection state denied even if an older grant call completes late; when the Web bridge is temporarily unavailable, no new Firebase initialization, re-enabling, or event is permitted until a later authorized event successfully retries the queue update.

`logEvent` first passes the received object's name/parameters through
`AnalyticsEventPolicy.sanitize` again, even though the normal sink already did
so. It drops an unknown result and sends only this newly sanitized object to
the SDK; it never forwards the caller's object directly. It also returns
without work when unsupported-platform initialization produced no client or
when any readiness condition is false. It never uses a nullable client
assertion to turn Linux/test no-op behavior into an exception.

- [ ] **Step 8: Compose the consent-aware sink and switch the default service**

Move `AnalyticsSink` into `analytics_sink.dart` and re-export it from `analytics_service.dart` so existing imports remain source-compatible. Remove `FirebaseAnalyticsSink` entirely; only `firebase_analytics_runtime.dart` may import Firebase Analytics.

`ConsentAwareAnalyticsSink` also receives the same immutable `operationallyEnabled` value. Its `logEvent` must:

```dart
if (!operationallyEnabled || !controller.isGranted) return;
final event = AnalyticsEventPolicy.sanitize(
  name: name,
  parameters: parameters,
);
if (event == null) return;
try {
  await runtime.initializeForGrantedConsent();
  if (!controller.isGranted) {
    await runtime.updateConsent(granted: false);
    return;
  }
  await runtime.logEvent(event);
} catch (error) {
  onError?.call(error);
}
```

Create `AnalyticsDependencies` with a private production factory that reads
`AnalyticsOperationalConfig.enabled` once, constructs exactly one runtime,
and uses the controller's normal public constructor with the real store. Give
that same runtime to the controller as its effects implementation and to
`ConsentAwareAnalyticsSink`, and expose `controller` and `sink`:

```dart
void _reportGenericAnalyticsError(Object error) {
  if (kDebugMode) {
    debugPrint('Analytics operation failed (${error.runtimeType}).');
  }
}

final runtime = FirebaseAnalyticsRuntime(
  operationallyEnabled: operationallyEnabled,
  onError: _reportGenericAnalyticsError,
);
final controller = AnalyticsConsentController(
  store: SharedPreferencesAnalyticsConsentStore(),
  effects: runtime,
  onError: _reportGenericAnalyticsError,
);
final sink = ConsentAwareAnalyticsSink(
  controller: controller,
  runtime: runtime,
  operationallyEnabled: operationallyEnabled,
  onError: _reportGenericAnalyticsError,
);
```

`_reportGenericAnalyticsError` accepts only `Object` and never receives event
names, parameters, UUIDs, stored values, or free text. The static `instance` is
the production graph; a
`@visibleForTesting AnalyticsDependencies.testOnly({required controller,
required sink})` factory never replaces the production singleton. Production
code must not call `AnalyticsConsentController.testOnly`. Change the default
`AnalyticsService` construction to use the graph while preserving explicit
injected sinks:

```dart
AnalyticsService({AnalyticsSink? sink})
    : _sink = sink ?? AnalyticsDependencies.instance.sink;
```

Rename the analytics-service test text from “anonymous follow validation” to “pseudonymous follow validation” or “follow-interest validation.”

- [ ] **Step 9: Run the focused analytics tests**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_consent_controller_test.dart \
  test/analytics_event_policy_test.dart \
  test/consent_aware_analytics_sink_test.dart \
  test/firebase_analytics_runtime_test.dart \
  test/analytics_service_test.dart
```

Expected: PASS with 23 allowed names, four parameter schemas, lazy initialization, race handling, and no replay.

- [ ] **Step 10: Commit the analytics core**

```bash
git add mobile/lib/core/analytics mobile/test/analytics_consent_controller_test.dart \
  mobile/test/analytics_event_policy_test.dart \
  mobile/test/consent_aware_analytics_sink_test.dart \
  mobile/test/firebase_analytics_runtime_test.dart \
  mobile/test/analytics_service_test.dart
git commit -m "feat: gate analytics behind explicit consent"
```

### Task 3: Make browser and Android bootstrap private by default

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Modify: `mobile/web/index.html`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/pubspec.lock`
- Move: `mobile/test/fixtures/fonts/Inter-Regular.ttf` → `mobile/assets/fonts/Inter-Regular.ttf`
- Move: `mobile/test/fixtures/fonts/Inter-SemiBold.ttf` → `mobile/assets/fonts/Inter-SemiBold.ttf`
- Move: `mobile/test/fixtures/fonts/Inter-ExtraBold.ttf` → `mobile/assets/fonts/Inter-ExtraBold.ttf`
- Move: `mobile/test/fixtures/fonts/OFL.txt` → `mobile/assets/fonts/Inter-OFL.txt`
- Move: `mobile/test/fixtures/fonts/SOURCES.md` → `mobile/assets/fonts/Inter-SOURCES.md`
- Modify: `mobile/tool/generate_web_brand_assets.py`
- Modify: `mobile/branding/README.md`
- Modify: `mobile/test/analytics_default_pipeline_web_test.dart`
- Create: `mobile/test/analytics_bootstrap_files_test.dart`
- Modify: `mobile/test/app_drawer_test.dart`
- Modify: `mobile/test/community_error_handling_test.dart`
- Modify: `mobile/test/community_feed_chrome_test.dart`
- Modify: `mobile/test/community_feed_states_test.dart`
- Modify: `mobile/test/community_vote_test.dart`
- Modify: `mobile/test/create_post_page_test.dart`
- Modify: `mobile/test/drawer_chrome_test.dart`
- Modify: `mobile/test/drawer_farol_status_tile_test.dart`
- Modify: `mobile/test/drawer_followed_actor_tile_test.dart`
- Modify: `mobile/test/drawer_quiz_affinity_tile_test.dart`
- Modify: `mobile/test/iot_device_page_test.dart`
- Modify: `mobile/test/iot_feature_flag_test.dart`
- Modify: `mobile/test/navigation_shell_wiring_test.dart`
- Modify: `mobile/test/news_states_test.dart`
- Modify: `mobile/test/political_actor_profile_page_test.dart`
- Modify: `mobile/test/politician_follow_validation_page_test.dart`
- Modify: `mobile/test/post_detail_removed_test.dart`
- Modify: `mobile/test/quiz_evidence_flow_test.dart`
- Modify: `mobile/test/quiz_explanation_test.dart`
- Modify: `mobile/test/results_exit_test.dart`
- Modify: `mobile/test/shell_drawer_test.dart`
- Modify: `mobile/test/tab_pages_leading_test.dart`
- Modify: `mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: `AnalyticsDependencies.instance.controller`, `AnalyticsDependencies.testOnly(...)`, and `farolSetAnalyticsConsent(bool)` from Task 2.
- Produces: no Firebase initialization during startup; default-denied Web queue before Flutter; overridable disabled collection on Android; and locally bundled Inter fonts with no runtime Google Fonts dependency.

- [ ] **Step 1: Write static bootstrap tests before editing platform files**

Read `web/index.html`, `lib/main.dart`, `lib/core/theme/app_theme.dart`,
`pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`,
`tool/generate_web_brand_assets.py`, and `branding/README.md` and assert:

```dart
expect(index, contains("gtag('consent', 'default'"));
expect(index, contains("'analytics_storage': 'denied'"));
expect(index, contains("'ad_storage': 'denied'"));
expect(index, contains("'ad_user_data': 'denied'"));
expect(index, contains("'ad_personalization': 'denied'"));
expect(index.indexOf("gtag('consent', 'default'"),
    lessThan(index.indexOf('flutter_bootstrap.js')));
expect(index, isNot(contains('googletagmanager.com/gtag/js')));
expect(index, isNot(contains("gtag('js'")));
expect(index, isNot(contains("gtag('config'")));
expect(index, isNot(contains("gtag('event'")));
expect(mainSource, isNot(contains('Firebase.initializeApp')));
expect(manifest, contains('firebase_analytics_collection_enabled'));
expect(manifest, contains('android:value="false"'));
expect(themeSource, isNot(contains('GoogleFonts')));
expect(themeSource, isNot(contains('package:google_fonts')));
expect(pubspec, isNot(contains('google_fonts:')));
expect(pubspec, contains('family: Inter'));
expect(pubspec, contains('assets/fonts/Inter-Regular.ttf'));
expect(pubspec, contains('assets/fonts/Inter-SemiBold.ttf'));
expect(pubspec, contains('assets/fonts/Inter-ExtraBold.ttf'));
expect(pubspec, contains('assets/fonts/Inter-OFL.txt'));
expect(brandExporter, contains('ROOT / "assets/fonts"'));
expect(brandExporter, contains('assets/fonts/Inter-OFL.txt'));
expect(brandExporter, isNot(contains('test/fixtures/fonts')));
expect(brandReadme, contains('mobile/assets/fonts'));
expect(brandReadme, isNot(contains('mobile/test/fixtures/fonts')));
expect(brandReadme, isNot(contains('As fontes são usadas somente na exportação')));
expect(brandReadme, contains('tema Flutter'));
expect(brandReadme, contains('exportador'));
expect(AppTheme.dark.textTheme.bodyMedium!.fontFamily, 'Inter');
```

Concatenate the production Dart files under `lib/core/analytics` and assert the
same closed command surface: no `gtag('js')`, `gtag('config')`, or
`gtag('event')` literal. Only the Web bootstrap's inline `consent` default and
update calls are allowed.

Recursively read every Dart file under `mobile/test` except
`analytics_bootstrap_files_test.dart` itself and assert that none contains
`package:google_fonts` or `GoogleFonts.`. The scanner test necessarily contains
those literals as its forbidden patterns, so including itself would make it
self-fail. Keep the dedicated assertions above against `themeSource`. Also
assert that all five local Inter asset/license/provenance files exist. Across
every other test file, require zero occurrences of `test/fixtures/fonts`,
`Inter_regular`, `Inter_600`, or `Inter_800`; build those forbidden strings in
the scanner test without making it match itself.

- [ ] **Step 2: Run the bootstrap test and verify the expected failures**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter pub get
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_bootstrap_files_test.dart
```

Expected: FAIL because startup still initializes Firebase, no default consent/platform metadata exists, and the theme still depends on a runtime Google font provider.

- [ ] **Step 3: Replace eager Firebase startup with consent hydration**

`main.dart` becomes responsible only for Flutter binding, local consent hydration, and mounting:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analytics = AnalyticsDependencies.instance;
  await analytics.controller.hydrate();
  runApp(const MyApp());
}
```

Remove `firebase_core`, `foundation`, and `firebase_options` imports from this file. `MyApp` and the default `AnalyticsService` both resolve the same production singleton, so Task 3 does not depend on the injectable `MyApp.analyticsConsent` parameter introduced later in Task 4.

- [ ] **Step 4: Add the inline default-denied queue without loading a tag**

Immediately before `flutter_bootstrap.js` in `web/index.html`, add:

```html
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('consent', 'default', {
    'analytics_storage': 'denied',
    'ad_storage': 'denied',
    'ad_user_data': 'denied',
    'ad_personalization': 'denied'
  });
  window.farolSetAnalyticsConsent = function(granted) {
    gtag('consent', 'update', {
      'analytics_storage': granted ? 'granted' : 'denied',
      'ad_storage': 'denied',
      'ad_user_data': 'denied',
      'ad_personalization': 'denied'
    });
  };
</script>
```

This code only populates the local queue; it contains no external `src`, `config`, or event command.

- [ ] **Step 5: Disable Android automatic collection until runtime opt-in**

Inside `<application>` add:

```xml
<meta-data
    android:name="firebase_analytics_collection_enabled"
    android:value="false" />
```

Do not use `firebase_analytics_collection_deactivated`, because that cannot be re-enabled after consent.

- [ ] **Step 6: Bundle Inter locally and remove the runtime Google Fonts dependency**

Move the three already versioned Inter TTF fixtures into `mobile/assets/fonts/`
and move their OFL/provenance files with them, using the exact destination
names in this task's file list. Update `Inter-SOURCES.md` to say that the files
are bundled application assets rather than test-only fixtures; retain the
source URL pattern and all three existing hashes.

PR #63 made the same Inter files inputs to the deterministic Feixe/social
preview exporter. Update `tool/generate_web_brand_assets.py` so `FONTS` points
to `ROOT / "assets/fonts"` and its docstring names
`assets/fonts/Inter-OFL.txt`; update `branding/README.md` to the same asset
directory and state truthfully that the same local files now serve both the
Flutter theme and the deterministic exporter, without network access. Remove
the now-false sentence that they are used “somente na exportação.” Do not
regenerate or alter the approved branding images merely for this path move.
The static test must prove the exporter and its documentation contain no stale
`test/fixtures/fonts` reference or export-only claim.

In `pubspec.yaml`, add the locally bundled family:

```yaml
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-ExtraBold.ttf
          weight: 800
```

Also list `assets/fonts/Inter-OFL.txt` and
`assets/fonts/Inter-SOURCES.md` under `flutter.assets` so the distributed
artifact retains the license and provenance alongside the registered font
faces.

Remove the `google_fonts` import and dependency. Replace
`GoogleFonts.interTextTheme(const TextTheme(...))` with
`const TextTheme(...).apply(fontFamily: 'Inter')`, preserving every explicit
size, weight, color, and height. Keep the already bundled `BarlowCondensed`
display family unchanged.

Remove the `package:google_fonts/google_fonts.dart` import and every
`GoogleFonts.config.allowRuntimeFetching = false` setup call from the 23 test
files listed above. Both `app_drawer_test.dart` and
`quiz_explanation_test.dart` currently have manual loaders for the three old
fixture paths and runtime aliases. Keep deterministic loading where needed,
but load `assets/fonts/Inter-Regular.ttf` into the exact family
`FontLoader('Inter')`, then assert the theme's `bodyMedium.fontFamily` is
`Inter`; do not retain the unrelated `Inter_regular`, `Inter_600`, or
`Inter_800` aliases in either file. The local theme no longer depends on a
Google Fonts runtime alias. Run
`flutter pub get` so `pubspec.lock` drops the unused direct/transitive package
entries.

This reuses the exact checked-in font bytes and license rather than downloading
a new font or adding a remote request. The release build will also use
Flutter's `--no-web-resources-cdn` flag in Task 8 so engine assets are
self-hosted.

- [ ] **Step 7: Rewrite the Chrome pipeline test around consent**

`flutter test --platform chrome` does not load `web/index.html`, so install a temporary `globalContext['farolSetAnalyticsConsent']` callback in the test and remove it in `addTearDown`. Build `AnalyticsDependencies.testOnly(...)` around an injected runtime factory that initializes the mocked Firebase app only when invoked. Pass `operationallyEnabled: true` to both `FirebaseAnalyticsRuntime` and `ConsentAwareAnalyticsSink`; otherwise the safe default would make an event-free test pass without exercising consent. The `_RecordingAnalyticsPlatform` must override `logEvent`, `setConsent`, and `setAnalyticsCollectionEnabled`; otherwise the latter two throw `UnimplementedError`.

The browser test must start with Firebase uninitialized, then assert through `AnalyticsService(sink: dependencies.sink)`:

```dart
expect(Firebase.apps, isEmpty);
await service.quizStarted();
expect(firebaseCalls, isEmpty);

await controller.grant();
expect(Firebase.apps, isEmpty);
await service.quizStarted();

expect(firebaseCalls, ['quiz_started']);
expect(consentBridgeCalls, contains(true));
expect(platformConsentCalls.last.analyticsStorage, isTrue);
expect(collectionEnabledCalls.last, isTrue);
```

Retain the platform-interface recording double so the test proves a single Firebase `logEvent` call. No test helper invokes or defines `gtag('event')`; the static bootstrap test separately proves the source has no such command. Add denial and revocation assertions without manually initializing Firebase at test start, and restore Firebase/JS globals in teardown.

- [ ] **Step 8: Run bootstrap and Chrome tests**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter pub get
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_bootstrap_files_test.dart
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  --platform chrome test/analytics_default_pipeline_web_test.dart
```

Expected: both PASS; Chrome observes consent commands and exactly one Firebase event, with no gtag event or runtime Google Fonts dependency.

- [ ] **Step 9: Commit platform bootstrap**

```bash
git add mobile/lib/main.dart mobile/lib/core/theme/app_theme.dart \
  mobile/assets/fonts mobile/pubspec.yaml mobile/pubspec.lock mobile/web/index.html \
  mobile/android/app/src/main/AndroidManifest.xml \
  mobile/tool/generate_web_brand_assets.py mobile/branding/README.md \
  mobile/test
git commit -m "fix: keep analytics disabled before consent"
```

### Task 4: Publish the permanent privacy page and preference controls

**Files:**
- Create: `mobile/lib/features/privacy/privacy_config.dart`
- Create: `mobile/lib/features/privacy/privacy_page.dart`
- Create: `mobile/test/privacy_page_test.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/shared/widgets/app_drawer.dart`
- Modify: `mobile/test/app_drawer_test.dart`

**Interfaces:**
- Consumes: `AnalyticsConsentController`, `AnalyticsDependencies.instance`, `PrivacyConfig.environment`, the existing `LinkOpener` seam, and route name `/privacidade`.
- Produces: a scrollable public notice, current consent/persistence status, accept/reject/revoke/retry controls, a stable root `ScaffoldMessenger`, and drawer navigation to the page.

- [ ] **Step 1: Specify public configuration and page content in tests**

The configuration type is:

```dart
class PrivacyConfig {
  const PrivacyConfig({
    required this.controllerName,
    required this.contactEmail,
  });

  final String controllerName;
  final String contactEmail;

  static const environment = PrivacyConfig(
    controllerName: String.fromEnvironment('PRIVACY_CONTROLLER_NAME'),
    contactEmail: String.fromEnvironment('PRIVACY_CONTACT_EMAIL'),
  );
}
```

Pump `PrivacyPage` through its real constructor with a test controller, a
`PrivacyConfig`, and a fake link seam:

```dart
final openedUris = <Uri>[];
final controller = AnalyticsConsentController.testOnly(
  store: _MemoryConsentStore(),
  effects: _RecordingEffects(),
);
await controller.hydrate();
addTearDown(controller.dispose);
await tester.pumpWidget(MaterialApp(
  home: PrivacyPage(
    consentController: controller,
    config: const PrivacyConfig(
      controllerName: 'Responsável de Teste',
      contactEmail: 'privacidade@fpolitico.com.br',
    ),
    openLink: (uri) async {
      openedUris.add(uri);
      return true;
    },
  ),
));
```

Define the two small local fakes in `privacy_page_test.dart` with the same
`AnalyticsConsentStore`/`AnalyticsConsentEffects` contracts from Task 1. Use
`openedUris` in the mail and Google-link tests. Assert these headings and
claims are visible after scrolling:

```text
PRIVACIDADE E DADOS
Quem decide e como falar conosco
Finalidades e bases legais
Métricas opcionais
Quiz e respostas políticas
Identidades funcionais e comunidade
Validação da área Acompanhar
Compartilhamento do resultado
Fornecedores e transferências
Retenção e segurança
Seus direitos
```

Assert the page explains:

- quiz answers may reveal political opinion and are processed by the API only to calculate the requested result;
- the legal-basis map distinguishes optional Analytics consent; specific highlighted consent for transient quiz processing; the person's explicit publication/registration actions for community and follow-interest features; legitimate-interest/security processing for rate limiting and abuse prevention; and legal-obligation/exercise-of-rights retention where applicable;
- in the public IoT-disabled version, those answers and `device_id` are not persisted;
- Analytics is based on consent and receives only the allowed generic data after acceptance;
- the analytics choice itself is saved locally so the site can remember it;
- after acceptance Google may store `_ga` cookies and a Firebase Installation
  ID locally; revocation stops future Analytics collection but does not
  automatically erase those local identifiers or data already received;
  applicable deletion/right requests use the public privacy channel;
- Google/GA4, Firebase Installation ID after acceptance, and BigQuery are identified;
- the main local UUID supports community and retained functional features, with no account recovery;
- `politician_follow_interests` stores a contextual hash and registration date, can be withdrawn from the same browser, and has the 180-day maximum;
- posts/comments go to NVIDIA NIM for moderation;
- voluntary sharing sends the chosen image/text to the destination selected by the user;
- Cloud Run/Cloud Logging, Neon/PostgreSQL, Google Cloud, ImprovMX, and Google email processing are disclosed at the necessary level;
- privacy-request messages are retained only while handling the request and for the documented period needed to demonstrate legal compliance, with the delivered mailbox copy distinguished from ImprovMX's verified Minimum-detail 7-day forwarding logs;
- page/referrer, approximate location derived by providers, browser/device, IP in transit/logs, international processing, retention criteria, and LGPD article 18 rights are not denied or disguised as anonymous;
- the notice links to Google's partner-site data explanation and the public email via `mailto:`.

Do not present legitimate interest as a basis for the political-opinion content itself. The notice must tie sensitive quiz content to the highlighted `VER RESULTADOS` manifestation and user-authored community content to the deliberate `PUBLICAR` or `ENVIAR COMENTÁRIO` action, while explaining that later security/legal retention has its own limited purpose.

Pin the substantive copy in test fixtures and implement it section by section with these exact claims (line wrapping may differ):

```text
Quem decide e como falar conosco
O controlador deste site é {controllerName}. Pedidos sobre privacidade podem
ser enviados para {contactEmail}.

Finalidades e bases legais
Métricas opcionais usam consentimento e podem ser recusadas ou revogadas. O
processamento transitório das respostas políticas do quiz usa a manifestação
específica e destacada em VER RESULTADOS. PUBLICAR, ENVIAR COMENTÁRIO e registrar
interesse são ações deliberadas para as respectivas funções, precedidas de
aviso específico. Interesse legítimo não fundamenta o conteúdo político: ele
é usado apenas, quando aplicável e após avaliação, para segurança, limitação
de abuso e proteção do serviço. Obrigação legal e exercício de direitos podem
justificar conservação excepcional e limitada.

Métricas opcionais
O Google Analytics só é ativado se você aceitar. Depois do aceite, podemos
enviar eventos genéricos de uso e desempenho, página e referência, informações
do navegador/dispositivo e um Firebase Installation ID pseudônimo. Google,
Firebase Analytics, GA4 e BigQuery podem processar esses dados, inclusive fora
do Brasil. Provedores também podem tratar endereço IP em trânsito e em
registros técnicos e estimar localização aproximada. Não enviamos respostas do quiz,
candidatos, partidos, afinidade, texto livre ou identificadores funcionais aos
eventos de Analytics. Não usamos esses dados para publicidade. Você pode
rejeitar ou revogar sem perder funções do site.
Sua escolha sobre métricas é salva localmente no navegador para que o site
possa lembrá-la. Após o aceite, o Google pode gravar cookies `_ga` e um Firebase
Installation ID no navegador. Revogar interrompe novos envios, mas não apaga
automaticamente esses identificadores locais nem eventos já recebidos, que
seguem os prazos abaixo e os direitos que você pode exercer pelo canal de
privacidade.

Quiz e respostas políticas
Suas respostas do quiz podem revelar opinião política. Quando você pede o
cálculo, elas são enviadas à nossa API e processadas de forma transitória para
comparar suas escolhas com posições documentadas. Na versão pública, com o
recurso IoT desligado, não enviamos o UUID funcional local do navegador no
quiz e não armazenamos essas respostas. A ação destacada VER RESULTADOS é sua manifestação
positiva e específica para esse processamento; ela não aceita métricas.

Identidades funcionais e comunidade
O navegador mantém um identificador aleatório local para funções como
comunidade e acompanhamento. Ele não contém seu nome ou e-mail, mas é
pseudônimo e não oferece recuperação de conta se for perdido. Posts e
comentários podem revelar opinião política. Ao tocar em PUBLICAR ou ENVIAR COMENTÁRIO
depois do aviso destacado, você concorda com o armazenamento, moderação via
NVIDIA NIM e publicação do texto sob um alias pseudônimo estável; não inclua
dados pessoais que não queira tornar públicos. O autor pode remover o conteúdo
do próprio post, que vira uma lápide; os comentários permanecem para preservar
a discussão. Para retirar um comentário ou exercer outros direitos, use o
canal de privacidade.
Identificadores e registros técnicos podem ser usados de forma limitada para
votação, prevenção de abuso, segurança, cumprimento de obrigação legal e
exercício de direitos.

Validação da área Acompanhar
Ao registrar interesse na área Acompanhar, o navegador cria um identificador
aleatório separado das outras atividades. O servidor guarda somente um hash
contextualizado e a data do registro. É um registro sem nome ou contato, mas
pseudônimo: o mesmo navegador consegue consultá-lo e retirá-lo enquanto
conservar o identificador. Ele é apagado na retirada, no encerramento da
validação ou em até 180 dias, o que ocorrer primeiro.

Compartilhamento do resultado
O compartilhamento é voluntário. Quando você escolhe um destino, a imagem ou o
texto selecionado é entregue ao aplicativo ou serviço indicado por você e fica
sujeito também às regras desse serviço.

Fornecedores e transferências
Usamos Google Cloud, Cloud Run e Cloud Logging para operar e proteger o site;
Neon/PostgreSQL para dados funcionais; Google/Firebase/GA4/BigQuery apenas para
métricas aceitas; NVIDIA NIM para moderar publicações; e ImprovMX e Google para
encaminhar e receber mensagens enviadas ao canal de privacidade. Esses
fornecedores podem processar dados em outros países com salvaguardas aplicáveis.

Retenção e segurança
Respostas do quiz não são persistidas na versão pública atual. Eventos e dados
de usuário aceitos têm retenção configurada por 2 meses no GA4; relatórios
agregados padrão podem seguir regras e prazos próprios. As tabelas novas do
BigQuery expiram em até 60 dias. Logs operacionais do Cloud Run roteados ao
bucket padrão do Cloud Logging são mantidos por 30 dias; registros de auditoria
obrigatórios seguem política própria e mais longa. Dados
funcionais permanecem somente enquanto necessários à função, segurança,
obrigação legal ou exercício de direitos. Mensagens de privacidade permanecem
durante o atendimento e, depois, somente enquanto necessárias para comprovar
cumprimento legal ou exercer direitos, com revisão ao menos anual e eliminação
quando essa necessidade terminar; a cópia entregue à caixa de e-mail é
distinta dos registros mínimos de entrega que o ImprovMX mantém por 7 dias.

Seus direitos
Você pode pedir confirmação e acesso, correção, anonimização, bloqueio ou
eliminação quando cabível, portabilidade nos termos da regulamentação,
informação sobre compartilhamentos, revogação do consentimento, revisão de
decisões automatizadas e oposição a tratamento irregular. Use {contactEmail}.
Também é possível peticionar à Autoridade Nacional de Proteção de Dados.
```

- [ ] **Step 2: Add state-control tests**

For `pending`, render equal accept/reject actions. For `granted`, render status
“Métricas aceitas” and a `REVOGAR MÉTRICAS` button. For a successfully saved
`denied`, render “Métricas rejeitadas” plus `ACEITAR MÉTRICAS`. When
`denialPersistenceFailed` is true, render this explicit status and an
additional retry action:

```text
Métricas rejeitadas nesta sessão, mas não foi possível salvar a rejeição para
a próxima visita.
TENTAR SALVAR REJEIÇÃO
```

The retry calls `deny()` again. Test a store that starts at `granted`, fails
the first denial write, and succeeds on retry: the first controller must stay
denied for the running session and show the warning; a freshly hydrated
controller would still read `granted`; after the retry, the warning disappears
and another fresh controller hydrates `denied`. Verify all other failures show
a message without navigating away.

Run at 320×568 and 1440×900 with text scale 2.0; scroll to the final rights section and assert no exception.

- [ ] **Step 3: Run the page test and verify it fails before implementation**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/privacy_page_test.dart
```

Expected: FAIL because the config and page are missing.

- [ ] **Step 4: Implement the configuration, page, and testable links**

Use `AppScaffold` and one `SingleChildScrollView` with narrow readable paragraphs on mobile and a page-owned maximum content width on desktop. Render the controller name and `privacidade@fpolitico.com.br` as public values. Inject the existing `LinkOpener` typedef from `mobile/lib/core/link/link_opener.dart`, defaulting to `openExternalLink`; never call `launchUrl` directly from this page. A false result or thrown error must show a `SnackBar` rather than escape.

Use this constructor contract consistently in the page, tests, and route:

```dart
const PrivacyPage({
  super.key,
  required this.consentController,
  required this.config,
  this.openLink,
});

final AnalyticsConsentController consentController;
final PrivacyConfig config;
final LinkOpener? openLink;
```

Pin these exact destinations in tests:

```dart
final emailUri = Uri(
  scheme: 'mailto',
  path: config.contactEmail,
);
final googlePartnerSitesUri = Uri.parse(
  'https://policies.google.com/technologies/partner-sites?hl=pt-BR',
);
```

Use these exact statements for the two most error-prone sections:

```text
Suas respostas do quiz podem revelar opinião política. Quando você pede o
cálculo, elas são enviadas à nossa API e processadas de forma transitória para
comparar suas escolhas com posições documentadas. Na versão pública, com o
recurso IoT desligado, não enviamos o UUID funcional local do navegador no
quiz e não armazenamos essas respostas.
```

```text
Ao registrar interesse na área Acompanhar, o navegador cria um identificador
aleatório separado das outras atividades. O servidor guarda somente um hash
contextualizado e a data do registro. É um registro sem nome ou contato, mas
pseudônimo: o mesmo navegador consegue consultá-lo e retirá-lo enquanto
conservar o identificador. Ele é apagado na retirada, no encerramento da
validação ou em até 180 dias, o que ocorrer primeiro.
```

- [ ] **Step 5: Preserve `const MyApp`, wire the route, and replace the drawer dialog**

Keep the constructor const and resolve the optional production dependency inside `build`:

```dart
class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.featureFlags = FeatureFlags.environment,
    this.analyticsConsent,
    this.privacyConfig = PrivacyConfig.environment,
    this.pageBuilders,
  });

  final FeatureFlags featureFlags;
  final AnalyticsConsentController? analyticsConsent;
  final PrivacyConfig privacyConfig;

  @visibleForTesting
  final List<Widget Function(VoidCallback onStartQuiz)>? pageBuilders;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final featureFlags = widget.featureFlags;
    final resolvedConsent = widget.analyticsConsent ??
        AnalyticsDependencies.instance.controller;
    // MaterialApp receives navigatorKey: _navigatorKey,
    // scaffoldMessengerKey: _scaffoldMessengerKey, and uses
    // resolvedConsent below.
  }
}
```

Owning both keys in `State` preserves a `const MyApp` constructor and isolates them for every test/app instance. The navigator key gives the global banner in Task 5 a valid way to navigate even though `MaterialApp.builder` is outside the nested `Navigator` subtree. The messenger key lets a failed rejection display feedback after the state change removes the banner from the tree.

Add:

```dart
'/privacidade': (_) => PrivacyPage(
  consentController: resolvedConsent,
  config: widget.privacyConfig,
),
```

In the `/` route, forward `pageBuilders: widget.pageBuilders` to `MainShell`.
This preserves `MainShell`'s existing test seam at the application-shell level
without changing production behavior. Keep using the local `featureFlags`
variable for the existing route conditions and constructor arguments; this
avoids a broad mechanical rewrite while moving the widget from stateless to
stateful.

Change `AppDrawer` privacy callback to close the drawer and call `navigator.pushNamed('/privacidade')`. Remove `_showPrivacy` and its stale short-ID/privacy body; keep the About dialog. Update tests to expect navigation to a fake route and no `AlertDialog`.

- [ ] **Step 6: Run route, drawer, and page tests**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/privacy_page_test.dart \
  test/app_drawer_test.dart \
  test/drawer_chrome_test.dart \
  test/widget_test.dart
```

Expected: PASS; the footer closes the drawer then opens a scrollable route, and the stale “salvar respostas do quiz” assertion is gone.

- [ ] **Step 7: Commit the privacy page**

```bash
git add mobile/lib/app.dart mobile/lib/features/privacy \
  mobile/lib/shared/widgets/app_drawer.dart \
  mobile/test/privacy_page_test.dart mobile/test/app_drawer_test.dart
git commit -m "feat: publish privacy notice and preferences"
```

### Task 5: Add the nonblocking responsive consent banner

**Files:**
- Create: `mobile/lib/features/privacy/analytics_consent_banner.dart`
- Create: `mobile/test/analytics_consent_banner_test.dart`
- Create: `mobile/test/analytics_consent_shell_composition_test.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/test/widget_test.dart`

**Interfaces:**
- Consumes: `AnalyticsConsentController`, `AnalyticsConsent.pending`, the state-owned root `navigatorKey`, and the `/privacidade` route implemented in Task 4.
- Produces: an accessible banner with `REJEITAR MÉTRICAS`, `ACEITAR MÉTRICAS`, and `SAIBA MAIS`, rendered only while pending.

- [ ] **Step 1: Write widget tests for behavior and layout**

For each surface size `Size(320, 568)`, `Size(390, 844)`, and `Size(1440, 900)`, run once at the default text scale and once by wrapping the complete `MyApp` shell in `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: ...)`. Do not use `withClampedTextScaling(maxScaleFactor: 2)`, which leaves an inherited 1.0 scaler unchanged. In the scaled cases first prove `MediaQuery.textScalerOf(element).scale(10) == 20`, then assert:

```dart
expect(find.text('REJEITAR MÉTRICAS'), findsOneWidget);
expect(find.text('ACEITAR MÉTRICAS'), findsOneWidget);
expect(find.text('SAIBA MAIS'), findsOneWidget);
expect(tester.takeException(), isNull);
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
```

For every layout case, call `final semantics = tester.ensureSemantics()` before
the accessibility matcher and dispose it in `finally`; otherwise the Flutter
3.41 guideline matcher fails because Semantics is disabled rather than because
of the banner UI.

Inspect the two decision buttons and assert they use the same widget class and equivalent minimum size/style. Add tests that:

- tapping accept calls `grant()` once;
- tapping reject calls `deny()` once;
- tapping `SAIBA MAIS` invokes the root-key callback and opens the real `/privacidade` page without changing state;
- pumping/removing/navigating without tapping leaves `pending`;
- a failed acceptance shows a `SnackBar`, keeps the banner pending, and its
  retry action calls `grant()`—never `deny()`;
- a failed rejection removes the banner because the in-memory gate is already
  denied, but the root `ScaffoldMessengerKey` still shows the persistence
  warning with a `TENTAR NOVAMENTE` action that calls `deny()` again;
- if either retry fails again, the same matching warning/action is shown again
  rather than discarding the second `false` result;
- granted and denied render no banner;
- there is no close/dismiss control;
- the real tappable “Começar o quiz” control in Home remains hit-testable while the banner is shown.

Create `analytics_consent_shell_composition_test.dart` with a reusable helper
that sets `tester.view.physicalSize = const Size(320, 568)`, device pixel ratio
1, a real pending `AnalyticsConsentController`, and `TextScaler.linear(2)`
around the complete `MyApp`. Before mounting, call
`SharedPreferences.setMockInitialValues(<String, Object>{})`. Pass
`pageBuilders` through `MyApp`: its first builder must return the real
`HomePage` with `NewsSession.testOnly(api: fakeNewsApi)` where the fake returns
a deterministic empty weekly-news payload, and the other three builders may
return controlled placeholder pages. This keeps the real “Começar o quiz”
interaction while proving that shell setup cannot touch the network. Register
tear-down for the view overrides, controller, and any closeable fake client.
After mounting, obtain the nested `NavigatorState` from
`find.byType(Navigator).first` and push a real target page with
`MaterialPageRoute`; never pump a page outside `MyApp.builder`. For every
target, assert the three banner actions remain present,
`tester.takeException()` is null, scroll/`ensureVisible` the page's primary
action, and require that action to be `hitTestable`. Start the file with the
Home action. Tasks 6 and 7 extend this same matrix to the four pages whose
notice/action layouts change.

- [ ] **Step 2: Run the banner test and verify the missing widget**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_consent_banner_test.dart \
  test/analytics_consent_shell_composition_test.dart
```

Expected: FAIL because `AnalyticsConsentBanner` does not exist.

- [ ] **Step 3: Implement the banner copy and equal actions**

Use this exact short explanation:

```text
Métricas opcionais
Usamos Google Analytics somente se você aceitar, para medir uso e desempenho.
Ele pode receber um identificador pseudônimo, a página, navegador/dispositivo
e eventos genéricos. Não enviamos suas respostas do quiz, candidatos, partidos
ou afinidade e não usamos publicidade.
```

Use a `Wrap` for actions. Render accept and reject with the same `OutlinedButton` style and minimum height 48; `SAIBA MAIS` is a `TextButton`. Add semantics labels that state “Aceitar métricas opcionais” and “Rejeitar métricas opcionais.” The banner receives separate `onGrantPersistenceFailure` and `onDenialPersistenceFailure` callbacks rather than looking up a transient local messenger; it calls the callback matching the decision whose `Future<bool>` returned false. Do not add a close icon.

- [ ] **Step 4: Integrate inside one safe responsive layout**

Keep the `const MyApp` dependency shape plus both root keys introduced in Task
4. Pass them to `MaterialApp.navigatorKey` and
`MaterialApp.scaffoldMessengerKey`. Add a private helper whose retry operation
matches the failed decision and which re-shows itself when retry also returns
false:

```dart
void _showConsentSaveError(Future<bool> Function() retry) {
  final messenger = _scaffoldMessengerKey.currentState!;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: const Text('Não foi possível salvar sua escolha.'),
      action: SnackBarAction(
        label: 'TENTAR NOVAMENTE',
        onPressed: () async {
          if (!await retry() && mounted) {
            _showConsentSaveError(retry);
          }
        },
      ),
    ));
}
```

Do not call `Navigator.of` from the banner's builder context: `MaterialApp.builder` wraps the navigator child, so that context has no navigator ancestor. Extract the existing desktop/mobile branch to a private method without changing its behavior. Make `ColoredBox > SafeArea > LayoutBuilder` the single outer layout for both content and banner, then place the responsive content and pending banner in a `ListenableBuilder` + `Column`:

```dart
return ColoredBox(
  color: AppTheme.background,
  child: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: resolvedConsent,
        builder: (context, _) => Column(
          children: [
            Expanded(child: _buildResponsiveContent(context, child)),
            if (resolvedConsent.state == AnalyticsConsent.pending)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * .55,
                ),
                child: AnalyticsConsentBanner(
                  controller: resolvedConsent,
                  onLearnMore: () => _navigatorKey.currentState!
                      .pushNamed('/privacidade'),
                  onGrantPersistenceFailure: () =>
                      _showConsentSaveError(resolvedConsent.grant),
                  onDenialPersistenceFailure: () =>
                      _showConsentSaveError(resolvedConsent.deny),
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);
```

Give the banner its own `SingleChildScrollView` so all text/actions remain reachable at 320×568 and 200% text scale. The banner may constrain only its own inner width; do not wrap the desktop app child in `kMaxContentWidth`.

- [ ] **Step 5: Run banner, app smoke, and desktop shell regressions**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/analytics_consent_banner_test.dart \
  test/analytics_consent_shell_composition_test.dart \
  test/widget_test.dart \
  test/main_shell_test.dart \
  test/navigation_shell_wiring_test.dart \
  test/iot_feature_flag_test.dart
```

Expected: PASS at mobile and desktop sizes, at 200% text scale, with no overflow and existing desktop navigation intact.

- [ ] **Step 6: Commit the banner**

```bash
git add mobile/lib/app.dart \
  mobile/lib/features/privacy/analytics_consent_banner.dart \
  mobile/test/analytics_consent_banner_test.dart \
  mobile/test/analytics_consent_shell_composition_test.dart \
  mobile/test/widget_test.dart
git commit -m "feat: add analytics consent banner"
```

### Task 6: Omit the quiz UUID when IoT is disabled

**Files:**
- Modify: `mobile/lib/shared/quiz_session.dart:9-86`
- Modify: `mobile/test/quiz_session_test.dart:92-126`
- Modify: `mobile/lib/features/quiz/quiz_intro_page.dart:55-81`
- Create: `mobile/test/quiz_intro_privacy_test.dart`
- Create: `mobile/lib/features/quiz/quiz_processing_notice.dart`
- Create: `mobile/test/quiz_processing_notice_test.dart`
- Modify: `mobile/lib/features/party_selection/party_selection_page.dart:192-219`
- Create: `mobile/test/party_selection_page_test.dart`
- Modify: `mobile/test/analytics_consent_shell_composition_test.dart`

**Interfaces:**
- Consumes: `FeatureFlags.environment.iotEnabled`, `DeviceIdentityStore.getOrCreateDeviceId()`, and `ApiClient.submitQuiz(..., deviceId:)`.
- Produces: `QuizSession.iotEnabled`, public omission of `deviceId`, and one reusable highlighted transient-processing notice shown at introduction and final submission.

- [ ] **Step 1: Replace the existing submit test with false/true IoT tests**

Enhance the fake store with a call counter and add:

```dart
test('submit with IoT disabled never reads or sends the device id', () async {
  final api = _FakeApiClient();
  final store = _FakeDeviceIdentityStore(
    '550e8400-e29b-41d4-a716-446655440000',
  );
  final session = QuizSession.testOnly(
    api: api,
    deviceIdentityStore: store,
    iotEnabled: false,
  )..theses = [
      Thesis(
        id: 1,
        title: 'Thesis 1',
        category: 'Economia',
        answer: ThesisAnswer.agree,
      ),
    ];

  await session.submit();

  expect(store.reads, 0);
  expect(api.receivedDeviceId, isNull);
  expect(session.results, hasLength(1));
});

test('submit with IoT enabled preserves the device contract', () async {
  const id = '550e8400-e29b-41d4-a716-446655440000';
  final api = _FakeApiClient();
  final store = _FakeDeviceIdentityStore(id);
  final session = QuizSession.testOnly(
    api: api,
    deviceIdentityStore: store,
    iotEnabled: true,
  )..theses = [
      Thesis(
        id: 1,
        title: 'Thesis 1',
        category: 'Economia',
        answer: ThesisAnswer.agree,
      ),
    ];

  await session.submit();

  expect(store.reads, 1);
  expect(api.receivedDeviceId, id);
});
```

- [ ] **Step 2: Run the false-IoT test and observe the current read/send**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/quiz_session_test.dart \
  --plain-name 'submit with IoT disabled never reads or sends the device id'
```

Expected: FAIL because `QuizSession` has no flag and always calls the store.

- [ ] **Step 3: Add the injected flag and conditional ID**

Use:

```dart
QuizSession._({
  ApiClient? api,
  DeviceIdentityStore? deviceIdentityStore,
  bool? iotEnabled,
}) : iotEnabled = iotEnabled ?? FeatureFlags.environment.iotEnabled,
     api = api ?? ApiClient(),
     deviceIdentityStore = deviceIdentityStore ?? DeviceIdentityStore();

final bool iotEnabled;

Future<void> submit() async {
  final deviceId = iotEnabled
      ? await deviceIdentityStore.getOrCreateDeviceId()
      : null;
  results = await api.submitQuiz(theses, deviceId: deviceId);
  notifyListeners();
}
```

Expose `iotEnabled` in `testOnly`. The singleton continues using the compile-time environment flag.

- [ ] **Step 4: Write failing tests for the highlighted quiz-processing notice**

In `quiz_processing_notice_test.dart`, specify `QuizProcessingNotice`, pump it
at 320×568 and 1440×900 with text scale 2.0, and assert it includes:

```text
Suas respostas podem revelar opinião política. Ao tocar em VER RESULTADOS,
você concorda com o envio à API e o processamento transitório para calcular a
comparação. Na versão pública, elas não são armazenadas. Isso independe da sua
escolha sobre métricas.
```

In `quiz_intro_privacy_test.dart` and `party_selection_page_test.dart`, specify
the same component once in `QuizIntroPage` before `COMEÇAR PERGUNTAS` and once
in `PartySelectionPage` immediately above `VER RESULTADOS`. Tests must prove
both placements, absence of a checkbox, and that rejecting analytics does not
disable either quiz action.

Pump each **complete page**, not only the notice, at 320×568 with
`TextScaler.linear(2)`. For `QuizIntroPage`, require `takeException() == null`,
scroll/`ensureVisible` as the real UI permits, and prove `COMEÇAR PERGUNTAS` is
reachable and hit-testable. Apply the same overflow/reachability proof to
`VER RESULTADOS` on `PartySelectionPage`. These compositions currently place
the actions near constrained regions, so isolated notice tests are
insufficient.

Extend `analytics_consent_shell_composition_test.dart` with two cases that use
its real pending-controller `MyApp` harness, push `QuizIntroPage` and
`PartySelectionPage`, and keep the banner pending throughout. Inject the same
fake analytics/session/API dependencies used by the focused page tests so no
network or Firebase work occurs. At 320×568 and 200% text, assert zero
exception, all banner actions remain reachable, and respectively
`COMEÇAR PERGUNTAS` and `VER RESULTADOS` can be scrolled into view and are
hit-testable without accepting or rejecting metrics. If either fails, make the
smallest page-owned notice/action region flexible or scrollable, or reduce the
banner's responsive allocation; never hide the banner, auto-select consent, or
test the page at the full viewport height as a substitute.

- [ ] **Step 5: Run the notice/page tests and observe RED**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/quiz_intro_privacy_test.dart \
  test/quiz_processing_notice_test.dart \
  test/party_selection_page_test.dart \
  test/analytics_consent_shell_composition_test.dart
```

Expected: FAIL because `QuizProcessingNotice` and both placements do not yet
exist; this proves the content, independence, and constrained-layout coverage
are RED before UI implementation.

- [ ] **Step 6: Implement the reusable notice and both responsive placements**

Create `QuizProcessingNotice` with the exact tested copy. Render it in the two
tested positions. If either complete page overflows or leaves its primary
action unreachable, move that notice/action region into the smallest suitable
scrollable or flexible layout while preserving existing navigation and action
behavior. Do not add a checkbox or couple either action to Analytics consent.

- [ ] **Step 7: Run quiz client tests**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/quiz_session_test.dart \
  test/api_client_submit_test.dart \
  test/quiz_intro_privacy_test.dart \
  test/quiz_processing_notice_test.dart \
  test/party_selection_page_test.dart \
  test/analytics_consent_shell_composition_test.dart
```

Expected: PASS; false IoT omits the ID without reading storage, true IoT
preserves it, HTTP body inclusion/omission remains correct, and both quiz pages
keep their actions reachable under the real pending banner at 320×568/200%.

- [ ] **Step 8: Commit quiz minimization**

```bash
git add mobile/lib/shared/quiz_session.dart \
  mobile/lib/features/quiz/quiz_intro_page.dart \
  mobile/lib/features/quiz/quiz_processing_notice.dart \
  mobile/lib/features/party_selection/party_selection_page.dart \
  mobile/test/quiz_session_test.dart mobile/test/quiz_intro_privacy_test.dart \
  mobile/test/quiz_processing_notice_test.dart \
  mobile/test/party_selection_page_test.dart \
  mobile/test/analytics_consent_shell_composition_test.dart
git commit -m "fix: omit public quiz device identity"
```

### Task 7: Correct pseudonymity and highlight sensitive community publication

**Files:**
- Modify: `mobile/lib/features/political_actors/politician_follow_validation_page.dart:271-289`
- Modify: `mobile/lib/shared/widgets/app_drawer.dart:256-307`
- Modify: `mobile/lib/features/community/create_post_page.dart:102-169`
- Modify: `mobile/lib/features/community/community_feed_page.dart:198-207`
- Modify: `mobile/lib/features/community/post_detail_page.dart`
- Create: `mobile/lib/features/community/community_processing_notice.dart`
- Modify: `mobile/test/politician_follow_validation_page_test.dart`
- Modify: `mobile/test/create_post_page_test.dart`
- Modify: `mobile/test/community_feed_chrome_test.dart`
- Create: `mobile/test/community_processing_notice_test.dart`
- Modify: `mobile/test/post_detail_removed_test.dart`
- Modify: `mobile/test/analytics_service_test.dart`
- Modify: `mobile/test/app_drawer_test.dart`
- Modify: `mobile/test/analytics_consent_shell_composition_test.dart`
- Modify: `mobile/.env.example`
- Modify: `README.md`
- Modify: `backend/README.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the separate `PoliticianFollowInterestIdentityStore`, consent-aware default sink, and `politician_follow_interests(subject_hash, created_at)` backend contract.
- Produces: accurate pseudonymous wording, highlighted specific notice before political community text is published, and proof that the features work when analytics is denied.

- [ ] **Step 1: Add denied-analytics functional tests**

Create a denied `AnalyticsConsentController`, pass it through a real
`ConsentAwareAnalyticsSink` and `AnalyticsService`, and set
`operationallyEnabled: true` on both the fake runtime and sink. Pump
`PoliticianFollowValidationPage` with that service and a fake API. Register and
withdraw interest. Assert API calls succeed, UI transitions occur, and
`runtime.events` remains empty. This setup proves denial—not the operational
kill switch—blocked analytics. Assert the identity UUID appears only in the API
fake's header argument and never in any captured analytics event or parameter.

- [ ] **Step 2: Add copy assertions before changing text**

Assert the registered state contains “registro sem nome ou contato” and does not contain “registro anônimo”. Assert About/privacy-facing copy does not call the validation anonymous. Assert the community composer says “Publicação sob alias pseudônimo” and explains its stable public alias, while the feed says “discussão sob aliases pseudônimos” rather than promising an anonymous community.

Create `CommunityProcessingNotice.post()` and
`CommunityProcessingNotice.comment()` so each surface names the action the
person can actually take. Pin the shared copy plus each exact final sentence in
tests:

```text
Seu texto pode revelar opinião política e ficará público sob um alias
pseudônimo estável. Ele será armazenado e enviado à NVIDIA NIM para moderação.
Não inclua dados pessoais que não queira publicar.

Post: Ao tocar em PUBLICAR, você concorda especificamente com esse uso.
Comentário: Ao tocar em ENVIAR COMENTÁRIO, você concorda especificamente com
esse uso.
```

Assert `CreatePostPage` no longer puts `PUBLICAR` in the AppBar: the final
enabled action is in a footer/action region immediately below
`CommunityProcessingNotice.post()`. Pin structural traversal/order so no field
or unrelated control sits between the notice and button; mere simultaneous
visibility is insufficient. The comment notice is immediately adjacent to
`_CommentInput` in `PostDetailPage`. Give the existing comment
`IconButton` both `tooltip: 'ENVIAR COMENTÁRIO'` and an equivalent semantics
label, and pin that discoverable action in the widget test. At 320×568 and text
scale 2.0, each complete page keeps the matching notice/action pair reachable,
ordered, and hit-testable without overflow.

Add two more cases to `analytics_consent_shell_composition_test.dart`. Inside
the same real pending-controller `MyApp` at 320×568/200%, push
`CreatePostPage` with a fake themes/create API and `PostDetailPage` with a fake
loaded-post API. Reinitialize
`SharedPreferences.setMockInitialValues(<String, Object>{})` before each of
these two cases (or in the helper immediately before mounting) so
`DeviceIdentityStore` never reaches a host plugin and the detail page reaches
its loaded state. Keep consent untouched and assert zero exception, all banner
actions remain present, then scroll the page-owned region until respectively
`PUBLICAR` and `ENVIAR COMENTÁRIO` are visible and hit-testable. The post case
must enter text before checking the enabled action. A layout fix may make the
smallest notice/action footer flexible or scrollable, but cannot move either
action above its notice or let the banner cover it permanently.

Assert the copy explains that removing one's post replaces its content with a
tombstone while preserving comments, and that comment-removal requests use the
privacy channel. Preserve `post_detail_removed_test.dart`'s existing assertion
that an earlier comment remains visible under a removed post.

- [ ] **Step 3: Run the focused tests and observe copy failures**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/politician_follow_validation_page_test.dart \
  test/app_drawer_test.dart \
  test/create_post_page_test.dart \
  test/community_feed_chrome_test.dart \
  test/community_processing_notice_test.dart \
  test/post_detail_removed_test.dart \
  test/analytics_consent_shell_composition_test.dart \
  test/analytics_service_test.dart
```

Expected: copy and pending-shell composition assertions FAIL before the wording
and layout change; functional behavior remains intact.

- [ ] **Step 4: Replace inaccurate product language**

Use:

```text
Obrigado. Esse registro sem nome ou contato, separado das outras atividades,
entra na nossa medição de demanda.
```

In About text, use “registro de interesse sem nome ou contato” rather than
“registro anônimo”. In the community, use “sob alias pseudônimo” and explain
that the local UUID acts as a possession credential and generates a stable
public alias. Move the current AppBar `PUBLICAR` behavior—including validation,
loading/disabled state, and submission—to a footer immediately after the
correctly parameterized `CommunityProcessingNotice.post()`. Place
`CommunityProcessingNotice.comment()` immediately before the matching comment
submission control; do not add a checkbox. In documentation, state that the
database hash is one-way, while the browser can reproduce it from its retained
UUID to consult or delete the row; do not call the hash reversible.

Document truthfully that posts/comments may reveal political opinion, are persisted and publicly displayed under a stable alias, and are moderated by NVIDIA NIM. A post author can remove the post content, which leaves a tombstone and preserves the discussion; comment-removal and other applicable rights requests use `privacidade@fpolitico.com.br`. Do not invent a fixed community retention period: state the functional retention criterion plus limited security/legal retention.

Document that GA funnel counts include only visitors who accepted optional metrics. The deduplicated active database row count remains the demand source of truth. Document withdrawal and the maximum 180-day operational retention.

- [ ] **Step 5: Run feature and sharing regressions**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/politician_follow_validation_page_test.dart \
  test/create_post_page_test.dart \
  test/community_feed_chrome_test.dart \
  test/community_processing_notice_test.dart \
  test/post_detail_removed_test.dart \
  test/analytics_consent_shell_composition_test.dart \
  test/analytics_service_test.dart \
  test/results_share_navigation_test.dart \
  test/result_share_page_test.dart
```

Expected: PASS; interest remains functional without analytics, and result sharing still has no new tracking.

- [ ] **Step 6: Scan public wording and commit**

```bash
rg -n -i "validação anônima|registro anônimo|comunidade anônima|discussão anônima|publicação anônima|anonimamente|anonymous demand-validation|anonymous community|register interest anonymously|reversível pelo próprio aparelho" \
  README.md backend/README.md CLAUDE.md mobile/.env.example \
  mobile/lib/features/community mobile/lib/features/political_actors \
  mobile/lib/shared/widgets/app_drawer.dart
```

Expected: no inaccurate matches.

```bash
git add README.md backend/README.md CLAUDE.md \
  mobile/.env.example \
  mobile/lib/features/political_actors/politician_follow_validation_page.dart \
  mobile/lib/features/community/create_post_page.dart \
  mobile/lib/features/community/community_feed_page.dart \
  mobile/lib/features/community/post_detail_page.dart \
  mobile/lib/features/community/community_processing_notice.dart \
  mobile/lib/shared/widgets/app_drawer.dart \
  mobile/test/politician_follow_validation_page_test.dart \
  mobile/test/create_post_page_test.dart \
  mobile/test/community_feed_chrome_test.dart \
  mobile/test/community_processing_notice_test.dart \
  mobile/test/post_detail_removed_test.dart \
  mobile/test/analytics_consent_shell_composition_test.dart \
  mobile/test/analytics_service_test.dart mobile/test/app_drawer_test.dart
git commit -m "docs: describe follow interest as pseudonymous"
```

### Task 8: Enforce public privacy configuration in CI and deployment

**Files:**
- Modify: `.github/workflows/deploy-web.yml:29-38`
- Modify: `.github/workflows/ci.yml:13-78`
- Modify: `firebase.json`
- Modify: `mobile/lib/features/privacy/privacy_config.dart`
- Modify: `mobile/.env.example`
- Modify: `README.md`
- Modify: `PUBLICACAO_2026.md`
- Modify: `CLAUDE.md`
- Create: `mobile/test/privacy_build_config_test.dart`

**Interfaces:**
- Consumes: `PrivacyConfig.environment` and GitHub repository variables.
- Produces: application-level diagnostics plus deploy-time failure for missing/example/brand-only public identity or invalid analytics kill-switch state, deterministic CI smoke values, self-hosted Flutter Web runtime resources, and mandatory revalidation for mutable Web shell/code files.

- [ ] **Step 1: Add configuration-unit tests**

Test an injectable validation helper on `PrivacyConfig`:

```dart
expect(
  const PrivacyConfig(
    controllerName: 'Pessoa Controladora',
    contactEmail: 'privacidade@fpolitico.com.br',
  ).validationErrors,
  isEmpty,
);
expect(
  const PrivacyConfig(controllerName: '', contactEmail: '').validationErrors,
  containsAll(['controllerName', 'contactEmail']),
);
expect(
  const PrivacyConfig(
    controllerName: 'Nome de Exemplo',
    contactEmail: 'privacy@example.com',
  ).validationErrors,
  containsAll(['controllerName', 'contactEmail']),
);
expect(
  const PrivacyConfig(
    controllerName: 'Farol Político',
    contactEmail: 'privacidade@fpolitico.com.br',
  ).validationErrors,
  contains('controllerName'),
);
expect(
  const PrivacyConfig(
    controllerName: 'Giovanni Testa',
    contactEmail: 'privacidade@fpolitico.com.br',
  ).validationErrors,
  isEmpty,
);
for (final invalidName in <String>[
  'Nome de Exemplo,',
  'Nome (Teste)',
  'Farol-Político',
]) {
  expect(
    PrivacyConfig(
      controllerName: invalidName,
      contactEmail: 'privacidade@fpolitico.com.br',
    ).validationErrors,
    contains('controllerName'),
  );
}
```

Also cover `Teste`, `test`, `TODO`, `TBD`, and `placeholder`
case-insensitively as complete normalized placeholder tokens. Normalize every
run of non-letter/non-number Unicode characters to a space with
`RegExp(r'[^\p{L}\p{N}]+', unicode: true)` before tokenizing; use the same
normalized tokens joined without spaces for the brand-only comparison. The
punctuation and hyphen cases above prove separators cannot bypass the gate,
while positive `Giovanni Testa` proves that substrings inside real names are
not rejected.
The helper is for diagnostics/tests; the release workflow remains the hard
build gate because Dart assertions are removed in release. A human must still
record that the supplied value is the real civil/legal identity; a denylist
cannot prove that fact.

- [ ] **Step 2: Observe RED, implement `validationErrors`, and rerun GREEN**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/privacy_build_config_test.dart
```

Expected before implementation: FAIL because `validationErrors` does not exist. Add an immutable getter that trims values, reports the field name once for empty or placeholder/test/example values, rejects the exact brand-only controller after case/whitespace normalization, and verifies the contact has a syntactically valid email shape. Do not embed a production controller identity. Rerun the same command and require PASS.

- [ ] **Step 3: Write failing workflow and Hosting contract tests**

In `privacy_build_config_test.dart`, read both workflow files from
`../.github/workflows/` and require every build command to contain all seven
critical fragments:

```text
flutter build web --release --no-web-resources-cdn
--dart-define=IOT_FEATURE_ENABLED=
--dart-define=POLITICIAN_FOLLOW_ENABLED=
--dart-define=PUBLIC_APP_URL=
--dart-define=ANALYTICS_ENABLED=
--dart-define=PRIVACY_CONTROLLER_NAME=
--dart-define=PRIVACY_CONTACT_EMAIL=
```

For the deploy workflow, additionally assert the four public environment
bindings use `vars.PUBLIC_APP_URL`, `vars.ANALYTICS_ENABLED`,
`vars.PRIVACY_CONTROLLER_NAME`, and `vars.PRIVACY_CONTACT_EMAIL`; the approved
contact literal is `privacidade@fpolitico.com.br`; the shell contains the exact
`true|false` gate, Unicode-locale punctuation normalization, token-bounded
placeholder loop, and no broad `*test*` or `*teste*` substring pattern; and
`name: Validate public privacy identity`
appears before `name: Build web release`. The configuration-unit case for
`Giovanni Testa` must remain green alongside this workflow contract. For CI,
assert the six explicit smoke values are
IoT false, follow false, analytics true, `https://example.invalid`,
`Responsável de Teste`, and `privacidade@example.invalid`.

Extract the actual indented `run: |` body of the validation step in the test
and execute that exact body through `Process.run('bash', ['-c', script],
environment: ...)`. Require exit 0 for `Giovanni Testa`; require a nonzero exit
for `Nome de Exemplo,`, `Nome (Teste)`, and `Farol-Político`, with the other
three environment variables set to their valid production-shaped values. This
tests the deployed shell rather than a Dart reimplementation of it.

Read `../firebase.json`, parse it with `dart:convert`, and assert that `/`,
`/index.html`, `/flutter_bootstrap.js`, `/flutter_service_worker.js`,
`/main.dart.js`, and `/version.json` each have exactly
`Cache-Control: no-cache, max-age=0, must-revalidate`.

Run:

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/privacy_build_config_test.dart
```

Expected: FAIL on the missing workflow flags/gate and Hosting headers, proving
that this test is RED for the production controls rather than only for
`PrivacyConfig`.

- [ ] **Step 4: Add a shell validation step before the deployment build**

Set job environment from public repository variables:

```yaml
env:
  PUBLIC_APP_URL: ${{ vars.PUBLIC_APP_URL || 'https://fpolitico.com.br' }}
  PRIVACY_CONTROLLER_NAME: ${{ vars.PRIVACY_CONTROLLER_NAME }}
  PRIVACY_CONTACT_EMAIL: ${{ vars.PRIVACY_CONTACT_EMAIL }}
  ANALYTICS_ENABLED: ${{ vars.ANALYTICS_ENABLED }}
```

Add a step before `Build web release`:

```yaml
- name: Validate public privacy identity
  shell: bash
  run: |
    set -euo pipefail
    export LC_ALL=C.UTF-8
    controller="${PRIVACY_CONTROLLER_NAME//[[:space:]]/}"
    contact="${PRIVACY_CONTACT_EMAIL//[[:space:]]/}"
    test -n "$controller" || { echo "PRIVACY_CONTROLLER_NAME is required"; exit 1; }
    test -n "$contact" || { echo "PRIVACY_CONTACT_EMAIL is required"; exit 1; }
    lowered_controller="${PRIVACY_CONTROLLER_NAME,,}"
    normalized_controller="$(
      sed -E 's/[^[:alnum:]]+/ /g' <<< "$lowered_controller"
    )"
    read -r -a controller_tokens <<< "$normalized_controller"
    for token in "${controller_tokens[@]}"; do
      case "$token" in
        exemplo|example|teste|test|todo|tbd|placeholder)
          echo "Privacy identity must use production values"
          exit 1
          ;;
      esac
    done
    compact_controller="${normalized_controller//[[:space:]]/}"
    test -n "$compact_controller" || {
      echo "PRIVACY_CONTROLLER_NAME must contain letters or numbers"
      exit 1
    }
    case "$compact_controller" in
      farolpolítico|farolpolitico)
        echo "PRIVACY_CONTROLLER_NAME must be the real civil/legal identity, not the brand alone"
        exit 1
        ;;
    esac
    test "$PRIVACY_CONTACT_EMAIL" = "privacidade@fpolitico.com.br" || {
      echo "PRIVACY_CONTACT_EMAIL must be the approved public mailbox"
      exit 1
    }
    case "$ANALYTICS_ENABLED" in
      true|false) ;;
      *) echo "ANALYTICS_ENABLED must be exactly true or false"; exit 1 ;;
    esac
```

Pass all six build definitions, quoting the four environment-derived values:

```yaml
run: >-
  flutter build web --release --no-web-resources-cdn
  --dart-define=IOT_FEATURE_ENABLED=false
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false
  --dart-define=PUBLIC_APP_URL="$PUBLIC_APP_URL"
  --dart-define=ANALYTICS_ENABLED="$ANALYTICS_ENABLED"
  --dart-define=PRIVACY_CONTROLLER_NAME="$PRIVACY_CONTROLLER_NAME"
  --dart-define=PRIVACY_CONTACT_EMAIL="$PRIVACY_CONTACT_EMAIL"
```

- [ ] **Step 5: Make CI exercise the release configuration and Hosting revalidation**

Add both `.github/workflows/deploy-web.yml` and root `firebase.json` to the
mobile path filter. The latter is mandatory because
`privacy_build_config_test.dart` reads `../firebase.json`; a headers-only PR
must run the mobile job. Pin both filter entries in that static test. Change
the smoke build to pass:

```yaml
run: >-
  flutter build web --release --no-web-resources-cdn
  --dart-define=IOT_FEATURE_ENABLED=false
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false
  --dart-define=ANALYTICS_ENABLED=true
  --dart-define=PUBLIC_APP_URL=https://example.invalid
  --dart-define=PRIVACY_CONTROLLER_NAME="Responsável de Teste"
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid
```

CI uses explicit test values and does not exercise the production shell gate; deployment uses only repository variables and rejects test/example values. Extend `privacy_build_config_test.dart` to read both workflow files and assert every `flutter build web` command contains `--no-web-resources-cdn`; this keeps CanvasKit/engine resources on the site's own origin rather than Flutter's CDN.

Add these exact Hosting header entries without changing the catch-all rewrite or
the cacheability of content-addressed assets:

```json
"headers": [
  {
    "source": "/",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  },
  {
    "source": "/index.html",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  },
  {
    "source": "/flutter_bootstrap.js",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  },
  {
    "source": "/flutter_service_worker.js",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  },
  {
    "source": "/main.dart.js",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  },
  {
    "source": "/version.json",
    "headers": [{"key": "Cache-Control", "value": "no-cache, max-age=0, must-revalidate"}]
  }
]
```

Keep both `/` and `/index.html`: Firebase Hosting applies a header rule to the
original request path before the SPA rewrite, and the normal hash-route entry
`https://fpolitico.com.br/#/privacidade` requests `/`, not `/index.html`.

Rerun `flutter test test/privacy_build_config_test.dart` and require PASS for
the complete configuration, workflow, ordering, build-flag, and Hosting-header
contract.

- [ ] **Step 6: Update configuration and release documentation**

Add all three public build values to `mobile/.env.example`; use `privacidade@fpolitico.com.br` for contact, explain that the controller value must be supplied as a real name without inventing it in the file, and document that `ANALYTICS_ENABLED=false` is the safe default/operational pause while `true` still requires user consent. Update every Web release-build example with explicit safe development values and `--no-web-resources-cdn`.

`PUBLICACAO_2026.md` must add these release gates:

- privacy controller repository variable is real and visible on `/#/privacidade`;
- the accountable-contact decision is recorded outside the repository: if the
  applicable small-agent dispensation is substantiated, controller plus public
  channel remain the published configuration; if an encarregado is formally
  appointed, stop this release until `PrivacyConfig`, copy, and tests are
  deliberately extended with the approved public identity/contact;
- `privacidade@fpolitico.com.br` successfully receives a test message before deployment;
- ImprovMX effective logging is read back as `Minimum` detail with 7-day retention without exposing the alias destination;
- replying without exposing the private destination requires authenticated outbound mail and is not claimed until configured;
- backend deploy/gate succeeds before the Web deploy;
- rollback may not target a backend revision from before the persistence gate.
- the analytics kill switch is explicitly `true` for normal collection and is changed only through the cutover/pause procedure.

Update the root README's user-facing introduction from “Aplicativo”/“app” to “site” where it describes the published product. Technical paths may retain the conventional Flutter term when needed.

- [ ] **Step 7: Run config, YAML, and build checks**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  test/privacy_build_config_test.dart
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED=true \
  --dart-define=PUBLIC_APP_URL=https://example.invalid \
  --dart-define='PRIVACY_CONTROLLER_NAME=Responsável de Teste' \
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid
```

From repository root, parse both workflows:

```bash
/tmp/codex-uv/bin/uv run --with pyyaml python - <<'PY'
from pathlib import Path
import yaml

for path in (Path('.github/workflows/ci.yml'), Path('.github/workflows/deploy-web.yml')):
    with path.open(encoding='utf-8') as handle:
        yaml.safe_load(handle)
    print(path)
PY
```

Expected: test/build exit 0 and both workflow files parse.

- [ ] **Step 8: Commit CI and docs**

```bash
git add .github/workflows/ci.yml .github/workflows/deploy-web.yml firebase.json \
  mobile/lib/features/privacy/privacy_config.dart mobile/.env.example \
  mobile/test/privacy_build_config_test.dart \
  README.md PUBLICACAO_2026.md CLAUDE.md
git commit -m "ci: require public privacy identity"
```

Do not create `PRIVACY_CONTROLLER_NAME` in GitHub until the user provides the real public identity. It is acceptable and intentional for production Web deployment to remain blocked meanwhile.

### Task 9: Run full verification and prepare browser validation

**Files:**
- Verify only: `mobile/`, `.github/workflows/`, repository documentation

**Interfaces:**
- Consumes: Tasks 1-8 and the backend persistence plan.
- Produces: local release evidence and an artifact ready for the production cutover plan; it does not claim live GA/BigQuery behavior.

- [ ] **Step 1: Format and inspect generated changes**

```bash
mapfile -d '' dart_files < <(
  git diff -z --name-only --diff-filter=ACMR origin/main...HEAD -- 'mobile/**/*.dart'
)
test "${#dart_files[@]}" -gt 0
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/dart format \
  "${dart_files[@]}"
git diff --check
```

Expected: every added or modified Dart file in the branch—including theme,
quiz notice, party-selection, and font-related tests—is formatted, and diff
check is clean.

- [ ] **Step 2: Run the complete Flutter gate**

```bash
cd mobile
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter pub get
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter analyze
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter test \
  --platform chrome test/analytics_default_pipeline_web_test.dart
/home/brunooliveira/.cache/farol-flutter-3.41.6/bin/flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED=true \
  --dart-define=PUBLIC_APP_URL=https://example.invalid \
  --dart-define='PRIVACY_CONTROLLER_NAME=Responsável de Teste' \
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@example.invalid
```

Expected: analyze has no issues; all VM and Chrome tests pass; release build succeeds.

- [ ] **Step 3: Scan the built and source tree for forbidden analytics paths/data**

```bash
set -euo pipefail
if rg -n "gtag\(['\"](?:js|config|event)" mobile/lib mobile/web; then
  printf 'Forbidden direct gtag command found\n' >&2
  exit 1
fi
mapfile -t firebase_init_matches < <(
  rg -n 'Firebase\.initializeApp' mobile/lib \
    --glob '*.dart' --glob '!firebase_options.dart' || true
)
test "${#firebase_init_matches[@]}" -eq 1
[[ "${firebase_init_matches[0]}" == \
  mobile/lib/core/analytics/firebase_analytics_runtime.dart:* ]]
mapfile -t sdk_event_matches < <(
  rg -n 'analytics\.logEvent\(' mobile/lib --glob '*.dart' || true
)
test "${#sdk_event_matches[@]}" -eq 1
[[ "${sdk_event_matches[0]}" == \
  mobile/lib/core/analytics/firebase_analytics_runtime.dart:* ]]
rg -n "thesis_id|stance|party_acronym|candidate_id|score_percent|anonymous_id|device_id" \
  mobile/lib/core/analytics || true
```

Expected: there is no `gtag('js')`, `gtag('config')`, or `gtag('event')`;
executable Firebase initialization and SDK event emission each appear exactly
once, in the lazy runtime. `firebase_options.dart` is excluded only from the
initialization search because its generated documentation comment contains a
non-executable example; the file is not excluded from any build or analyzer.
Any political method arguments in `AnalyticsService` are deliberately
discarded and no forbidden key enters the policy/runtime.

- [ ] **Step 4: Review the branch against the spec**

Confirm all of these from the diff and test names:

- pending/denied never initialize Firebase;
- the operational kill switch blocks initialization and keeps effective Google consent denied even when the saved choice is granted;
- grant initializes lazily once and emits once;
- revoke stops future events immediately;
- five `follow_waitlist_*` events are generic and consent-gated;
- banner and page work on mobile/desktop;
- quiz false-IoT does not read/send UUID;
- the theme has no runtime Google Fonts dependency and every Web release build uses `--no-web-resources-cdn`;
- community post/comment actions show the specific sensitive-content notice before submission;
- the public notice uses only the functional email and real injected controller;
- no code or docs include the private mailbox destination;
- no unrelated product analytics was added.

- [ ] **Step 5: Commit any formatter-only corrections and leave a clean tree**

If formatting changed tracked implementation files:

```bash
git add mobile/lib mobile/test
git commit -m "style: format privacy implementation"
```

Then run:

```bash
git status --short
git log --oneline origin/main..HEAD
```

Expected: empty status and a reviewable sequence of focused commits.

- [ ] **Step 6: Hand off to production verification without overclaiming**

State that network absence before consent, Firebase Installation storage, GA4 retention, BigQuery consent fields, mailbox delivery, and historical cleanup require the live steps in `docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md`.
