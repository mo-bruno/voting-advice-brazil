# Web Product Analytics Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar cobertura ampla e consentida do comportamento do site no GA4 atual, sem enviar nem persistir respostas, posições políticas, candidaturas, partidos, ranking, score ou afinidade.

**Architecture:** O site continuará com um único pipeline `call site → AnalyticsService → ConsentAwareAnalyticsSink → AnalyticsEventPolicy → FirebaseAnalyticsRuntime → GA4`. O contrato público usará enums fechados, o sink ordenará eventos sem bloquear a interface e uma revisão monotônica impedirá que eventos atravessem revogações; navegação, operações e engajamentos serão instrumentados nos limites de UI já existentes. A propriedade `535804267`, o measurement ID `G-0P9XLRYVWT` e o histórico serão preservados, com corte operacional por SHA e timestamp UTC após o merge.

**Tech Stack:** Flutter 3.41.6, Dart, Firebase Analytics/GA4, flutter_test, Chrome Web test, GitHub Actions, Google Analytics Admin API, BigQuery CLI e Firebase Hosting.

**Spec:** `docs/superpowers/specs/2026-09-30-web-product-analytics-coverage-design.md`

## Global Constraints

- Executar toda alteração no worktree `/home/brunooliveira/Repositorios/voting-advice-brazil/.worktrees/web-analytics-coverage`, branch `codex/web-analytics-coverage`, baseada em `origin/main@162e3577a6f3738b8f95e1d15a0b855cd0ccd262`.
- Preservar a propriedade GA4 `535804267`, o stream Web e `G-0P9XLRYVWT`; não criar propriedade, stream, link ou pipeline paralelo.
- Não implementar Analytics para Android, iOS ou IoT e não habilitar nenhuma coleta dessas plataformas.
- Não enviar nem persistir para análise tese, índice, resposta, stance, peso, prioridade, candidatura, partido, colocação, score, afinidade, UUID, `user_id`, URL, rota crua, referrer customizado, título ou texto livre.
- Não criar tabela, migration, endpoint ou agregado backend para respostas, posições ou primeiros lugares; o quiz permanece transitório.
- Manter `ANALYTICS_ENABLED=false` até o cutover pós-merge; nenhum evento deve ser reproduzido depois de consentimento tardio.
- Toda string customizada deve vir de enum fechado; todo número deve respeitar `duration_ms 0..86400000`, totais do quiz `0..60`, seleções `0..50` e `item_count 0..1000`.
- Eventos de produto nunca podem bloquear clique, navegação, renderização ou atualização de estado.
- Preservar o histórico de GA4/BigQuery sem excluir ou alterar expiração de tabelas legadas; o TTL de 60 dias vale somente para tabelas futuras.
- O build Web deve continuar usando `--no-web-resources-cdn` e fontes locais.
- O PR não ativa produção. Configuração externa segura pode ser preparada, mas o unpause e o timestamp de corte só acontecem após merge, no mesmo SHA verificado.

## Review Focus

- `grant A → evento aguardando → deny → grant B` deve descartar o evento de A; Task 2 inclui regressão com `Completer`.
- Respostas assíncronas ultrapassadas por retry/refresh devem gerar um único terminal `stale` e nunca sucesso posterior; Tasks 4, 5, 6 e 7 incluem concorrência controlada.
- Back do navegador, botão de voltar, replace e retorno ao shell não podem duplicar `screen_viewed` nem `quiz_abandoned`; Tasks 3 e 4 cobrem os dois caminhos.
- Falha de share nativo seguida de fallback de download não pode fabricar um segundo clique, nem incluir URL/ranking/candidato; Task 7 fixa essa semântica.
- Runtime de Analytics travado ou falhando não pode atrasar ações da pessoa; Tasks 2, 4 e 7 usam sinks bloqueados para provar avanço imediato.

---

## File and responsibility map

### Core analytics

- Create `mobile/lib/core/analytics/analytics_dimensions.dart` — enums fechados e serialização dos valores permitidos.
- Create `mobile/lib/core/analytics/analytics_failure_classifier.dart` — classificação genérica e sem payload de falhas de API/transporte.
- Modify `mobile/lib/core/analytics/analytics_service.dart` — métodos semânticos tipados e remoção de argumentos políticos.
- Modify `mobile/lib/core/analytics/analytics_event_policy.dart` — schema único dos 26 eventos, chaves, coerência e limites.
- Modify `mobile/lib/core/analytics/analytics_consent_controller.dart` — revisão pública monotônica.
- Modify `mobile/lib/core/analytics/consent_aware_analytics_sink.dart` — fila FIFO e gate por revisão.
- Create `mobile/test/helpers/analytics_test_support.dart` — sink gravador e helpers de asserção usados pelos testes novos.
- Modify `mobile/test/analytics_event_policy_test.dart`, `mobile/test/analytics_service_test.dart`, `mobile/test/analytics_consent_controller_test.dart`, `mobile/test/consent_aware_analytics_sink_test.dart` e `mobile/test/firebase_analytics_runtime_test.dart` — contratos e corridas do core.

### Navigation and product surfaces

- Create `mobile/lib/core/analytics/analytics_navigation.dart` — intenção de origem one-shot, mapeamento local de rota e observer.
- Modify `mobile/lib/app.dart` e `mobile/lib/core/shell/main_shell.dart` — composição do observer, aba inicial, troca real e retorno ao shell.
- Modify `mobile/lib/shared/widgets/app_drawer.dart` — marcar origem `drawer` antes da navegação.
- Create `mobile/test/analytics_navigation_test.dart`; modify `mobile/test/main_shell_test.dart`, `mobile/test/navigation_shell_wiring_test.dart`, `mobile/test/shell_drawer_test.dart` e `mobile/test/results_share_navigation_test.dart`.

### Quiz, content and community

- Modify `mobile/lib/features/quiz/quiz_controller.dart`, `quiz_page.dart`, `quiz_intro_page.dart` e `thesis_explanation_panel.dart` — carga, funil, evidências e abandono.
- Modify `mobile/lib/features/weighting/weighting_page.dart`, `mobile/lib/features/party_selection/party_selection_page.dart`, `mobile/lib/features/results/results_page.dart` e `mobile/lib/features/comparison/comparison_page.dart` — semântica terminal correta e nenhum identificador político.
- Modify `mobile/lib/features/home/news_session.dart`, `home_page.dart` e `widgets/news_card.dart` — carga de notícias, quiz entry e links externos por categoria.
- Modify `mobile/lib/features/community/community_feed_page.dart`, `post_detail_page.dart` e `create_post_page.dart` — operações terminais de leitura e escrita.
- Modify `mobile/lib/features/results/sharing/result_share_page.dart` e `result_share_controls.dart` — render e destinos de compartilhamento.
- Modify `mobile/lib/features/political_actors/politician_follow_validation_page.dart` — leitura e registro de interesse.

### Transparency and operations

- Modify `mobile/lib/features/privacy/privacy_page.dart` e `mobile/test/privacy_page_test.dart` — descrever cobertura genérica e diferença temporária de retenção histórica.
- Create `docs/operations/web-product-analytics-cutover-2026-09.md` — inventário, configuração, canário, corte, consulta e rollback.
- Modify `docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md` — banner de supersessão que impede executar a antiga criação/relink/exclusão.
- Preserve `.github/workflows/deploy-web.yml` unless a failing test proves a gap; o workflow já passa os defines e `--no-web-resources-cdn`.

---

### Task 1: Closed analytics contract and policy

**Files:**
- Create: `mobile/lib/core/analytics/analytics_dimensions.dart`
- Create: `mobile/lib/core/analytics/analytics_failure_classifier.dart`
- Create: `mobile/test/helpers/analytics_test_support.dart`
- Modify: `mobile/lib/core/analytics/analytics_service.dart`
- Modify: `mobile/lib/core/analytics/analytics_event_policy.dart`
- Test: `mobile/test/analytics_event_policy_test.dart`
- Test: `mobile/test/analytics_service_test.dart`
- Test: `mobile/test/analytics_failure_classifier_test.dart`

**Interfaces:**
- Consumes: `AnalyticsSink.logEvent({required String name, Map<String, Object>? parameters})`.
- Produces: `AnalyticsService.screenViewed`, `engagementAction`, `operationResult` e `quizAbandoned` com os enums abaixo; `classifyAnalyticsFailure(Object error, {bool moderationWrite = false})`; allowlist de 26 eventos.

- [ ] **Step 1: Add failing enum/service serialization tests**

Create the shared test sink first; every later test uses these exact helpers
instead of inventing a second fake:

```dart
final class RecordedAnalyticsCall {
  const RecordedAnalyticsCall(this.name, this.parameters);

  final String name;
  final Map<String, Object>? parameters;
}

final class RecordingAnalyticsSink implements AnalyticsSink {
  RecordingAnalyticsSink({this.block});

  final Future<void>? block;
  final List<RecordedAnalyticsCall> calls = [];

  List<String> get names => [
        for (final call in calls) call.name,
      ];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    calls.add(RecordedAnalyticsCall(
      name,
      parameters == null ? null : Map<String, Object>.of(parameters),
    ));
    return block ?? Future<void>.value();
  }
}

List<RecordedAnalyticsCall> named(
  List<RecordedAnalyticsCall> calls,
  String name,
) =>
    calls.where((call) => call.name == name).toList();

RecordedAnalyticsCall lastNamed(
  List<RecordedAnalyticsCall> calls,
  String name,
) =>
    named(calls, name).last;

RecordedAnalyticsCall lastOperation(List<RecordedAnalyticsCall> calls) =>
    lastNamed(calls, 'operation_result');

RecordedAnalyticsCall lastEngagement(List<RecordedAnalyticsCall> calls) =>
    lastNamed(calls, 'engagement_action');

List<String> operationOutcomes(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['outcome']! as String,
    ];

List<String> operationTriggers(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['trigger']! as String,
    ];

List<String> operationNames(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'operation_result'))
        call.parameters!['operation']! as String,
    ];

List<String> engagementTargets(List<RecordedAnalyticsCall> calls) => [
      for (final call in named(calls, 'engagement_action'))
        call.parameters!['target']! as String,
    ];
```

Then add tests that compile only after these exact public types exist:

```dart
test('new product events serialize only closed dimensions', () async {
  final sink = RecordingAnalyticsSink();
  final analytics = AnalyticsService(sink: sink);

  await analytics.screenViewed(
    screen: AnalyticsScreen.communityFeed,
    source: AnalyticsSource.tab,
  );
  await analytics.operationResult(
    operation: AnalyticsOperation.communityFeedLoad,
    outcome: AnalyticsOutcome.empty,
    trigger: AnalyticsTrigger.initial,
    durationMs: 12,
    itemCount: 0,
  );

  expect(sink.calls[0].parameters, {
    'screen': 'community_feed',
    'source': 'tab',
  });
  expect(sink.calls[1].parameters, {
    'operation': 'community_feed_load',
    'outcome': 'empty',
    'trigger': 'initial',
    'duration_ms': 12,
    'item_count': 0,
  });
});

test('legacy methods no longer require discarded political values', () async {
  final sink = RecordingAnalyticsSink();
  final analytics = AnalyticsService(sink: sink);
  await analytics.thesisViewed();
  await analytics.thesisAnswered(timeToAnswerMs: 8);
  await analytics.thesisSkipped();
  await analytics.weightAdded();
  await analytics.weightRemoved();
  await analytics.partyToggled();
  await analytics.resultsViewed();
  await analytics.comparisonCandidateAdded();
  expect(
    sink.calls.expand((call) => call.parameters?.keys ?? const <String>[]),
    isNot(contains(anyOf(
      'thesis_id',
      'stance',
      'party_acronym',
      'candidate_id',
      'position',
      'score',
    ))),
  );
});
```

- [ ] **Step 2: Add failing policy matrix and hostile-input tests**

Cover all 26 names: the 22 existing names except `candidate_positions_viewed`, plus `screen_viewed`, `engagement_action`, `operation_result` and `quiz_abandoned`. Pin required fields, optional stripping, exact enum values, numeric boundaries and coherence:

```dart
test('required invalid value drops the whole event', () {
  expect(
    AnalyticsEventPolicy.sanitize(
      name: 'screen_viewed',
      parameters: {'screen': 'candidate_13', 'source': 'tab'},
    ),
    isNull,
  );
});

test('operation failures require a generic failure type', () {
  expect(
    AnalyticsEventPolicy.sanitize(
      name: 'operation_result',
      parameters: {
        'operation': 'news_load',
        'outcome': 'failed',
        'trigger': 'initial',
      },
    ),
    isNull,
  );
  expect(
    AnalyticsEventPolicy.sanitize(
      name: 'operation_result',
      parameters: {
        'operation': 'news_load',
        'outcome': 'success',
        'trigger': 'initial',
        'failure_type': 'network',
      },
    )!.parameters,
    isNot(contains('failure_type')),
  );
});

test('hostile identifiers and free text never cross the policy', () {
  final event = AnalyticsEventPolicy.sanitize(
    name: 'engagement_action',
    parameters: {
      'action': 'outbound_open',
      'surface': 'news',
      'target': 'news_article',
      'outcome': 'success',
      'candidate_id': '13',
      'url': 'https://example.test/?email=a@example.test',
      'anonymous_id': '550e8400-e29b-41d4-a716-446655440000',
      'text': 'posição política',
    },
  );
  expect(event!.parameters, {
    'action': 'outbound_open',
    'surface': 'news',
    'target': 'news_article',
    'outcome': 'success',
  });
});
```

Also test `duration_ms` at `0` and `86400000`, rejecting `-1` and `86400001`; quiz counts at `0` and `60`; `count_selected` at `50`; `item_count` at `1000`.

- [ ] **Step 3: Add failing failure-classifier tests**

```dart
test('classifies only generic failure families', () {
  expect(classifyAnalyticsFailure(TimeoutException('x')),
      AnalyticsFailureType.timeout);
  expect(
    classifyAnalyticsFailure(
      const ApiException('x', statusCode: 422),
      moderationWrite: true,
    ),
    AnalyticsFailureType.moderationRejected,
  );
  expect(
    classifyAnalyticsFailure(const ApiException('x', statusCode: 429)),
    AnalyticsFailureType.rateLimited,
  );
  expect(
    classifyAnalyticsFailure(const ApiException('x', statusCode: 503)),
    AnalyticsFailureType.unavailable,
  );
  expect(
    classifyAnalyticsFailure(http.ClientException('x')),
    AnalyticsFailureType.network,
  );
});
```

- [ ] **Step 4: Run the focused tests and verify red**

Run:

```bash
cd mobile
flutter test test/analytics_event_policy_test.dart \
  test/analytics_service_test.dart \
  test/analytics_failure_classifier_test.dart
```

Expected: FAIL because the enums, new methods and classifier do not exist and `candidate_positions_viewed` is still accepted.

- [ ] **Step 5: Implement the closed enums**

Create enhanced enums with these exact wire values:

```dart
enum AnalyticsScreen {
  home('home'),
  followValidation('follow_validation'),
  quizIntro('quiz_intro'),
  quizQuestions('quiz_questions'),
  weighting('weighting'),
  candidateSelection('candidate_selection'),
  results('results'),
  comparison('comparison'),
  communityFeed('community_feed'),
  communityPost('community_post'),
  communityCreate('community_create'),
  resultShare('result_share'),
  privacy('privacy');

  const AnalyticsScreen(this.value);
  final String value;
}

enum AnalyticsSource {
  initial('initial'),
  tab('tab'),
  homeCta('home_cta'),
  drawer('drawer'),
  deepLink('deep_link'),
  route('route'),
  back('back');

  const AnalyticsSource(this.value);
  final String value;
}

enum AnalyticsAction {
  quizEntry('quiz_entry'),
  evidenceOpen('evidence_open'),
  outboundOpen('outbound_open'),
  share('share');

  const AnalyticsAction(this.value);
  final String value;
}

enum AnalyticsSurface {
  home('home'),
  quiz('quiz'),
  comparison('comparison'),
  news('news'),
  results('results'),
  privacy('privacy');

  const AnalyticsSurface(this.value);
  final String value;
}

enum AnalyticsTarget {
  quizGuide('quiz_guide'),
  quizSource('quiz_source'),
  comparisonSource('comparison_source'),
  newsArticle('news_article'),
  newsIndex('news_index'),
  privacyEmail('privacy_email'),
  googlePrivacy('google_privacy'),
  nativeShare('native_share'),
  download('download'),
  copyLink('copy_link'),
  twitter('twitter'),
  whatsapp('whatsapp'),
  instagramHelp('instagram_help');

  const AnalyticsTarget(this.value);
  final String value;
}

enum AnalyticsOperation {
  newsLoad('news_load'),
  quizLoad('quiz_load'),
  candidateLoad('candidate_load'),
  resultsSubmit('results_submit'),
  comparisonLoad('comparison_load'),
  followStatusLoad('follow_status_load'),
  followRegister('follow_register'),
  communityFeedLoad('community_feed_load'),
  communityPostLoad('community_post_load'),
  communityPostCreate('community_post_create'),
  communityCommentCreate('community_comment_create'),
  communityVote('community_vote'),
  communityReport('community_report'),
  shareRender('share_render');

  const AnalyticsOperation(this.value);
  final String value;
}

enum AnalyticsOutcome {
  success('success'),
  empty('empty'),
  failed('failed'),
  stale('stale'),
  blocked('blocked');

  const AnalyticsOutcome(this.value);
  final String value;
}

enum AnalyticsTrigger {
  initial('initial'),
  retry('retry'),
  refresh('refresh'),
  pagination('pagination'),
  submit('submit');

  const AnalyticsTrigger(this.value);
  final String value;
}

enum AnalyticsFailureType {
  network('network'),
  timeout('timeout'),
  client('client'),
  server('server'),
  rateLimited('rate_limited'),
  moderationRejected('moderation_rejected'),
  unavailable('unavailable'),
  unknown('unknown');

  const AnalyticsFailureType(this.value);
  final String value;
}

enum AnalyticsQuizStage {
  questions('questions'),
  weighting('weighting'),
  candidateSelection('candidate_selection');

  const AnalyticsQuizStage(this.value);
  final String value;
}

enum AnalyticsAbandonReason {
  back('back'),
  restart('restart'),
  recovery('recovery');

  const AnalyticsAbandonReason(this.value);
  final String value;
}
```

- [ ] **Step 6: Implement typed service methods and remove political arguments**

Use these exact signatures:

```dart
Future<void> screenViewed({
  required AnalyticsScreen screen,
  required AnalyticsSource source,
});

Future<void> engagementAction({
  required AnalyticsAction action,
  AnalyticsSurface? surface,
  AnalyticsSource? source,
  AnalyticsTarget? target,
  AnalyticsOutcome? outcome,
});

Future<void> operationResult({
  required AnalyticsOperation operation,
  required AnalyticsOutcome outcome,
  required AnalyticsTrigger trigger,
  AnalyticsFailureType? failureType,
  int? durationMs,
  int? itemCount,
});

Future<void> quizAbandoned({
  required AnalyticsQuizStage stage,
  required AnalyticsAbandonReason reason,
  required int totalAnswered,
  required int totalSkipped,
  required int durationMs,
});
```

For existing methods, use `thesisViewed()`, `thesisAnswered({required int timeToAnswerMs})`, `thesisSkipped()`, `weightAdded()`, `weightRemoved()`, `partyToggled()`, `resultsViewed()` and `comparisonCandidateAdded()`. Delete `candidatePositionsViewed`. Build parameter maps with collection-if so nulls never become values.

- [ ] **Step 7: Implement strict schema validation**

Represent each event with required and optional `_ParameterRule` maps. The exact catalog is:

| Event | Required | Optional |
|---|---|---|
| `quiz_intro_viewed`, `quiz_started`, `quiz_restarted`, `thesis_viewed`, `thesis_skipped`, `weighting_started`, `weight_added`, `weight_removed`, `party_selection_viewed`, `party_toggled`, `results_viewed`, `comparison_opened`, `comparison_candidate_added`, five `follow_waitlist_*` events | none | none |
| `thesis_answered` | `time_to_answer_ms` duration | none |
| `quiz_completed` | `total_answered`, `total_skipped`, `duration_ms` | none |
| `weighting_completed` | `count_weighted` quiz count | none |
| `party_selection_completed` | `count_selected` selection count | none |
| `screen_viewed` | `screen`, `source` | none |
| `engagement_action` | `action` | `surface`, `source`, `target`, `outcome` |
| `operation_result` | `operation`, `outcome`, `trigger` | `failure_type`, `duration_ms`, `item_count` |
| `quiz_abandoned` | `stage`, `reason`, `total_answered`, `total_skipped`, `duration_ms` | none |

Use a sealed rule implementation:

```dart
sealed class _ParameterRule {
  const _ParameterRule();
  Object? sanitize(Object? value);
}

final class _EnumRule extends _ParameterRule {
  const _EnumRule(this.values);
  final Set<String> values;

  @override
  Object? sanitize(Object? value) =>
      value is String && values.contains(value) ? value : null;
}

final class _IntRule extends _ParameterRule {
  const _IntRule(this.max);
  final int max;

  @override
  Object? sanitize(Object? value) =>
      value is int && value >= 0 && value <= max ? value : null;
}
```

After field validation, enforce:

- `engagement_action/quiz_entry` requires `surface` and `source` and removes `target`/`outcome`;
- `evidence_open` requires `surface` and removes `source`/`outcome`;
- `outbound_open` requires `surface`, `target` and `outcome ∈ {success, failed}`;
- `share` requires `surface=results` and `target`; `outcome` is optional for `instagram_help` and otherwise must be `success` or `failed`;
- `operation_result` requires `failure_type` for `failed`/`blocked` and removes it for `success`/`empty`/`stale`.

Unknown keys are never copied. Missing/invalid required or conditionally required values return null.

- [ ] **Step 8: Implement the generic failure classifier**

```dart
AnalyticsFailureType classifyAnalyticsFailure(
  Object error, {
  bool moderationWrite = false,
}) {
  if (error is TimeoutException) return AnalyticsFailureType.timeout;
  if (error is http.ClientException) return AnalyticsFailureType.network;
  if (error is ApiException) {
    final status = error.statusCode;
    if (status == 408) return AnalyticsFailureType.timeout;
    if (status == 422 && moderationWrite) {
      return AnalyticsFailureType.moderationRejected;
    }
    if (status == 429) return AnalyticsFailureType.rateLimited;
    if (status == 503) return AnalyticsFailureType.unavailable;
    if (status != null && status >= 500) return AnalyticsFailureType.server;
    if (status != null && status >= 400) return AnalyticsFailureType.client;
  }
  return AnalyticsFailureType.unknown;
}
```

- [ ] **Step 9: Run tests and static analysis**

Run:

```bash
cd mobile
dart format lib/core/analytics test/helpers test/analytics_event_policy_test.dart \
  test/analytics_service_test.dart test/analytics_failure_classifier_test.dart
flutter test test/analytics_event_policy_test.dart \
  test/analytics_service_test.dart \
  test/analytics_failure_classifier_test.dart
flutter analyze
```

Expected: all focused tests PASS; analyze may still identify old call-site signatures, which are intentionally fixed in Tasks 4–8 but must not introduce errors in committed code. Update all call sites mechanically to the new no-political signatures before committing; do not add new tracking yet.

- [ ] **Step 10: Commit**

```bash
git add mobile/lib/core/analytics mobile/test/helpers \
  mobile/test/analytics_event_policy_test.dart \
  mobile/test/analytics_service_test.dart \
  mobile/test/analytics_failure_classifier_test.dart \
  mobile/lib/features
git commit -m "feat: define privacy-safe analytics contract"
```

---

### Task 2: Consent-generation-safe ordered delivery

**Files:**
- Modify: `mobile/lib/core/analytics/analytics_consent_controller.dart`
- Modify: `mobile/lib/core/analytics/consent_aware_analytics_sink.dart`
- Test: `mobile/test/analytics_consent_controller_test.dart`
- Test: `mobile/test/consent_aware_analytics_sink_test.dart`
- Test: `mobile/test/firebase_analytics_runtime_test.dart`
- Test: `mobile/test/analytics_default_pipeline_web_test.dart`

**Interfaces:**
- Consumes: `AnalyticsEventPolicy.sanitize` and `AnalyticsRuntime.initializeForGrantedConsent/logEvent`.
- Produces: `AnalyticsConsentController.revision` and a FIFO sink that drops stale-consent work while isolating failures.

- [ ] **Step 1: Add failing controller revision tests**

```dart
test('revision is monotonic across hydrate grant and deny intents', () async {
  final controller = controllerWithStoredValue('granted');
  final beforeHydrate = controller.revision;
  await controller.hydrate();
  final afterHydrate = controller.revision;
  await controller.deny();
  final afterDeny = controller.revision;
  await controller.grant();
  expect(beforeHydrate, lessThan(afterHydrate));
  expect(afterHydrate, lessThan(afterDeny));
  expect(afterDeny, lessThan(controller.revision));
});
```

- [ ] **Step 2: Add failing queue and generation-race tests**

Use a runtime whose first initialization is held by a `Completer<void>`:

```dart
test('grant A event cannot cross deny and grant B', () async {
  final init = Completer<void>();
  final runtime = BlockingAnalyticsRuntime(init.future);
  final controller = grantedController(runtime);
  final sink = ConsentAwareAnalyticsSink(
    controller: controller,
    runtime: runtime,
    operationallyEnabled: true,
  );

  final fromGrantA = sink.logEvent(name: 'quiz_started');
  await runtime.initializationStarted.future;
  await controller.deny();
  await controller.grant();
  init.complete();
  await fromGrantA;
  await sink.logEvent(name: 'quiz_restarted');

  expect(runtime.logged.map((event) => event.name), ['quiz_restarted']);
});

test('one failed event does not poison the FIFO tail', () async {
  final runtime = RuntimeFailingFirstLog();
  final sink = enabledSink(runtime);
  await Future.wait([
    sink.logEvent(name: 'quiz_started'),
    sink.logEvent(name: 'quiz_completed', parameters: {
      'total_answered': 10,
      'total_skipped': 2,
      'duration_ms': 20,
    }),
  ]);
  expect(runtime.attemptedNames, ['quiz_started', 'quiz_completed']);
  expect(runtime.loggedNames, ['quiz_completed']);
});
```

Also assert FIFO order for three calls and that events queued before `deny` are all dropped after a later regrant.

- [ ] **Step 3: Run focused tests and verify red**

Run:

```bash
cd mobile
flutter test test/analytics_consent_controller_test.dart \
  test/consent_aware_analytics_sink_test.dart \
  test/firebase_analytics_runtime_test.dart
```

Expected: FAIL because `revision` is private/not advanced by hydrate and the sink executes calls independently.

- [ ] **Step 4: Expose and advance the consent revision**

Add `int get revision => _revision;`. Increment once at the beginning of `hydrate`, `grant` and `deny`; keep the local revision check around async persistence/effects. `deny` must still change visible state before awaiting storage or runtime effects.

- [ ] **Step 5: Implement the sink FIFO with revision capture**

Remove the `const` constructor and add a failure-isolated tail:

```dart
Future<void> _tail = Future<void>.value();

bool _canSend(int revision) =>
    operationallyEnabled &&
    controller.isGranted &&
    controller.revision == revision;

@override
Future<void> logEvent({
  required String name,
  Map<String, Object>? parameters,
}) {
  if (!operationallyEnabled || !controller.isGranted) {
    return Future<void>.value();
  }
  final event = AnalyticsEventPolicy.sanitize(
    name: name,
    parameters: parameters,
  );
  if (event == null) return Future<void>.value();
  final revision = controller.revision;
  final task = _tail.then((_) => _deliver(event, revision));
  _tail = task.then<void>((_) {}, onError: (_) {});
  return task;
}

Future<void> _deliver(
  SanitizedAnalyticsEvent event,
  int revision,
) async {
  if (!_canSend(revision)) return;
  try {
    await runtime.initializeForGrantedConsent();
    if (!_canSend(revision)) return;
    await runtime.logEvent(event);
  } catch (_) {
    onError?.call(StateError('analytics event failed'));
  }
}
```

Do not call `runtime.updateConsent(false)` from a stale event: `deny` owns that effect, and an event from generation A must not turn collection off after grant B.

- [ ] **Step 6: Extend the browser pipeline regression**

In `analytics_default_pipeline_web_test.dart`, hold initialization across deny/regrant and prove only the post-regrant call reaches `FirebaseAnalyticsPlatform.logEvent`. Keep the existing assertions that Firebase has no app before consent and that there is no second gtag event pipeline.

- [ ] **Step 7: Run all core consent tests**

Run:

```bash
cd mobile
dart format lib/core/analytics/analytics_consent_controller.dart \
  lib/core/analytics/consent_aware_analytics_sink.dart \
  test/analytics_consent_controller_test.dart \
  test/consent_aware_analytics_sink_test.dart \
  test/firebase_analytics_runtime_test.dart \
  test/analytics_default_pipeline_web_test.dart
flutter test test/analytics_consent_controller_test.dart \
  test/consent_aware_analytics_sink_test.dart \
  test/firebase_analytics_runtime_test.dart
flutter test --platform chrome test/analytics_default_pipeline_web_test.dart
```

Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/core/analytics/analytics_consent_controller.dart \
  mobile/lib/core/analytics/consent_aware_analytics_sink.dart \
  mobile/test/analytics_consent_controller_test.dart \
  mobile/test/consent_aware_analytics_sink_test.dart \
  mobile/test/firebase_analytics_runtime_test.dart \
  mobile/test/analytics_default_pipeline_web_test.dart
git commit -m "fix: bind analytics events to consent generation"
```

---

### Task 3: Screen and quiz-entry navigation coverage

**Files:**
- Create: `mobile/lib/core/analytics/analytics_navigation.dart`
- Modify: `mobile/lib/app.dart`
- Modify: `mobile/lib/core/shell/main_shell.dart`
- Modify: `mobile/lib/shared/widgets/app_drawer.dart`
- Modify: `mobile/lib/features/community/community_feed_page.dart`
- Modify: `mobile/lib/features/results/results_page.dart`
- Test: `mobile/test/analytics_navigation_test.dart`
- Test: `mobile/test/main_shell_test.dart`
- Test: `mobile/test/navigation_shell_wiring_test.dart`
- Test: `mobile/test/shell_drawer_test.dart`
- Test: `mobile/test/results_share_navigation_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService.screenViewed` and `engagementAction` from Task 1.
- Produces: `AnalyticsNavigationIntent.mark/consumeOr`, `AnalyticsNavigationObserver`, canonical route constants and exact one-shot screen attribution.

- [ ] **Step 1: Add failing one-shot intent and route mapping tests**

```dart
test('navigation intent is consumed exactly once', () {
  final intent = AnalyticsNavigationIntent();
  intent.mark(AnalyticsSource.drawer);
  expect(intent.consumeOr(AnalyticsSource.route), AnalyticsSource.drawer);
  expect(intent.consumeOr(AnalyticsSource.route), AnalyticsSource.route);
});

testWidgets('push replace and pop emit canonical screens without route text',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  final observer = AnalyticsNavigationObserver(
    analytics: AnalyticsService(sink: sink),
    intent: AnalyticsNavigationIntent(),
  );
  await pumpNamedNavigationHarness(tester, observer);
  await pushRoute(tester, '/quiz');
  await replaceRoute(tester, '/weighting');
  await popRoute(tester);
  expect(screenPairs(sink.calls), [
    ('quiz_questions', 'route'),
    ('weighting', 'route'),
    ('quiz_questions', 'back'),
  ]);
  expect(
    sink.calls.expand((event) => event.parameters?.keys ?? const <String>[]),
    isNot(contains('route')),
  );
});
```

- [ ] **Step 2: Add failing shell tests**

```dart
testWidgets('initial tab and real tab changes emit once', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpShell(tester, sink: sink, initialTab: MainShellTab.inicio);
  expect(screenPairs(sink.calls), [('home', 'initial')]);

  await tester.tap(find.text('Comunidade'));
  await tester.pump();
  await tester.tap(find.text('Comunidade'));
  await tester.pump();

  expect(screenPairs(sink.calls), [
    ('home', 'initial'),
    ('community_feed', 'tab'),
  ]);
});

testWidgets('home CTA and deep link identify quiz entry source', (tester) async {
  final homeSink = RecordingAnalyticsSink();
  await pumpShell(tester, sink: homeSink);
  await tester.tap(find.textContaining('FAZER O QUIZ'));
  await tester.pump();
  expect(lastQuizEntry(homeSink.calls)['source'], 'home_cta');

  final deepSink = RecordingAnalyticsSink();
  await pumpAppAtUri(tester, Uri.parse('https://fpolitico.com.br/?tab=quiz'),
      sink: deepSink);
  expect(lastQuizEntry(deepSink.calls)['source'], 'deep_link');
});
```

Add a drawer test asserting `source=drawer` and a `didPopNext` test asserting the current shell tab reappears once with `source=back`.

- [ ] **Step 3: Run navigation tests and verify red**

Run:

```bash
cd mobile
flutter test test/analytics_navigation_test.dart \
  test/main_shell_test.dart \
  test/navigation_shell_wiring_test.dart \
  test/shell_drawer_test.dart \
  test/results_share_navigation_test.dart
```

Expected: FAIL because no observer, intent, canonical anonymous-route names or tab events exist.

- [ ] **Step 4: Implement navigation primitives**

Use these constants and signatures:

```dart
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

class AnalyticsNavigationObserver extends RouteObserver<ModalRoute<void>> {
  AnalyticsNavigationObserver({
    required AnalyticsService analytics,
    required AnalyticsNavigationIntent intent,
  });

  static const screens = <String, AnalyticsScreen>{
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
}
```

`didPush` and `didReplace` resolve only `RouteSettings.name` through `screens` and consume `route` fallback. `didPop` resolves the previous named route with `back`. Never forward `settings.name` as a parameter. Exclude `/` because `MainShell` owns its visible tab.

- [ ] **Step 5: Compose one observer and one analytics service in MyApp**

Add optional test injection `AnalyticsService? analytics`. In `_MyAppState.initState` construct one service, one `AnalyticsNavigationIntent` and one `AnalyticsNavigationObserver`; pass the observer to `MaterialApp.navigatorObservers` and pass the same service/intent/observer into `MainShell` and route page constructors.

- [ ] **Step 6: Track shell visibility and entry origins**

Make `_MainShellState` implement `RouteAware`:

- after first frame emit its actual initial tab using `initial`, or consume `deep_link`/`drawer`;
- `_select(index, source: AnalyticsSource.tab)` returns without emitting when `index == _index`;
- `_openQuiz` uses `homeCta` and emits one `engagement_action(action=quiz_entry, surface=home, source=home_cta)`;
- selecting the quiz tab emits the same action with `source=tab`;
- initial deep link to quiz emits it with `source=deep_link`;
- `didPopNext` emits the current tab with `source=back`;
- subscribe/unsubscribe from the passed route observer in `didChangeDependencies/dispose`.

Map tabs exactly: `inicio→home`, `acompanhar→follow_validation`, `quiz→quiz_intro`, `comunidade→community_feed`.

- [ ] **Step 7: Name anonymous routes and mark drawer intent**

Before drawer navigation, call `intent.mark(AnalyticsSource.drawer)`; for its quiz destination emit `quiz_entry` with `surface=home` and `source=drawer`. Add:

```dart
RouteSettings(name: communityPostRoute)
RouteSettings(name: communityCreateRoute)
RouteSettings(name: resultShareRoute)
```

to the corresponding `MaterialPageRoute` constructors in community feed and results.

- [ ] **Step 8: Run navigation tests and analyze**

Run:

```bash
cd mobile
dart format lib/core/analytics/analytics_navigation.dart lib/app.dart \
  lib/core/shell/main_shell.dart lib/shared/widgets/app_drawer.dart \
  lib/features/community/community_feed_page.dart \
  lib/features/results/results_page.dart \
  test/analytics_navigation_test.dart test/main_shell_test.dart \
  test/navigation_shell_wiring_test.dart test/shell_drawer_test.dart \
  test/results_share_navigation_test.dart
flutter test test/analytics_navigation_test.dart \
  test/main_shell_test.dart \
  test/navigation_shell_wiring_test.dart \
  test/shell_drawer_test.dart \
  test/results_share_navigation_test.dart
flutter analyze
```

Expected: PASS, with no duplicate event on active-tab taps or back.

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/core/analytics/analytics_navigation.dart mobile/lib/app.dart \
  mobile/lib/core/shell/main_shell.dart \
  mobile/lib/shared/widgets/app_drawer.dart \
  mobile/lib/features/community/community_feed_page.dart \
  mobile/lib/features/results/results_page.dart \
  mobile/test/analytics_navigation_test.dart mobile/test/main_shell_test.dart \
  mobile/test/navigation_shell_wiring_test.dart mobile/test/shell_drawer_test.dart \
  mobile/test/results_share_navigation_test.dart
git commit -m "feat: track consented web navigation"
```

---

### Task 4: Correct quiz funnel, operations, evidence and abandonment

**Files:**
- Modify: `mobile/lib/features/quiz/quiz_controller.dart`
- Modify: `mobile/lib/features/quiz/quiz_page.dart`
- Modify: `mobile/lib/features/quiz/quiz_intro_page.dart`
- Modify: `mobile/lib/features/quiz/thesis_explanation_panel.dart`
- Modify: `mobile/lib/features/weighting/weighting_page.dart`
- Modify: `mobile/lib/features/party_selection/party_selection_page.dart`
- Modify: `mobile/lib/features/results/results_page.dart`
- Modify: `mobile/lib/features/comparison/comparison_page.dart`
- Test: `mobile/test/quiz_controller_analytics_test.dart`
- Test: `mobile/test/quiz_explanation_test.dart`
- Test: `mobile/test/quiz_evidence_flow_test.dart`
- Test: `mobile/test/party_selection_page_test.dart`
- Test: `mobile/test/results_exit_test.dart`

**Interfaces:**
- Consumes: all four typed event methods and `classifyAnalyticsFailure` from Task 1.
- Produces: one terminal event per quiz/candidate/result/comparison attempt, corrected legacy semantics and explicit abandonment without political payloads.

- [ ] **Step 1: Add failing quiz-controller tests**

```dart
test('skip is exclusive and analytics never blocks progress', () async {
  final blocker = Completer<void>();
  final sink = RecordingAnalyticsSink(block: blocker.future);
  final controller = quizControllerAtLastQuestion(sink);

  final completion = controller.skip();
  expect(await completion.timeout(const Duration(milliseconds: 100)), isTrue);
  expect(sink.names, containsAll(['thesis_skipped', 'quiz_completed']));
  expect(sink.names, isNot(contains('thesis_answered')));
  blocker.complete();
});

test('quiz load reports one terminal result with trigger and duration',
    () async {
  final sink = RecordingAnalyticsSink();
  final controller = quizControllerWithEmptySession(sink);
  await controller.loadQuestions(trigger: AnalyticsTrigger.retry);
  expect(lastOperation(sink.calls).parameters, containsAll({
    'operation': 'quiz_load',
    'outcome': 'empty',
    'trigger': 'retry',
    'item_count': 0,
  }));
});
```

- [ ] **Step 2: Add failing widget regressions**

Add tests proving:

```dart
testWidgets('failed submit emits failure but not selection completion',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpPartySelectionWithFailingSubmit(tester, sink);
  await tester.tap(find.text('VER RESULTADOS'));
  await tester.pumpAndSettle();
  expect(sink.names, isNot(contains('party_selection_completed')));
  expect(lastOperation(sink.calls).parameters, containsAll({
    'operation': 'results_submit',
    'outcome': 'failed',
    'trigger': 'submit',
  }));
});

testWidgets('nonempty results without eligible leader emit once',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpResultsWithoutEligibleLeader(tester, sink);
  await tester.pump();
  await tester.pump();
  expect(sink.names.where((name) => name == 'results_viewed'), hasLength(1));
});

testWidgets('explicit question exit emits one generic abandonment',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpQuiz(tester, sink: sink, answered: 3, skipped: 1);
  await tester.tap(find.byTooltip('Sair do quiz'));
  await tester.pumpAndSettle();
  expect(lastNamed(sink.calls, 'quiz_abandoned').parameters, containsAll({
    'stage': 'questions',
    'reason': 'back',
    'total_answered': 3,
    'total_skipped': 1,
  }));
});
```

Also cover browser/system back, weighting back, candidate-selection back, `recovery` on stale-candidate return, `restart` on explicit redo, explanation expansion, quiz source open and comparison source open. Assert parameter values never contain thesis/candidate IDs, answer strings or source URLs.

- [ ] **Step 3: Run focused tests and verify red**

Run:

```bash
cd mobile
flutter test test/quiz_controller_analytics_test.dart \
  test/quiz_explanation_test.dart \
  test/quiz_evidence_flow_test.dart \
  test/party_selection_page_test.dart \
  test/results_exit_test.dart
```

Expected: FAIL on duplicate skip semantics, premature selection completion, result emission in `build`, missing operations/abandonment and political method signatures.

- [ ] **Step 4: Instrument question loading and make answer analytics nonblocking**

Change the load signature:

```dart
Future<void> loadQuestions({
  bool force = false,
  AnalyticsTrigger trigger = AnalyticsTrigger.initial,
})
```

Use `Stopwatch` and emit one `operation_result(operation=quiz_load)` in `finally`: `success` with item count, `empty` with zero, or `failed` with the classifier. Retry buttons pass `AnalyticsTrigger.retry`. In `answer`, mutate the session/current index first, then call `unawaited`:

```dart
if (answer == ThesisAnswer.skipped) {
  unawaited(analytics.thesisSkipped());
} else {
  unawaited(analytics.thesisAnswered(timeToAnswerMs: elapsed));
}
if (finished) {
  unawaited(analytics.quizCompleted(
    totalAnswered: session.totalAnswered,
    totalSkipped: session.totalSkipped,
    durationMs: session.quizDurationMs(now: now()),
  ));
}
```

`thesisViewed()` receives no thesis ID/index.

- [ ] **Step 5: Add explicit abandonment guards**

Create one idempotent helper per stage that snapshots only totals and duration
and calls the full event before navigating:

```dart
void _recordAbandonment({
  required AnalyticsQuizStage stage,
  required AnalyticsAbandonReason reason,
}) {
  if (_abandonmentRecorded) return;
  _abandonmentRecorded = true;
  unawaited(_analytics.quizAbandoned(
    stage: stage,
    reason: reason,
    totalAnswered: _session.totalAnswered,
    totalSkipped: _session.totalSkipped,
    durationMs: _session.quizDurationMs(),
  ));
}
```

Use `PopScope` so toolbar and browser back share the helper. Set a local
completed/navigation flag before legitimate forward navigation so route
transitions do not look like abandonment.

Use:

- questions + `back` when leaving quiz;
- weighting + `back` when returning;
- candidate selection + `back` when returning;
- candidate selection + `recovery` when an outdated candidate list sends the person back;
- current incomplete stage + `restart` only for explicit redo.

No `dispose`, `pagehide`, unload or beacon emission.

- [ ] **Step 6: Correct candidate load and submit terminals**

Change candidate load to accept `trigger` and report `candidate_load` with `success/empty/failed`. In submit:

1. start `Stopwatch`;
2. validate locally; a blocked attempt emits `results_submit/blocked/client`;
3. await `session.submit`;
4. if candidates changed, emit `results_submit/stale`, then reload with `trigger=refresh`;
5. on success, emit `party_selection_completed` and `results_submit/success` immediately before navigation;
6. on exception, emit `results_submit/failed` with generic classifier.

`partyToggled()` receives no acronym or selection value.

- [ ] **Step 7: Move results tracking out of build**

Convert the one-shot guard into an init/post-frame method that emits `resultsViewed()` exactly once whenever `session.results.isNotEmpty`, independent of an eligible leader. Rebuilds and scrolling must not re-emit.

- [ ] **Step 8: Replace premature comparison tracking**

Delete every `candidatePositionsViewed` call. For one comparison attempt:

- `success` only after all selected candidate evidence validates;
- `stale` when request generation changes or returned evidence no longer matches;
- `failed` on other errors;
- `item_count` equals the count of selected candidates, never their IDs;
- `comparisonCandidateAdded()` keeps no candidate/position argument.

Use `Stopwatch` and emit one `operation_result(operation=comparison_load, trigger=submit)` per attempt.

- [ ] **Step 9: Track evidence and outbound outcomes**

On first expansion per widget instance emit `engagement_action(action=evidence_open, surface=quiz)` or `surface=comparison`. After each actual opener result emit:

```dart
analytics.engagementAction(
  action: AnalyticsAction.outboundOpen,
  surface: AnalyticsSurface.quiz,
  target: AnalyticsTarget.quizSource,
  outcome: opened ? AnalyticsOutcome.success : AnalyticsOutcome.failed,
);
```

Use `comparisonSource` on comparison. Never include the URI, title, thesis or candidate.

- [ ] **Step 10: Run quiz tests, full widget regressions and analyze**

Run:

```bash
cd mobile
dart format lib/features/quiz lib/features/weighting \
  lib/features/party_selection lib/features/results/results_page.dart \
  lib/features/comparison test/quiz_controller_analytics_test.dart \
  test/quiz_explanation_test.dart test/quiz_evidence_flow_test.dart \
  test/party_selection_page_test.dart test/results_exit_test.dart
flutter test test/quiz_controller_analytics_test.dart \
  test/quiz_explanation_test.dart \
  test/quiz_evidence_flow_test.dart \
  test/party_selection_page_test.dart \
  test/results_exit_test.dart
flutter analyze
```

Expected: PASS; a deliberately never-completing analytics sink cannot delay answer completion or navigation.

- [ ] **Step 11: Commit**

```bash
git add mobile/lib/features/quiz mobile/lib/features/weighting \
  mobile/lib/features/party_selection mobile/lib/features/results/results_page.dart \
  mobile/lib/features/comparison mobile/test/quiz_controller_analytics_test.dart \
  mobile/test/quiz_explanation_test.dart mobile/test/quiz_evidence_flow_test.dart \
  mobile/test/party_selection_page_test.dart mobile/test/results_exit_test.dart
git commit -m "feat: correct and expand quiz analytics"
```

---

### Task 5: Home, news and outbound-link coverage

**Files:**
- Modify: `mobile/lib/features/home/news_session.dart`
- Modify: `mobile/lib/features/home/home_page.dart`
- Modify: `mobile/lib/features/home/widgets/news_card.dart`
- Test: `mobile/test/news_session_test.dart`
- Test: `mobile/test/home_page_news_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService.operationResult`, `engagementAction` and `classifyAnalyticsFailure`.
- Produces: one `news_load` terminal per initial/retry attempt and closed-category outcomes for guide, news index and news article links.

- [ ] **Step 1: Add failing NewsSession terminal tests**

```dart
test('empty initial news load emits one terminal result', () async {
  final sink = RecordingAnalyticsSink();
  final session = NewsSession.testOnly(
    api: FakeNewsApi(const []),
    analytics: AnalyticsService(sink: sink),
  );
  await session.load();
  expect(lastOperation(sink.calls).parameters, containsAll({
    'operation': 'news_load',
    'outcome': 'empty',
    'trigger': 'initial',
    'item_count': 0,
  }));
});

test('retry superseding an older load marks the older attempt stale', () async {
  final first = Completer<List<NewsArticle>>();
  final session = newsSessionWithResponses([first.future, Future.value(news)]);
  final initial = session.load();
  await session.load(trigger: AnalyticsTrigger.retry);
  first.complete(oldNews);
  await initial;
  expect(operationOutcomes(session.analyticsCalls), ['success', 'stale']);
});
```

Order the expected calls by completion: retry succeeds first; the older initial attempt terminates as stale. Also test a classified failure.

- [ ] **Step 2: Add failing Home outbound tests**

```dart
testWidgets('article opener reports only target and observable outcome',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpHome(
    tester,
    sink: sink,
    openLink: (_) async => false,
    articles: news,
  );
  await tester.tap(find.text(news.first.title));
  await tester.pump();
  expect(lastEngagement(sink.calls).parameters, {
    'action': 'outbound_open',
    'surface': 'news',
    'target': 'news_article',
    'outcome': 'failed',
  });
  expect(lastEngagement(sink.calls).parameters!.values,
      isNot(contains(news.first.url)));
});
```

Add equivalent assertions for `quiz_guide` and `news_index`, and assert a retry button passes `trigger=retry`.

- [ ] **Step 3: Run tests and verify red**

Run:

```bash
cd mobile
flutter test test/news_session_test.dart test/home_page_news_test.dart
```

Expected: FAIL because no analytics dependency, triggers or outbound categories exist.

- [ ] **Step 4: Instrument NewsSession attempts**

Add:

```dart
factory NewsSession.testOnly({
  ApiClient? api,
  AnalyticsService? analytics,
})

Future<void> load({
  AnalyticsTrigger trigger = AnalyticsTrigger.initial,
})
```

Give each load a generation number and `Stopwatch`. Exactly one terminal call is emitted in `finally`:

- generation changed: `stale`;
- exception: `failed` plus `failure_type`;
- empty list: `empty` and `item_count=0`;
- nonempty list: `success` and bounded `item_count`.

The analytics call is `unawaited` and never changes UI state.

- [ ] **Step 5: Instrument Home actions through one helper**

Inject `AnalyticsService? analytics` and `LinkOpener? openLink` into `HomePage`. Replace URL-specific analytics with:

```dart
Future<void> _open(
  Uri uri, {
  required AnalyticsSurface surface,
  required AnalyticsTarget target,
}) async {
  var opened = false;
  try {
    opened = await _openLink(uri);
  } catch (_) {
    opened = false;
  }
  unawaited(_analytics.engagementAction(
    action: AnalyticsAction.outboundOpen,
    surface: surface,
    target: target,
    outcome:
        opened ? AnalyticsOutcome.success : AnalyticsOutcome.failed,
  ));
  if (!opened && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
}
```

Map the guide to `surface=home,target=quiz_guide`, the full news index to `surface=news,target=news_index` and cards to `surface=news,target=news_article`. Do not add domain, title or URL parameters.

- [ ] **Step 6: Run tests and analyze**

Run:

```bash
cd mobile
dart format lib/features/home test/news_session_test.dart \
  test/home_page_news_test.dart
flutter test test/news_session_test.dart test/home_page_news_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/home mobile/test/news_session_test.dart \
  mobile/test/home_page_news_test.dart
git commit -m "feat: measure news and outbound engagement"
```

---

### Task 6: Community read/write operation coverage

**Files:**
- Modify: `mobile/lib/features/community/community_feed_page.dart`
- Modify: `mobile/lib/features/community/post_detail_page.dart`
- Modify: `mobile/lib/features/community/create_post_page.dart`
- Test: `mobile/test/community_feed_states_test.dart`
- Test: `mobile/test/community_interactions_test.dart`
- Test: `mobile/test/community_vote_test.dart`
- Test: `mobile/test/community_error_handling_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService.operationResult`, `AnalyticsTrigger` and `classifyAnalyticsFailure`.
- Produces: terminal results for feed/detail/create/comment/vote/report, with no IDs, content, direction, theme or reason.

- [ ] **Step 1: Add failing feed attempt tests**

```dart
testWidgets('feed classifies initial empty, retry and pagination',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpFeed(tester, sink: sink, responses: [emptyPage, firstPage, nextPage]);
  expect(lastOperation(sink.calls).parameters, containsAll({
    'operation': 'community_feed_load',
    'outcome': 'empty',
    'trigger': 'initial',
    'item_count': 0,
  }));

  await tester.tap(find.text('TENTAR NOVAMENTE'));
  await tester.pumpAndSettle();
  await scrollToPagination(tester);
  await tester.pumpAndSettle();
  expect(operationTriggers(sink.calls), ['initial', 'retry', 'pagination']);
});

testWidgets('superseded refresh emits stale exactly once', (tester) async {
  final old = Completer<CommunityPage>();
  final sink = RecordingAnalyticsSink();
  await pumpFeedWithPendingInitial(tester, sink: sink, pending: old);
  await triggerRefreshWithSuccess(tester);
  old.complete(oldPage);
  await tester.pumpAndSettle();
  expect(operationOutcomes(sink.calls), containsAll(['success', 'stale']));
  expect(operationOutcomes(sink.calls).where((v) => v == 'stale'), hasLength(1));
});
```

- [ ] **Step 2: Add failing write-operation tests**

```dart
testWidgets('vote sends no post id or direction', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpPostDetail(tester, sink: sink);
  await tester.tap(find.byTooltip('Apoiar'));
  await tester.pumpAndSettle();
  final event = lastOperation(sink.calls);
  expect(event.parameters, containsAll({
    'operation': 'community_vote',
    'outcome': 'success',
    'trigger': 'submit',
  }));
  expect(event.parameters, isNot(contains(anyOf('post_id', 'value', 'vote'))));
});

testWidgets('moderation rejection is generic', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpCreatePost(
    tester,
    sink: sink,
    error: const ApiException('private moderation text', statusCode: 422),
  );
  await submitPost(tester, 'conteúdo que não pode chegar ao analytics');
  final event = lastOperation(sink.calls);
  expect(event.parameters, containsAll({
    'operation': 'community_post_create',
    'outcome': 'failed',
    'failure_type': 'moderation_rejected',
  }));
  expect(event.parameters.toString(), isNot(contains('conteúdo')));
  expect(event.parameters.toString(), isNot(contains('private moderation')));
});
```

Also cover detail initial/retry/refresh, post creation, comment creation, report success/failure, and prove canceling the report-reason dialog emits nothing.

- [ ] **Step 3: Run community tests and verify red**

Run:

```bash
cd mobile
flutter test test/community_feed_states_test.dart \
  test/community_interactions_test.dart \
  test/community_vote_test.dart \
  test/community_error_handling_test.dart
```

Expected: FAIL because the pages do not accept analytics and do not emit operations.

- [ ] **Step 4: Add analytics injection and trigger-aware loaders**

Use:

```dart
const CommunityFeedPage({
  super.key,
  this.apiClient,
  this.analytics,
});

const PostDetailPage({
  super.key,
  required this.postId,
  this.apiClient,
  this.analytics,
});

const CreatePostPage({
  super.key,
  this.apiClient,
  this.initialThemeSlug,
  this.analytics,
});

Future<void> _loadPage(
  int page, {
  required AnalyticsTrigger trigger,
});

Future<void> _load({
  AnalyticsTrigger trigger = AnalyticsTrigger.initial,
});
```

The feed passes the same `AnalyticsService` to detail/create routes. Retry buttons use `retry`, pull-to-refresh uses `refresh` and next-page scroll uses `pagination`.

- [ ] **Step 5: Emit exactly one read terminal per attempt**

For `community_feed_load` and `community_post_load`, record generation, timer, outcome, failure type and item count. A generation mismatch is `stale` even if the stale response would otherwise succeed. Emit once from `finally` with `unawaited`. Preserve existing stale-response UI guards.

- [ ] **Step 6: Instrument writes after a real attempt begins**

Wrap these existing API calls:

| Call site | Operation | Trigger | Item count |
|---|---|---|---|
| create post | `community_post_create` | `submit` | none |
| add comment | `community_comment_create` | `submit` | none |
| vote | `community_vote` | `submit` | none |
| accepted report confirmation | `community_report` | `submit` | none |

Success is emitted only after the API resolves. Failure uses `classifyAnalyticsFailure(error, moderationWrite: true)` for post/comment and `false` for vote/report. Do not instrument delete, canceled dialog, draft text, theme selection, reason, IDs or vote direction.

- [ ] **Step 7: Run tests and analyze**

Run:

```bash
cd mobile
dart format lib/features/community test/community_feed_states_test.dart \
  test/community_interactions_test.dart test/community_vote_test.dart \
  test/community_error_handling_test.dart
flutter test test/community_feed_states_test.dart \
  test/community_interactions_test.dart \
  test/community_vote_test.dart \
  test/community_error_handling_test.dart
flutter analyze
```

Expected: PASS; every attempted operation has exactly one terminal event.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/community \
  mobile/test/community_feed_states_test.dart \
  mobile/test/community_interactions_test.dart \
  mobile/test/community_vote_test.dart \
  mobile/test/community_error_handling_test.dart
git commit -m "feat: measure community operation outcomes"
```

---

### Task 7: Sharing render and destination coverage

**Files:**
- Modify: `mobile/lib/features/results/results_page.dart`
- Modify: `mobile/lib/features/results/sharing/result_share_page.dart`
- Modify: `mobile/lib/features/results/sharing/result_share_controls.dart`
- Test: `mobile/test/result_share_page_test.dart`
- Test: `mobile/test/result_share_service_test.dart`
- Test: `mobile/test/results_share_navigation_test.dart`

**Interfaces:**
- Consumes: `AnalyticsService.operationResult`, `engagementAction` and canonical `resultShareRoute`.
- Produces: `share_render` terminal events and `share` engagement by closed destination only.

- [ ] **Step 1: Add failing render-generation tests**

```dart
testWidgets('render emits success and stale for superseded work',
    (tester) async {
  final first = Completer<Uint8List>();
  final sink = RecordingAnalyticsSink();
  await pumpSharePage(tester, sink: sink, firstRender: first.future);
  await selectAnotherPalette(tester);
  await tester.pumpAndSettle();
  first.complete(validPng);
  await tester.pumpAndSettle();
  expect(operationOutcomes(sink.calls), containsAll(['success', 'stale']));
  expect(operationNames(sink.calls).toSet(), {'share_render'});
});
```

The first render uses `trigger=initial`; format, variant and palette changes use `trigger=refresh`.

- [ ] **Step 2: Add failing destination and fallback tests**

```dart
testWidgets('download reports one safe share action', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpSharePage(tester, sink: sink);
  await tester.tap(find.text('Baixar imagem'));
  await tester.pumpAndSettle();
  expect(lastEngagement(sink.calls).parameters, {
    'action': 'share',
    'surface': 'results',
    'target': 'download',
    'outcome': 'success',
  });
  expect(lastEngagement(sink.calls).parameters!.values,
      isNot(contains(anyOf('Pessoa 1', 'https://fpolitico.com.br'))));
});

testWidgets('native-share failure plus automatic download is one click',
    (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpSharePage(
    tester,
    sink: sink,
    nativeShareResult: ShareResult.unavailable,
  );
  await tester.tap(find.text('Compartilhar'));
  await tester.pumpAndSettle();
  final shares = named(sink.calls, 'engagement_action');
  expect(shares, hasLength(1));
  expect(shares.single.parameters, containsAll({
    'target': 'native_share',
    'outcome': 'failed',
  }));
});
```

Also test `twitter`, `whatsapp`, `copy_link` and `instagram_help`. Instagram help has no outcome because opening a help dialog is not an external success signal.

- [ ] **Step 3: Run tests and verify red**

Run:

```bash
cd mobile
flutter test test/result_share_page_test.dart \
  test/result_share_service_test.dart \
  test/results_share_navigation_test.dart
```

Expected: FAIL because render/action events and analytics injection are absent.

- [ ] **Step 4: Inject analytics and instrument render generations**

Use:

```dart
const ResultSharePage({
  super.key,
  required this.data,
  this.service,
  this.analytics,
});
```

`_queueImage` accepts `AnalyticsTrigger` and increments a request generation. `_prepareImage` emits exactly one `share_render` result:

- superseded generation: `stale`;
- valid bytes: `success`;
- exception or unusable bytes: `failed` with generic classifier;
- duration only, never candidate count, ranking, caption, URL or palette.

- [ ] **Step 5: Instrument deliberate destination actions**

After each observable result, emit
`engagement_action(action=share,surface=results,outcome=success|failed)` with
exactly one of `target=native_share`, `target=download`,
`target=copy_link`, `target=twitter` or `target=whatsapp`. Emit
`target=instagram_help` when its deliberate help flow opens, without outcome.

If native share falls back to download automatically, only the selected `native_share/failed` event is emitted. A direct download click emits `download`.

- [ ] **Step 6: Prove analytics cannot block sharing**

Add a test sink whose future never completes. Tap share and assert the injected `ResultShareService` receives the call before a 100 ms timeout. Keep all analytics calls under `unawaited`.

- [ ] **Step 7: Run tests and analyze**

Run:

```bash
cd mobile
dart format lib/features/results test/result_share_page_test.dart \
  test/result_share_service_test.dart test/results_share_navigation_test.dart
flutter test test/result_share_page_test.dart \
  test/result_share_service_test.dart \
  test/results_share_navigation_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/results \
  mobile/test/result_share_page_test.dart \
  mobile/test/result_share_service_test.dart \
  mobile/test/results_share_navigation_test.dart
git commit -m "feat: measure privacy-safe result sharing"
```

---

### Task 8: Follow-validation operations and public transparency

**Files:**
- Modify: `mobile/lib/features/political_actors/politician_follow_validation_page.dart`
- Modify: `mobile/lib/features/privacy/privacy_page.dart`
- Test: `mobile/test/politician_follow_validation_page_test.dart`
- Test: `mobile/test/privacy_page_test.dart`

**Interfaces:**
- Consumes: `operationResult`, `engagementAction` and the existing five parameter-free `follow_waitlist_*` events.
- Produces: generic status/register outcomes and public copy that matches the final GA4/BigQuery behavior.

- [ ] **Step 1: Add failing follow-operation tests**

```dart
testWidgets('status and registration emit no identifier', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpFollowValidation(tester, sink: sink, registered: false);
  expect(lastOperation(sink.calls).parameters, containsAll({
    'operation': 'follow_status_load',
    'outcome': 'success',
    'trigger': 'initial',
  }));

  await tester.tap(find.text('QUERO ACOMPANHAR'));
  await tester.pumpAndSettle();
  final register = lastOperation(sink.calls);
  expect(register.parameters, containsAll({
    'operation': 'follow_register',
    'outcome': 'success',
    'trigger': 'submit',
  }));
  expect(register.parameters, isNot(contains(anyOf(
    'anonymous_id',
    'device_id',
    'hash',
  ))));
});
```

Add failure tests for both operations and preserve assertions for the five existing legacy events.

- [ ] **Step 2: Add failing privacy copy and link-event tests**

```dart
testWidgets('retention copy distinguishes legacy and future BigQuery tables',
    (tester) async {
  await pumpPrivacy(tester, analyticsEnabled: true);
  expect(
    find.textContaining(
      'tabelas históricas existentes podem não ter expiração',
      skipOffstage: false,
    ),
    findsOneWidget,
  );
  expect(
    find.textContaining(
      'novas tabelas expiram em até 60 dias',
      skipOffstage: false,
    ),
    findsOneWidget,
  );
});

testWidgets('privacy links report only closed targets', (tester) async {
  final sink = RecordingAnalyticsSink();
  await pumpPrivacy(tester, sink: sink, openLink: (_) async => true);
  await tapOffstageText(tester, 'ENVIAR E-MAIL');
  await tapOffstageText(tester, 'SAIBA COMO O GOOGLE USA DADOS');
  expect(engagementTargets(sink.calls), ['privacy_email', 'google_privacy']);
});
```

The optional-metrics copy must explicitly say events cover generic screens, feature use and operation outcomes, while answers, political positions, candidate/party/ranking/affinity and free text are excluded.

- [ ] **Step 3: Run tests and verify red**

Run:

```bash
cd mobile
flutter test test/politician_follow_validation_page_test.dart \
  test/privacy_page_test.dart
```

Expected: FAIL because operations/link events and explicit legacy-retention wording are absent.

- [ ] **Step 4: Instrument follow status and registration**

Inject the shared `AnalyticsService` from `MyApp`. Wrap the actual status request as `follow_status_load` with `initial` and the registration request as `follow_register` with `submit`. Use `Stopwatch` and the generic classifier. Keep `follow_waitlist_viewed`, `follow_waitlist_prompt_viewed`, `follow_waitlist_cta_clicked`, `follow_waitlist_registered` and `follow_waitlist_failed` parameter-free.

- [ ] **Step 5: Track privacy outbound outcomes**

Inject `AnalyticsService? analytics`. Change `_open` to receive `AnalyticsTarget` and, after the opener resolves, emit:

```dart
unawaited(_analytics.engagementAction(
  action: AnalyticsAction.outboundOpen,
  surface: AnalyticsSurface.privacy,
  target: target,
  outcome: opened ? AnalyticsOutcome.success : AnalyticsOutcome.failed,
));
```

Map mail to `privacyEmail` and Google partner-sites to `googlePrivacy`. Never send the email address or URI.

- [ ] **Step 6: Align the public copy**

For enabled Analytics, use wording with these facts:

- consent is optional and revocable;
- generic screens, feature interactions and operation outcomes/durations may be sent;
- page/referrer/device fields and a pseudonymous Firebase installation identifier may be added by Google after consent;
- no quiz answers, political positions, candidates, parties, ranking, affinity, functional identifier or free text is sent in custom events;
- GA4 retention is two months;
- historical BigQuery tables can remain without expiration, while tables created after the operational adjustment expire in 60 days;
- production activation remains conditional on configuration matching this text.

- [ ] **Step 7: Run tests and analyze**

Run:

```bash
cd mobile
dart format lib/features/political_actors/politician_follow_validation_page.dart \
  lib/features/privacy/privacy_page.dart \
  test/politician_follow_validation_page_test.dart test/privacy_page_test.dart
flutter test test/politician_follow_validation_page_test.dart \
  test/privacy_page_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/features/political_actors/politician_follow_validation_page.dart \
  mobile/lib/features/privacy/privacy_page.dart \
  mobile/test/politician_follow_validation_page_test.dart \
  mobile/test/privacy_page_test.dart
git commit -m "feat: cover follow flow and clarify analytics notice"
```

---

### Task 9: Safe GA4/BigQuery preparation and executable cutover record

**Files:**
- Create: `docs/operations/web-product-analytics-cutover-2026-09.md`
- Modify: `docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md`
- Test: `mobile/test/analytics_bootstrap_files_test.dart`
- Test: `mobile/test/privacy_build_config_test.dart`

**Interfaces:**
- Consumes: property `535804267`, measurement ID `G-0P9XLRYVWT`, dataset `farol-politico-495210:analytics_535804267` and the taxonomic parameter names from Task 1.
- Produces: non-destructive external configuration/readback, a redacted operational record, explicit supersession of the destructive old plan and an exact post-merge cutover/rollback procedure.

- [ ] **Step 1: Add static regression checks before touching external state**

Extend `analytics_bootstrap_files_test.dart` to assert:

```dart
for (final forbidden in [
  'googletagmanager.com/gtag/js',
  "gtag('js'",
  "gtag('config'",
  "gtag('event'",
]) {
  expect(index, isNot(contains(forbidden)));
}
expect(workflow, contains('--no-web-resources-cdn'));
expect(workflow, contains('--dart-define=ANALYTICS_ENABLED='));
```

Keep `privacy_build_config_test.dart` proving `ANALYTICS_ENABLED` is exactly `true` or `false` and all production privacy identity defines are required.

- [ ] **Step 2: Run static tests**

Run:

```bash
cd mobile
flutter test test/analytics_bootstrap_files_test.dart \
  test/privacy_build_config_test.dart
```

Expected: PASS on the existing single-pipeline/bootstrap controls; any failure is a hard stop to fix before configuration.

- [ ] **Step 3: Snapshot property, stream, link, dataset, tables and ACLs read-only**

Run authenticated inventory without printing access tokens:

```bash
gcloud config get-value project
gcloud auth list --filter=status:ACTIVE --format='value(account)'
bq show --format=prettyjson \
  farol-politico-495210:analytics_535804267
bq ls --format=prettyjson \
  farol-politico-495210:analytics_535804267
```

Using the Analytics Admin API or authenticated GA UI, verify one Web destination with property `535804267` and measurement ID `G-0P9XLRYVWT`, plus the current BigQuery link. Compare with `mobile/lib/firebase_options.dart`. Stop external mutation if there is another event destination or pipeline.

Record only configuration fields and table names/expiration metadata in the operations document. Do not record cookies, event payloads, `user_pseudo_id`, query strings or access tokens.

- [ ] **Step 4: Apply and read back GA4 privacy settings**

Set and then read back:

- Google Signals off;
- ads personalization off;
- user-provided data off;
- no advertising integration/feature;
- Enhanced Measurement page views on and scroll/outbound/search/video/download/form off;
- email redaction on;
- query-parameter redaction for `fbclid,gclid,dclid,gbraid,wbraid`;
- event/user retention two months;
- reset on new activity off.

Do not enable Android/iOS and do not create/relink any property, stream or Firebase project. A mismatch after readback is a hard stop for production activation, not permission to weaken the notice.

- [ ] **Step 5: Create only missing event-scoped custom definitions**

List existing definitions and quota first. Create no user-scoped definition and no `schema_version`.

Event-scoped dimensions:

```text
screen
source
action
surface
target
operation
outcome
trigger
failure_type
stage
reason
```

Event-scoped metrics:

```text
duration_ms — MILLISECONDS
item_count — STANDARD
```

Use `properties/535804267/customDimensions` and `properties/535804267/customMetrics`. Create only absent exact matches; do not archive, rename or alias an existing definition. A conflict or insufficient quota is a hard stop.

- [ ] **Step 6: Apply only the safe future-table BigQuery TTL**

Snapshot ACLs and every existing table `expirationTime`, then run:

```bash
bq update --default_table_expiration 5184000 \
  farol-politico-495210:analytics_535804267
bq show --format=prettyjson \
  farol-politico-495210:analytics_535804267
```

Readback must show `defaultTableExpirationMs=5184000000`. Recompare ACLs and table metadata: no permission change and every legacy table expiration remains identical. Keep daily export, keep streaming/fresh-daily off and disable future user-data/pseudonymous-user export. Never run `bq rm`, `ALTER TABLE`, wildcard mutation, per-table expiration updates or a broad dataset patch.

- [ ] **Step 7: Write the operational document with exact procedures**

The document must contain:

1. immutable identifiers and “no Android/iOS” decision;
2. redacted preflight/readback facts from Steps 3–6;
3. the 26-event allowlist and 13 custom definitions;
4. browser evidence rules that retain host/event/key set/count but not query values;
5. same-SHA cutover commands;
6. rollback commands and stale-tab caveat;
7. post-cutover BigQuery query rules;
8. hard stops.

Use this exact same-SHA sequence:

```bash
export FP_REPO='mo-bruno/voting-advice-brazil'
export FP_CUTOVER_SHA="$(git rev-parse origin/main)"
gh variable set ANALYTICS_ENABLED --body false --repo "$FP_REPO"
gh workflow run deploy-backend.yml --ref main --repo "$FP_REPO"
```

After the disabled Backend/Web runs both prove `headSha == FP_CUTOVER_SHA`, freeze merges, retain the successful Backend run ID, set true and rerun that exact run:

```bash
gh variable set ANALYTICS_ENABLED --body true --repo "$FP_REPO"
gh run rerun "$FP_BACKEND_RUN_ID" --repo "$FP_REPO"
```

Define `CUTOVER_UTC` only when the true bundle is confirmed served and the consented Network request shows `tid=G-0P9XLRYVWT`. Rollback sets false and reruns the same Backend run; changing the variable without redeploy is explicitly insufficient, and old open tabs may continue until reload/close.

- [ ] **Step 8: Add post-cutover query templates that never select identifiers**

Use a narrow `_TABLE_SUFFIX` and `event_timestamp >= UNIX_MICROS(@cutover)`. Include queries for event counts, out-of-allowlist names, parameter-key sets, expected Web stream/platform, consent storage distribution, and absence of `events_intraday_*`, `users_*` and `pseudonymous_users_*` after cutover. Never select `user_pseudo_id` or parameter values that can contain free text.

- [ ] **Step 9: Supersede the conflicting old plan**

At the first line of `2026-09-29-analytics-cutover-and-cleanup.md` add:

```markdown
> **SUPERSEDED — do not execute.** The approved design and plan dated
> 2026-09-30 preserve GA4 property 535804267 and its historical BigQuery data.
> They replace this document's property creation, relink and deletion steps.
```

- [ ] **Step 10: Verify docs and commit**

Run:

```bash
rg -n "SUPERSEDED|535804267|G-0P9XLRYVWT|5184000000|no Android|Android/iOS|CUTOVER_UTC|user_pseudo_id" \
  docs/operations/web-product-analytics-cutover-2026-09.md \
  docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md
cd mobile
flutter test test/analytics_bootstrap_files_test.dart \
  test/privacy_build_config_test.dart
```

Expected: the new runbook contains the fixed identifiers, safe TTL, cutover and prohibition; the old plan starts with the supersession banner; tests PASS.

`docs/` is ignored for new files, so stage the runbook explicitly:

```bash
git add -f docs/operations/web-product-analytics-cutover-2026-09.md
git add docs/superpowers/plans/2026-09-29-analytics-cutover-and-cleanup.md \
  mobile/test/analytics_bootstrap_files_test.dart \
  mobile/test/privacy_build_config_test.dart
git commit -m "docs: define safe analytics cutover"
```

---

### Task 10: Full verification, independent review and pull request

**Files:**
- Verify: all modified files in Tasks 1–9.
- No production activation or deployment in this task.

**Interfaces:**
- Consumes: completed branch, test suites, external readbacks and cutover runbook.
- Produces: reviewed branch pushed to GitHub and a PR that remains safe with `ANALYTICS_ENABLED=false`.

- [ ] **Step 1: Inspect scope and forbidden payloads**

Run:

```bash
git status --short
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
rg -n "candidatePositionsViewed|candidate_positions_viewed|candidate_id|party_acronym|topCandidateId|topScorePercent|stance:|thesisId:" \
  mobile/lib/core/analytics mobile/lib/features
rg -n "gtag\\('event'|user_id|schema_version|sendBeacon|pagehide" \
  mobile/lib mobile/web
```

Expected: `git diff --check` is clean; deprecated event/direct gtag/user ID/beacon patterns are absent from production analytics paths. Domain model/API uses found outside an analytics call are inspected, not mechanically deleted.

- [ ] **Step 2: Run backend regression without changing its schema**

Run:

```bash
cd backend
if command -v uv >/dev/null 2>&1; then
  uv run pytest
  uv run ruff check .
  uv run mypy app/
else
  .venv/bin/pytest
  .venv/bin/ruff check .
  .venv/bin/mypy app/
fi
```

Expected: all existing backend tests PASS, Ruff clean, mypy clean; `git diff -- backend` is empty because this feature adds no persistence or endpoint.

- [ ] **Step 3: Run the complete Flutter and browser suites**

Run:

```bash
cd ../mobile
flutter analyze
flutter test
flutter test --platform chrome test/analytics_default_pipeline_web_test.dart
```

Expected: analyze has no issues; all Flutter tests PASS; Chrome proves lazy initialization, revoke and regrant behavior through the single Firebase pipeline.

- [ ] **Step 4: Build the exact disabled production bundle**

Load the public repository variables without printing them and build:

```bash
export FP_REPO='mo-bruno/voting-advice-brazil'
export FP_CONTROLLER_NAME="$(gh variable get PRIVACY_CONTROLLER_NAME \
  --repo "$FP_REPO" --json value --jq .value)"
cd mobile
flutter build web --release \
  --no-web-resources-cdn \
  --dart-define=IOT_FEATURE_ENABLED=false \
  --dart-define=POLITICIAN_FOLLOW_ENABLED=false \
  --dart-define=ANALYTICS_ENABLED=false \
  --dart-define=PUBLIC_APP_URL=https://fpolitico.com.br \
  --dart-define=PRIVACY_CONTROLLER_NAME="$FP_CONTROLLER_NAME" \
  --dart-define=PRIVACY_CONTACT_EMAIL=privacidade@fpolitico.com.br
```

Expected: release build succeeds. Search `build/web` for remote Google font/CanvasKit/tag bootstrap references and fail if a pre-consent resource remains.

- [ ] **Step 5: Run local real-browser privacy and coverage QA**

Serve `mobile/build/web` locally and use a clean Chrome profile with Network “Preserve log” and Storage:

1. pending: zero requests to `googletagmanager.com`, `google-analytics.com`, `firebaseinstallations.googleapis.com`, `fonts.googleapis.com`, `fonts.gstatic.com` and Flutter CDN resources at `www.gstatic.com`; zero `_ga`/FID;
2. denied plus reload: same;
3. a separate build with `ANALYTICS_ENABLED=true` against local hosting, accepted: one pipeline, each event once, `tid=G-0P9XLRYVWT` and only allowlisted keys;
4. revoke: no later hit;
5. regrant: only future actions appear;
6. exercise tabs/routes, Home, quiz, news, community, follow and share;
7. retain only redacted host/event/key-set/count evidence, never full hit query strings.

Any pre-consent/post-revoke hit, duplicate, wrong ID, forbidden parameter or remote resource is a hard stop.

- [ ] **Step 6: Run independent code review**

Invoke `superpowers:requesting-code-review` on `origin/main...HEAD`. Resolve every correctness/privacy finding, rerun its focused test and rerun Steps 1–5 if the fix touches shared analytics, consent, navigation or policy.

- [ ] **Step 7: Confirm clean branch and commit any review fixes**

Run:

```bash
git status --short
git log --oneline --decorate origin/main..HEAD
git diff --check origin/main...HEAD
```

Expected: only the intended branch commits exist and the worktree is clean. If review fixes are present:

```bash
git add mobile docs
git commit -m "fix: address analytics coverage review"
```

- [ ] **Step 8: Push the isolated branch**

```bash
git push -u origin codex/web-analytics-coverage
```

Expected: remote branch is created without force push.

- [ ] **Step 9: Open the pull request**

```bash
gh pr create \
  --repo mo-bruno/voting-advice-brazil \
  --base main \
  --head codex/web-analytics-coverage \
  --title "feat: ampliar cobertura segura do Google Analytics" \
  --body "Amplia a cobertura de produto do site com quatro eventos genéricos, corrige o funil existente e mantém um único pipeline Firebase/GA4 após consentimento. Não coleta nem persiste respostas, posições políticas, candidaturas, partidos, ranking, score ou afinidade; não inclui Android/iOS. Inclui testes de corrida de consentimento, navegação, quiz, notícias, comunidade, acompanhamento, compartilhamento, transparência e runbook de cutover. O PR não ativa produção: ANALYTICS_ENABLED deve permanecer false até o merge, QA e canário do mesmo SHA."
```

- [ ] **Step 10: Verify the PR instead of assuming creation succeeded**

```bash
gh pr view \
  --repo mo-bruno/voting-advice-brazil \
  --json number,url,state,headRefName,baseRefName,statusCheckRollup
```

Expected: PR open, base `main`, head `codex/web-analytics-coverage`. Report the URL, test totals, external configuration completed, any activation hard stop and the explicit next action: merge, then execute the same-SHA disabled deploy/canary sequence from the runbook.

---

## Self-review record

- **Spec coverage:** Tasks 1–8 cover the 26-event contract, consent generation, navigation, quiz, evidence, news, community, sharing, follow and transparency. Task 9 covers the unchanged property, custom definitions, non-destructive TTL, historical separation, cutover and rollback. Task 10 covers backend, Flutter, Chrome, release build, real browser, review and PR.
- **Explicit exclusions:** no backend schema/API change, no political aggregate, no response/rank tracking, no new property, no history deletion, no Android/iOS, no IoT, no Sentry/Crashlytics/Performance/Web Vitals.
- **Type consistency:** all call sites consume the enhanced enums and four `AnalyticsService` signatures defined in Task 1; triggers/outcomes/failure types use the same wire values throughout.
- **Review-focus coverage:** consent race is in Task 2; stale attempts in Tasks 4–7; back/navigation duplication in Tasks 3–4; share fallback in Task 7; blocked runtime in Tasks 2, 4 and 7.
- **Placeholder scan:** the plan contains no deferred implementation marker; operational variables are defined commands or values captured from authenticated readback.
