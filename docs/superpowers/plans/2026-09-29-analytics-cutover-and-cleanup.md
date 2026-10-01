> **SUPERSEDED — do not execute.** The approved design and plan dated
> 2026-09-30 preserve GA4 property 535804267 and its historical BigQuery data.
> They replace this document's property creation, relink and deletion steps.

# Analytics Cutover and Historical Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy and prove the privacy gates, cut Firebase Analytics to a clean GA4 property with short retention and a bounded BigQuery export, then remove the contaminated historical analytics and quiz-response data without touching current product data.

**Architecture:** Treat production work as a staged cutover with evidence gates: code first, live write/traffic verification second, new analytics destination third, and irreversible cleanup last. Resolve every deletion target from authoritative inventory, validate it narrowly, preserve recovery information, and require a fresh human confirmation immediately before destructive commits.

**Tech Stack:** GitHub Actions, Firebase Hosting/Analytics, GA4 Admin, Google Cloud Run, Cloud Logging, BigQuery/bq, gcloud, Firebase Management API, Neon PostgreSQL/psql, browser DevTools

**Spec:** `docs/superpowers/specs/2026-09-29-analytics-privacy-and-data-minimization-design.md`

## Global Constraints

- Do not begin this plan until both code plans are merged and their full local/CI checks pass.
- Production Web deployment is blocked until the user supplies the real public controller name and `privacidade@fpolitico.com.br` receives mail reliably.
- The private destination mailbox must never appear in source, GitHub variables, screenshots, command output, logs, or the public notice.
- The backend persistence-gate revision must receive 100% of Cloud Run traffic with `IOT_FEATURE_ENABLED=false` before the Web release or any database deletion.
- Do not roll back to a backend revision from before the persistence gate after historical rows are removed.
- GA4 event/user retention is 2 months with reset-on-new-activity disabled; ads personalization, Google Signals, user-provided data, and ad links stay off.
- Query-parameter redaction covers `fbclid`, `gclid`, `dclid`, `gbraid`, and `wbraid` before new traffic is accepted as clean.
- BigQuery exports daily events only: no streaming export and no `users_*` or `pseudonymous_users_*` user-data tables. Daily event rows still contain GA4's `user_pseudo_id`. New tables expire after 5,184,000 seconds (60 days).
- Never delete a BigQuery dataset, table, database row, or GA property before recording inventory, recovery window, timestamps, and post-cutover evidence.
- BigQuery tables are deleted by validated explicit table IDs, never by wildcard, glob, dataset-wide recursive deletion, or project deletion.
- Neon cleanup deletes only `quiz_responses` and `devices`; it must preserve `politician_follow_interests`, follows, IoT links/events, posts, comments, votes, reports, locks, and moderation data.
- `politician_follow_interests` follows its own withdrawal/experiment/180-day retention rule and is not part of quiz cleanup.
- The old GA4 property is moved to Trash only after the new property and daily BigQuery export pass end-to-end validation.
- Every rejected GA4 candidate is entered immediately in a rejected-candidate
  register in the evidence document. Each entry contains the property ID,
  every stream ID and measurement ID plus app mapping, BigQueryLink name and
  removal state, dataset ID/location, explicit table list/count, and the
  effective dataset/table expirations. A missing or excessive table TTL is
  corrected to the approved 60-day bound immediately while collection remains
  paused; rejection never leaves tables unbounded. An entry closes only after
  a separately confirmed retirement of each destructive target, or with a
  concrete owner and due date for that confirmation. Task 10 cannot close
  while any rejected candidate lacks this inventory, bounded TTL, and one of
  those two dispositions.

## Review Focus

- A client from an old cached Web bundle still sends `device_id` after backend deployment: the live API returns a ranking but table counts and timestamps do not change; Task 2 pins this.
- Revocation occurs after Firebase has initialized: subsequent browser requests to Google Analytics cease, including after reload; Task 3 pins this.
- The newly linked BigQuery dataset appears after its first export without a default expiration or with streaming/user export enabled: cleanup stops and configuration is corrected before accepting the cutover; Task 5 pins this.
- An unexpected table, foreign key, or writer appears before Neon deletion: the transaction is rolled back and no data is removed; Task 8 pins this.
- The new stream accidentally receives political parameters, duplicate events, or denied-consent traffic: the old property remains available and cleanup does not start; Tasks 3 and 6 pin this.

---

### Task 1: Close external identity and delivery prerequisites

**Files:**
- External state: Registro.br DNS, ImprovMX alias, GitHub repository variables
- Record evidence in: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: user-approved controller identity, public mailbox `privacidade@fpolitico.com.br`, GitHub repository `mo-bruno/voting-advice-brazil`.
- Produces: a working public contact and three public deployment variables, with no private destination disclosure.

- [ ] **Step 1: Wait for authoritative DNS publication without changing records**

Resolve the current authoritative nameservers instead of assuming provider hostnames, then run the same read-only checks against every authority:

```bash
set -euo pipefail
mapfile -t authoritative_ns < <(
  dig +short NS fpolitico.com.br | sed 's/\.$//' | LC_ALL=C sort -u
)
((${#authoritative_ns[@]} >= 2))
for ns in "${authoritative_ns[@]}"; do
  dig @"$ns" fpolitico.com.br A +noall +answer
  dig @"$ns" fpolitico.com.br MX +noall +answer
  dig @"$ns" fpolitico.com.br TXT +noall +answer
  dig @"$ns" _dmarc.fpolitico.com.br TXT +noall +answer
  dig @"$ns" www.fpolitico.com.br CNAME +noall +answer
done
```

Expected after propagation: the currently resolved authorities (observed on 2026-09-29 as `a.sec.dns.br` and `c.sec.dns.br`) agree on apex A `199.36.158.100`; MX 10/20 ImprovMX; SPF includes ImprovMX with `-all`; DMARC is reject; `www` points to the Firebase site. If authorities disagree or still show a provider default, stop this task and continue waiting; do not resubmit or edit the zone.

- [ ] **Step 2: Verify inbound privacy mail without exposing the destination**

Send a uniquely titled message to `privacidade@fpolitico.com.br` from an unrelated sender and confirm it arrives. Record only the send/receive timestamps, subject token, and success; do not record the forwarding destination address or message body.

Expected: inbound delivery succeeds. Do not claim private-address replies until authenticated outbound sending as the public address is configured and tested.

- [ ] **Step 3: Define mailbox retention and safe outbound handling**

Record an operator SOP that privacy messages are retained while the request is handled and afterward only for a documented legal-rights/compliance need, reviewed at least annually and removed when that need ends. Distinguish the delivered mailbox copy from forwarding logs.

In ImprovMX Account Settings → Privacy and the domain-specific logging override, read back the effective log detail level and account-wide retention without opening/capturing the email-log listing. The minimum target is `Minimum` detail and 7 days. If the effective domain setting is `Standard` or `Full`, or retention is longer than 7 days, stop and change it to the minimum approved setting before publishing the corresponding notice; then read it back. Record only the setting names/days. Never screenshot or output an alias destination because Standard logs can include the forwarded-to address.

Before any reply, configure and test authenticated outbound `Send as` for `privacidade@fpolitico.com.br` with the provider-supported SPF/DKIM/DMARC path, or define another explicitly public reply channel. Never answer from the private forwarding destination and never promise that replies preserve the public address until this test passes. Record only the public From address, authentication result, timestamps, and outcome.

- [ ] **Step 4: Obtain and validate the public controller name**

The user provides one real civil name or legal-entity name for public display. Export it only in the operator shell, together with the already approved email:

```bash
test -n "${PRIVACY_CONTROLLER_NAME:?Set the user-approved public controller name}"
export PRIVACY_CONTACT_EMAIL='privacidade@fpolitico.com.br'
```

Reject empty/test/example/TODO/TBD/placeholder values and reject `Farol Político` alone if it is only the brand rather than the legal identity deciding the purposes and means of processing. Record a human check of the real civil/legal identity; string validation alone is insufficient.

- [ ] **Step 5: Create the public GitHub variables**

```bash
gh variable set PRIVACY_CONTROLLER_NAME \
  --body "$PRIVACY_CONTROLLER_NAME" \
  --repo mo-bruno/voting-advice-brazil
gh variable set PRIVACY_CONTACT_EMAIL \
  --body "$PRIVACY_CONTACT_EMAIL" \
  --repo mo-bruno/voting-advice-brazil
gh variable set ANALYTICS_ENABLED \
  --body 'false' \
  --repo mo-bruno/voting-advice-brazil
gh variable list --repo mo-bruno/voting-advice-brazil
```

Expected: all three variable names are listed. `ANALYTICS_ENABLED=false` is the safe initial production state and remains false until Task 6 accepts the hardened destination. Do not print or persist the private forwarding destination.

- [ ] **Step 6: Record the accountable-contact decision**

Document outside the source code whether the controller qualifies for the applicable small-agent dispensation while maintaining the public channel, or whether a formally appointed data-protection officer/contact must also be identified. If the dispensation cannot be substantiated and no officer is appointed, stop before production publication rather than inventing a title or identity.

- [ ] **Step 7: Verify Cloud Logging routing and each applicable retention**

Run a read-only inventory before publishing the notice:

```bash
gcloud logging sinks list \
  --project=farol-politico-495210 \
  --format=json > /tmp/farol-logging-sinks.json
gcloud logging buckets list \
  --project=farol-politico-495210 \
  --format=json > /tmp/farol-logging-buckets.json
gcloud logging sinks describe _Default \
  --project=farol-politico-495210 \
  --format=json > /tmp/farol-logging-default-sink.json
gcloud logging buckets describe _Default \
  --location=global \
  --project=farol-politico-495210 \
  --format=json > /tmp/farol-logging-default.json
gcloud logging buckets describe _Required \
  --location=global \
  --project=farol-politico-495210 \
  --format=json > /tmp/farol-logging-required.json
jq -er '.retentionDays | tonumber' /tmp/farol-logging-default.json
jq -er '.retentionDays | tonumber' /tmp/farol-logging-required.json
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="farol-politico-api"' \
  --project=farol-politico-495210 \
  --bucket=_Default --location=global --view=_AllLogs \
  --limit=1 --format='value(logName)' > /tmp/farol-cloud-run-default-log-name.txt
test -s /tmp/farol-cloud-run-default-log-name.txt
```

Expected at the audited baseline: the only project sinks are `_Default` and
`_Required`; operational Cloud Run request/runtime logs are queryable through
`_Default`; `_Default` is 30 days; and locked `_Required` is 400 days for
mandatory audit logs. Review every returned sink and bucket rather than
assuming the count. Record only routing/setting metadata, not a sample log
body; the Cloud Run check above materializes only `logName`, never request
content, IP address, URL, or user agent. If the operational bucket or its retention differs, change the privacy
copy and its test before Web deployment. Never publish the broad claim that
“Google/Cloud logs are 30 days”: identify the 30-day operational logs and
separately disclose that mandatory audit logs follow their own longer policy.

- [ ] **Step 8: Create the cutover evidence file**

Use `apply_patch` to create `docs/operations/analytics-privacy-cutover-2026-09.md` with headings for prerequisite timestamps, backend revision, Web release, browser checks, GA4 property/stream IDs, BigQuery dataset/TTL, a rejected-candidate register, old inventories, cleanup approvals, and recovery windows. Give every rejected-candidate row fields for the complete inventory, TTL correction, resolution status, separate approval reference or owner/due date. Record public IDs and aggregate counts only.

- [ ] **Step 9: Commit the empty evidence structure if repository policy permits operational records**

```bash
git add -f docs/operations/analytics-privacy-cutover-2026-09.md
git commit -m "docs: add analytics privacy cutover record"
```

### Task 2: Deploy and prove the backend write barrier

**Files:**
- External state: GitHub Actions, Cloud Run service `farol-politico-api`, Neon PostgreSQL
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: merged backend gate, deploy workflow, production API, read-only production database access.
- Produces: a revision serving 100% traffic that ignores legacy `device_id` while IoT is false.

- [ ] **Step 1: Confirm the workflow deploys the intended commit**

```bash
gh run list --workflow 'Deploy Backend' --branch main --limit 5 \
  --repo mo-bruno/voting-advice-brazil
```

If no successful run exists for the current `main` SHA after the code plans merge, dispatch the existing chain explicitly:

```bash
gh workflow run 'Deploy Backend' --ref main \
  --repo mo-bruno/voting-advice-brazil
```

Open the successful run, set its numeric ID in `BACKEND_RUN_ID`, and record its
commit SHA. It must contain the gate commit and precede/trigger the Web workflow
for that exact SHA; do not accept two merely adjacent runs from different
commits. Extract the single `PUBLISHED_REVISION=...` marker written by
`scripts/deploy_presidential_backend.py` from this exact run without printing
the full log:

```bash
mapfile -t published_revisions < <(
  gh run view "$BACKEND_RUN_ID" --repo mo-bruno/voting-advice-brazil --log \
    | rg -o 'PUBLISHED_REVISION=[a-z0-9-]+' \
    | cut -d= -f2 \
    | LC_ALL=C sort -u
)
((${#published_revisions[@]} == 1))
published_revision="${published_revisions[0]}"
```

- [ ] **Step 2: Resolve and validate the active Cloud Run revision**

```bash
set -euo pipefail
umask 077
service_file="$(mktemp)"
revision_file="$(mktemp)"
trap 'rm -f "$service_file" "$revision_file"' EXIT

gcloud run services describe farol-politico-api \
  --project farol-politico-495210 \
  --region us-east4 \
  --format=json > "$service_file"
jq -e '.status.traffic | length == 1 and .[0].percent == 100 and
       (.[0].revisionName | type == "string" and length > 0)' \
  "$service_file" >/dev/null
active_revision="$(jq -er '.status.traffic[0].revisionName' "$service_file")"
test "$active_revision" = "$published_revision"

gcloud run revisions describe "$active_revision" \
  --project farol-politico-495210 \
  --region us-east4 \
  --format=json > "$revision_file"
jq -e --arg revision "$active_revision" '
  .metadata.name == $revision and
  ([.spec.containers[].env[]
    | select(.name == "IOT_FEATURE_ENABLED")
    | .value] == ["false"]) and
  ([.spec.containers[].env[]
    | select(.name == "POLITICIAN_FOLLOW_ENABLED")
    | .value] == ["false"])
' "$revision_file" >/dev/null
```

This validates the immutable revision actually receiving 100% of traffic,
not `.spec.template` or merely the latest-created service template, and binds
it to the revision published by the exact successful workflow run. Record the
revision name and two boolean results only. The private temporary files may
contain other environment metadata, are mode-protected by `umask 077`, and are
deleted by the trap; never print secret values or retain the full JSON.

- [ ] **Step 3: Capture aggregate pre-submit counts and isolate the synthetic identifier**

Using the protected production database connection, record only:

```sql
SELECT count(*) AS devices_before FROM devices;
SELECT count(*) AS quiz_responses_before FROM quiz_responses;
```

For a synthetic UUID created specifically for this validation, first confirm it has no rows. Do not query or print real UUIDs.

- [ ] **Step 4: Submit a synthetic legacy payload with `device_id`**

Fetch five current thesis IDs from the public quiz endpoint, build valid neutral/agree answers, and send a UUID v4 generated solely for this test to `POST /api/v1/quiz/submit`. Record HTTP status and number of returned results; do not store the UUID in the evidence file.

Expected: 200 and a normal ranking response.

- [ ] **Step 5: Prove the database did not change**

Repeat the aggregate counts and query the synthetic UUID in `devices` and `quiz_responses`.

Expected: aggregate counts unchanged; zero matching device and response rows. Repeat one submission without `device_id` and confirm the same counts.

- [ ] **Step 6: Record evidence and the rollback restriction**

Write the revision name, commit SHA, UTC timestamps, before/after aggregate counts, and response outcome. State explicitly that revisions older than this gate are no longer safe rollback targets after Task 8.

### Task 3: Deploy the site and validate all consent states in a real browser

**Files:**
- External state: Firebase Hosting and browser storage/network
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: successful backend task, working mailbox, GitHub public variables, merged Web consent implementation, and `ANALYTICS_ENABLED=false`.
- Produces: live evidence that the site and consent UI work while the operational pause prevents every Google/Firebase Analytics network request or identifier.

- [ ] **Step 1: Confirm the Web workflow used the same commit and passed the identity gate**

```bash
gh run list --workflow 'Deploy Web' --branch main --limit 5 \
  --repo mo-bruno/voting-advice-brazil
```

Record the successful run SHA and Firebase Hosting release time. It must equal the backend workflow SHA.

- [ ] **Step 2: Validate `pending` in a clean browser profile**

Open the live site with DevTools Network `Preserve log`, no extensions, and storage cleared. Before interacting:

- banner is visible and the quiz/navigation remain usable;
- `/#/privacidade` (the browser URL for named route `/privacidade`) displays the approved controller and public email;
- Network has zero requests containing `g/collect`, `google-analytics.com`, `googletagmanager.com`, or Firebase Installations;
- Network has zero requests to `fonts.googleapis.com`, `fonts.gstatic.com`, or Flutter/CanvasKit resources under `www.gstatic.com`;
- Cookies contain no `_ga` or `_ga_*`;
- IndexedDB/local storage contains no Firebase Installation ID;
- the analytics preference is pending/absent. A separate pre-existing or drawer-created Farol functional UUID may be present locally; record it only as present/absent, never its value, and confirm that no network request transmits it until a community/follow/IoT function actually uses it.

Take redacted screenshots that do not show account addresses, tokens, or unrelated browsing data.

- [ ] **Step 3: Validate explicit rejection and reload**

Tap `REJEITAR MÉTRICAS`, navigate through Home, Acompanhar, Quiz, and Community, complete a synthetic quiz, and reload.

Expected: choice restores as rejected, banner stays absent, site works, and all network/storage assertions from pending remain true.

In DevTools, inspect the real `POST /api/v1/quiz/submit` from the released site. Assert its JSON body contains only the transient quiz answers required for calculation and no `device_id`. Compare aggregate `devices` and `quiz_responses` counts immediately before/after and assert they are unchanged. Do not retain or record the answer body in evidence.

- [ ] **Step 4: Validate that acceptance is stored but cannot override the operational pause**

From `/privacidade`, accept metrics. Perform one controlled path: view quiz intro, start, answer five items, complete weighting/selection, and view results.

Expected:

- the preference displays/restores as accepted after reload;
- Firebase/tag resources still do not load;
- no custom or automatic event request is emitted;
- no Firebase Installation ID or `_ga*` cookie is created;
- all Google consent fields remain denied because the operational gate is false.

- [ ] **Step 5: Validate revocation and reacceptance**

Revoke on `/#/privacidade`, clear the Network view, navigate and trigger more product actions, then reload.

Expected: no analytics hits and state restores denied. Existing functional UUID storage is not treated as an Analytics failure. Accept again and verify the preference changes without emitting or replaying anything while the operational pause remains active. The actual enabled pipeline and reacceptance behavior are validated only after the clean destination is ready in Task 6.

- [ ] **Step 6: Validate responsive privacy UI**

Repeat the banner/page controls at 320×568, 390×844, and 1440×900, plus 200% browser text zoom. Confirm actions remain reachable, the desktop header width is preserved, the banner does not cover navigation, and the page scrolls to rights/contact.

- [ ] **Step 7: Record evidence and stop on any violation**

Record UTC times, browser version, state transitions, request counts, event names, quiz-request minimization result, aggregate database invariants, and redacted screenshots. Any pre-consent analytics/third-party font/CDN call, duplicate event, forbidden parameter, broken revocation, transmitted quiz UUID, database mutation, or false public identity blocks Tasks 4-10.

### Task 4: Create, link, harden, and deploy the clean GA4 property

**Files:**
- External state: Google Analytics Admin and Firebase project link
- Later modify: `mobile/lib/firebase_options.dart`
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: verified live consent behavior and Firebase project `farol-politico-495210`.
- Produces: a verified analytics pause, one hardened GA4 candidate, the streams provisioned by the Firebase link, and a deployed Web build using the authoritative new measurement ID while collection remains paused.

- [ ] **Step 1: Pause analytics in a new production build before relinking**

Set the public operational variable to false, then dispatch the normal backend-to-Web chain for current `main`:

```bash
gh variable set ANALYTICS_ENABLED --body 'false' \
  --repo mo-bruno/voting-advice-brazil
gh workflow run 'Deploy Backend' --ref main \
  --repo mo-bruno/voting-advice-brazil
```

Wait for both workflows and verify Backend and Web serve the same SHA. First,
read back `Cache-Control: no-cache, max-age=0, must-revalidate` for `/`,
`/index.html`, `/flutter_bootstrap.js`, `/flutter_service_worker.js`,
`/main.dart.js`, and `/version.json`. In both a fresh profile and a profile that
visited the enabled release before the pause, perform a normal reload (not a
cache-clearing hard reload), verify the served JS/service-worker artifacts and
release marker belong to the paused SHA, and prove a previously granted choice
plus a new explicit accept causes no Firebase initialization, Installation ID,
Google tag, `_ga*` cookie, or Analytics request. If the warm profile still
serves an older artifact, wait through the observed cache lifetime, reload,
and do not unlink until it proves the paused SHA. Keep the variable false
through Task 5; consent remains stored but cannot enable collection.

Record the pause-deploy and warm-profile verification times and monitor the
old measurement ID for residual events. Already-open tabs cannot be stopped by
a remote deploy; treat their traffic as a residual old-property risk and never
call the pause universal while such events continue. This does not contaminate
the not-yet-linked clean property, but it controls when the old property can be
declared quiet and retired in Task 7.

- [ ] **Step 2: Preflight permissions, old association, and recovery before unlinking**

Using read-only Firebase Management/GA Admin calls, verify the acting identity
is a Firebase Project `Owner` for `farol-politico-495210`; that is the required
role for `projects.removeAnalytics` and `projects.addGoogleAnalytics`. The
credential must be intentionally authorized for `cloud-platform` or
`firebase` for those Firebase methods, plus the official Analytics scopes
`analytics.readonly`/`analytics.edit` for property configuration and
`analytics.manage.users.readonly`/`analytics.manage.users` for access-binding
read/create. The operator must hold direct GA `Editor` access at the Analytics
**account** level to add the link and direct GA `Administrator` where access
bindings will be managed; property-only Editor and GCP IAM Editor are not
enough. Use `farol-politico-495210` as quota project where supported. A default
`gcloud auth print-access-token` result alone is not proof of either API's
scopes.

Also verify the identity that will create the GA4→BigQuery link has GA `Editor` or higher and Cloud project `Owner` (including the needed IAM/Service Usage permissions) on `farol-politico-495210`, as required by the linking workflow. Do not grant the two collaborators `Owner` or GA `Administrator`; their requested steady-state roles remain Editor. Exercise one harmless GA Admin GET, one account/property access-binding list, and one Firebase Management GET before unlinking; stop on scope/permission errors.

For the operator and every rollback-critical identity, inspect whether each GA
binding is direct, inherited from the Analytics account, or supplied only by
`Firebase linked users`. Require a direct/account-inherited GA binding that is
independent of `Firebase linked users`: unlinking removes those Firebase-linked
roles and must not take away access to old property `535804267` before
monitoring, rollback, or Trash. Record roles/origins without recording email
addresses in the repository evidence.

Record the current Firebase project-to-property association (`535804267`), account/property resource names, Web app ID, old measurement ID, registered Android app, and a redacted copy of the old Web config.

Confirm the new property will be eligible for linking. Define one recovery
state before acting: `ANALYTICS_ENABLED=false` and Firebase associated again
with property `535804267`. This restores the property association only:
`projects.addGoogleAnalytics` provisions a **new** Web stream/measurement ID
for the registered Web app and cannot restore the previous stream mapping.
After any recovery relink, inventory the newly provisioned stream, retrieve
the authoritative Firebase Web config, update the code/config, deploy it while
paused, and read back the association plus served measurement ID. Collection
must not be re-enabled until those values match. Any failure after unlinking—including
link failure or later candidate contamination—must return to this paused
association-recovery procedure and stop. A fresh candidate starts only after
repeating this preflight, then unlinks the verified old association and links
the new candidate. Do not leave Firebase unlinked, describe recovery as the
old mapping being restored, or enable collection during recovery.

- [ ] **Step 3: Create an empty clean property without a manual data stream**

In Google Analytics Admin, create a property named `Farol Político — consentimento` with reporting time zone exactly `America/Sao_Paulo` and currency exactly `BRL`. Read both values back and record them with the numeric property ID and exact UTC create time in the evidence file. Do not create a Web stream manually: linking Firebase in Step 6 provisions new streams/mappings for the apps already registered in the Firebase project, and a manual stream would create an unintended duplicate.

Load the two collaborator addresses already approved by the user into
shell-only variables `COLLABORATOR_EDITOR_1` and `COLLABORATOR_EDITOR_2` without
echoing them. Grant each exactly `roles/editor` on GCP project
`farol-politico-495210`, then retrieve the IAM policy into a temporary file and
use `jq --arg` membership checks to prove both bindings. Redirect mutation
output, remove the temporary policy, and unset both variables; record only
“2/2 Editor bindings verified,” never the addresses. Do not grant Owner or IAM
administration.

```bash
set -euo pipefail
test -n "${COLLABORATOR_EDITOR_1:?Load approved collaborator 1}"
test -n "${COLLABORATOR_EDITOR_2:?Load approved collaborator 2}"
for collaborator in "$COLLABORATOR_EDITOR_1" "$COLLABORATOR_EDITOR_2"; do
  gcloud projects add-iam-policy-binding farol-politico-495210 \
    --member="user:$collaborator" --role=roles/editor --quiet >/dev/null
done
iam_policy_file="$(mktemp)"
gcloud projects get-iam-policy farol-politico-495210 \
  --format=json > "$iam_policy_file"
for collaborator in "$COLLABORATOR_EDITOR_1" "$COLLABORATOR_EDITOR_2"; do
  jq -e --arg member "user:$collaborator" \
    'any(.bindings[];
      .role == "roles/editor" and any(.members[]; . == $member))' \
    "$iam_policy_file" >/dev/null
done
rm "$iam_policy_file"
unset COLLABORATOR_EDITOR_1 COLLABORATOR_EDITOR_2 collaborator iam_policy_file
```

Grant the same two identities the GA4 property role `Editor`, then read back
their property access bindings. Keep their addresses out of repository files
and the evidence document. GCP project IAM access does not substitute for this
Analytics access-control step, and the GA roles do not substitute for GCP IAM.

- [ ] **Step 4: Configure retention before sending production traffic**

Set event data retention to 2 months and turn off reset-on-new-activity. Record screenshots/values. Note that standard aggregate reports may follow separate GA retention behavior; do not promise their deletion at 60 days.

- [ ] **Step 5: Disable property-level advertising and enrichment features**

Confirm all of the following are off or unlinked:

- Google Signals;
- ads personalization for the property/data stream;
- user-provided data collection;
- Google Ads and other advertising product links;
- any property-level enrichment that is not required for minimal use/performance measurement.

At the Analytics account level, read and record the effective data-sharing
options, including “Google products & services,” without changing them. These
settings may affect other properties in the account, so this plan does not
silently toggle them. If an enabled option permits use beyond the purposes in
the approved notice, stop for an explicit account-wide decision or revise the
transparency before acceptance.

Do not mark stream-specific controls complete yet; the Web stream does not exist until Firebase is linked.

- [ ] **Step 6: Switch the Firebase Analytics link and enforce rollback on failure**

Reconfirm that the paused release is live and the candidate property ID is selected. Record an exact UTC link-start time. Unlink the Firebase project from old GA4 property `535804267`, then link it to `Farol Político — consentimento`. Record the completion time. If the new link does not complete or cannot be read back, execute Step 2's paused association-recovery procedure immediately and stop. Do not claim that the old stream mapping was restored or create, delete, or rename streams manually during this step.

The Firebase link enables enhanced audience integration by default. Before any
traffic, disable it and read the setting back. Inventory the automatic
`Firebase linked users` and their effective account/property roles created by
the new link, distinguish them from direct user bindings, and record only
role/origin counts in repository evidence. Recheck that Signals, advertising
personalization, user-provided data, and product links remain off after the
link. Old-property traffic from already-open browser tabs is monitored
separately; a remote deploy cannot stop those running sessions, so do not claim
the old property is universally quiet here.

- [ ] **Step 7: Inventory and harden every stream provisioned by Firebase**

Use GA4 Admin/API inventory, not visual names alone, to record every provisioned stream and its platform/app mapping. Expected:

- exactly one Web stream mapped to Firebase Web app `1:694093414765:web:4fb4604e90584d78e89a64` (the app ID/stream mapping is the identity check; do not assume its initial URL);
- the registered Android app remains represented, but `firebase_analytics_collection_enabled=false` is in the released manifest and the stream receives zero traffic;
- no iOS stream/app exists;
- no manually created or duplicate Web stream exists.

Explicitly set and read back the Web stream's canonical URL as `https://fpolitico.com.br`. In enhanced measurement, keep page views only and disable scrolls, outbound clicks, site search, video engagement, file downloads, and form interactions; the platform-generated `session_start`, `first_visit`, and `user_engagement` events are separately accepted later in Task 6. Add `fbclid`, `gclid`, `dclid`, `gbraid`, and `wbraid` to query-parameter redaction. Record an exact UTC hardening-complete time and verify redaction with a synthetic URL.

- [ ] **Step 8: Retrieve the authoritative Firebase Web config**

Use the Firebase Management API with a short-lived access token:

```bash
access_token="$(gcloud auth print-access-token)"
firebase_config="$(curl --fail --silent --show-error \
  -H "Authorization: Bearer $access_token" \
  -H 'x-goog-user-project: farol-politico-495210' \
  'https://firebase.googleapis.com/v1beta1/projects/farol-politico-495210/webApps/1:694093414765:web:4fb4604e90584d78e89a64/config')"
new_measurement_id="$(jq -er '.measurementId | select(test("^G-[A-Z0-9]+$"))' \
  <<<"$firebase_config")"
test "$new_measurement_id" != 'G-0P9XLRYVWT'
printf '%s\n' "$new_measurement_id"
unset access_token firebase_config
```

Expected: one new `G-` ID. Do not print the access token or full config.

- [ ] **Step 9: Update, merge, and deploy the authoritative measurement ID while paused**

Use `apply_patch` to replace only the old Web `measurementId` in `mobile/lib/firebase_options.dart` with the value resolved in Step 8. Add/update a static test that asserts the old ID is absent and the resolved current ID is present. Run the analytics Chrome test, full Flutter tests, analyze, and release build with real public privacy variables and `--no-web-resources-cdn` before merging this narrow cutover commit.

Wait for both Backend and Web workflows for that same merge SHA and confirm Firebase Hosting serves that release with `ANALYTICS_ENABLED=false`. In the previously warmed profile, reload normally and prove the new measurement ID/paused SHA replaced the cached old bundle; repeat the six response-header checks from Step 1. Do not validate the new property against an old cached bundle or infer that already-open tabs changed without reload.

- [ ] **Step 10: Verify the new-ID build remains unable to collect**

In fresh profiles for `pending`, `denied`, and locally `granted`, inspect the deployed bundle/config and prove it contains the new measurement ID but emits no Firebase/Analytics/Installations request, identifier, or cookie because the operational gate is false. Confirm all Google consent fields remain denied. Any request blocks Task 5.

- [ ] **Step 11: Run the early candidate contamination check**

After normal Realtime/Data API processing delay, query the candidate from its Step 3 create time through the paused-build verification. Expected: zero events. Realtime/Data API is an early rejection check, not the final completeness proof; Task 6 uses a matured BigQuery cycle and event timestamps as the authoritative cutover checkpoint. If any event already appears, do not call the property clean: keep the kill switch false; inventory the candidate property and all provisioned streams/measurement IDs, record that no BigQuery link/dataset exists yet or inventory it if one appeared, and open its mandatory rejected-candidate-register entry; unlink the candidate; execute Step 2's complete paused association-recovery procedure for old property `535804267`—including inventory of the newly provisioned rollback stream, authoritative config retrieval, code/config update, paused deployment, and served-ID readback—leave the rejected candidate disabled for separately confirmed retirement, assign the register entry's resolution owner and due date if retirement is not completed under separate confirmation, and stop. Create a fresh candidate only after repeating the full preflight.

### Task 5: Link the clean BigQuery export with 60-day TTL

**Files:**
- External state: GA4 BigQuery link and BigQuery dataset
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: numeric ID of the clean GA4 property and project `farol-politico-495210`.
- Produces: one daily-only dataset with default expiration 5,184,000 seconds and no `users_*` or `pseudonymous_users_*` user-data export; ordinary event rows still contain GA4's `user_pseudo_id`.

- [ ] **Step 1: Create the minimal GA4 BigQuery link**

In GA4 Admin, link the clean property to BigQuery project `farol-politico-495210`. Enable daily event export only. Leave streaming export and user-data export disabled. Record the selected data location and a redacted UI/configuration proof of the user-data choice.

Read the created link back through the GA4 Admin API and save the redacted response. Assert that `dailyExportEnabled` is true, `streamingExportEnabled` is false, `freshDailyExportEnabled` is false, and the stream selection contains only the intended provisioned Web stream. The Admin API `BigQueryLink` resource does not expose the user-data-export choice, so prove that separately with the recorded configuration plus the matured absence of both `users_YYYYMMDD` and `pseudonymous_users_YYYYMMDD` tables in Task 6. Neither UI evidence nor API readback alone is sufficient.

Also assert `includeAdvertisingId == false`, `exportStreams` explicitly contains exactly the generated Web stream (an empty/all-stream selection is not acceptable), and immutable `datasetLocation == 'southamerica-east1'`. If that location is unavailable or a different location is desired, stop for explicit user approval before creating the link; it cannot be changed in place later.

- [ ] **Step 2: Resolve the new dataset without guessing its ID**

After the link creates the dataset, list candidates and validate the one matching the clean property ID:

```bash
set -euo pipefail
dataset_list="$(
  bq ls --project_id=farol-politico-495210 --format=prettyjson
)"
jq -e 'type == "array"' <<<"$dataset_list" >/dev/null
mapfile -t analytics_dataset_ids < <(
  jq -er '.[].datasetReference.datasetId' <<<"$dataset_list"
)
printf '%s\n' "${analytics_dataset_ids[@]}"
unset dataset_list
```

Set `new_analytics_dataset` to the exact `analytics_` dataset for the new property, then enforce that it differs from `analytics_535804267` and matches only digits:

```bash
test "$new_analytics_dataset" != 'analytics_535804267'
[[ "$new_analytics_dataset" =~ ^analytics_[0-9]+$ ]]
```

- [ ] **Step 3: Apply default expiration and repair any table created first**

```bash
bq update --default_table_expiration 5184000 \
  "farol-politico-495210:$new_analytics_dataset"
bq show --format=prettyjson \
  "farol-politico-495210:$new_analytics_dataset" \
  | jq -e '(.defaultTableExpirationMs | tonumber) == 5184000000'
```

Expected: the dataset default is exactly 5,184,000,000 milliseconds.

The dataset default is not retroactive. Immediately inventory every table that may have appeared between link creation and the default update. For each existing table, read `creationTime` and `expirationTime`; if expiration is absent or later than `creationTime + 5,184,000,000 ms`, calculate the remaining seconds to that exact deadline and update the table explicitly:

```bash
set -euo pipefail
umask 077
table_list="$(
  bq ls --max_results=10000 --format=prettyjson \
    "farol-politico-495210:$new_analytics_dataset"
)"
jq -e 'type == "array"' <<<"$table_list" >/dev/null

mapfile -t new_table_ids < <(
  jq -er '.[].tableReference.tableId' <<<"$table_list"
)
unset table_list
access_token="$(gcloud auth print-access-token)"
metadata=''
trap 'rm -f "${metadata:-}"' EXIT
for table_id in "${new_table_ids[@]}"; do
  [[ "$table_id" =~ ^events_[0-9]{8}$ ]] || {
    printf 'Unexpected new analytics table: %s\n' "$table_id" >&2
    exit 1
  }
  metadata="$(mktemp)"
  bq show --format=prettyjson \
    "farol-politico-495210:$new_analytics_dataset.$table_id" > "$metadata"
  jq -e \
    --arg dataset "$new_analytics_dataset" \
    --arg table "$table_id" \
    '.tableReference.projectId == "farol-politico-495210" and
     .tableReference.datasetId == $dataset and
     .tableReference.tableId == $table' \
    "$metadata" >/dev/null
  created_ms="$(jq -er '.creationTime | tonumber' "$metadata")"
  expiry_ms="$(jq -er '.expirationTime // "0" | tonumber' "$metadata")"
  deadline_ms="$((created_ms + 5184000000))"
  if ((expiry_ms == 0 || expiry_ms > deadline_ms)); then
    ((deadline_ms > $(date +%s%3N))) || {
      printf 'Expiration deadline already passed: %s\n' "$table_id" >&2
      exit 1
    }
    curl --fail --silent --show-error --request PATCH \
      -H "Authorization: Bearer $access_token" \
      -H 'x-goog-user-project: farol-politico-495210' \
      -H 'Content-Type: application/json' \
      --data "{\"expirationTime\":\"$deadline_ms\"}" \
      "https://bigquery.googleapis.com/bigquery/v2/projects/farol-politico-495210/datasets/$new_analytics_dataset/tables/$table_id" \
      >/dev/null
  fi
  rm -f "$metadata"
  metadata=''
done
unset access_token
trap - EXIT
```

The REST `tables.patch` call uses the absolute millisecond deadline, avoiding drift from a relative client-side duration. Re-read every table and programmatically assert a populated expiration no later than its creation time plus 60 days. Do not print the access token or response bodies. Stop on any table that cannot be brought into bounds.

- [ ] **Step 4: Verify the paused candidate is ready for controlled traffic**

Read back the GA4 BigQuery link and dataset settings a second time. Confirm daily-only Web-stream export, advertising IDs off, `southamerica-east1`, exact 60-day default expiration, and no `events_intraday_*`, `users_*`, or `pseudonymous_users_*` table. If any table already exists while the operational kill switch is false, inventory it immediately and treat any event row as candidate contamination.

- [ ] **Step 5: Stop if the link or dataset is not minimal**

Any unexpected row while paused, streaming table, user-data table, advertising-ID export, wrong/implicit stream selection, wrong location, or missing expiration blocks unpausing. Correct settings or reject the candidate before proceeding.

If the candidate must be rejected after its BigQuery link exists, use this one recovery sequence: deploy and verify `ANALYTICS_ENABLED=false`; inventory the candidate property, every stream/measurement ID, exact BigQueryLink, dataset, every table, current TTL, and recovery settings into its mandatory rejected-candidate-register entry; correct a missing or excessive dataset/table expiration to the approved 60-day bound immediately; delete only the candidate property's exact BigQueryLink and read back its absence; mark the property and dataset for separately confirmed retirement, or assign a concrete owner and due date for obtaining those confirmations; unlink Firebase from the candidate; associate Firebase again with old property `535804267`; inventory the newly provisioned rollback Web stream/measurement ID; retrieve the authoritative Firebase config; update and deploy matching code while still paused; read back the property association and served measurement ID; then stop. Never call this restoration of the old stream mapping, reactivate against a mismatched ID, orphan an active export, leave rejected tables unbounded, or silently delete a rejected candidate dataset.

### Task 6: Accept the clean analytics cutover

**Files:**
- External state: new GA4 DebugView/Realtime and daily BigQuery table
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: Tasks 3-5 evidence.
- Produces: explicit acceptance that only consented, minimized, nonduplicated events enter the clean property.

- [ ] **Step 1: Enable analytics only after the hardened destination is ready**

Set the operational variable to true and dispatch the normal deployment chain:

```bash
gh variable set ANALYTICS_ENABLED --body 'true' \
  --repo mo-bruno/voting-advice-brazil
gh workflow run 'Deploy Backend' --ref main \
  --repo mo-bruno/voting-advice-brazil
```

Record the exact UTC unpause time. Wait for Backend and Web to serve the same cutover SHA and verify the deployed build contains `ANALYTICS_ENABLED=true` and the new measurement ID. Reload both a fresh and the previously warmed profile normally and prove both receive that SHA under the revalidation headers; a still-open paused tab may remain safely paused and is not evidence of failure. If any later check fails, immediately set the variable back to false, redeploy the pause, and stop.

- [ ] **Step 2: Validate all consent transitions against the new stream**

Use fresh profiles for `pending` and `denied`: both must have zero Analytics/Installations network or storage artifacts. In a separate profile, grant and then revoke: accepted traffic must go only to the new `G-` ID and each controlled custom event must arrive once with only allowed counts/durations; after revocation, all new Analytics/Installations hits cease and remain absent after reload. Existing `_ga*` cookies/FID may remain locally after a prior grant and must be recorded as such rather than misreported as deleted; while denied they must not generate traffic. Reacceptance sends only new actions and never replays discarded history.

In DevTools/Tag Assistant verify `analytics_storage` changes only after acceptance while `ad_storage`, `ad_user_data`, and `ad_personalization` stay denied. Confirm the Web stream receives accepted events and the registered Android stream receives zero.

- [ ] **Step 3: Mature one BigQuery daily cycle before the authoritative checkpoint**

After the first daily table appears, run an early query of aggregate event names, counts, consent fields, parameter keys, and minimum/maximum `event_timestamp` only. Do not call it complete yet: GA4 can update daily exports with late events for up to three days. Wait until at least 72 hours after the end of that event date in the property's `America/Sao_Paulo` reporting time zone, then rerun the same query and use that matured result as the authoritative checkpoint. Confirm:

- every row timestamp is at or after both the recorded hardening-complete and Task 6 unpause times;
- table expiration is populated and no later than creation plus 60 days;
- no `events_intraday_*`, `users_*`, or `pseudonymous_users_*` table exists;
- every accepted row has `privacy_info.analytics_storage = 'Yes'`;
- `privacy_info.ads_storage = 'No'` and `privacy_info.uses_transient_token != 'Yes'`;
- there is no null consent state, forbidden parameter, political value, unexpected automatic event, or immediate duplicate.

The export schema does not expose `ad_user_data` or `ad_personalization`; their evidence remains the browser request/Tag Assistant record from Step 2. If an event predates hardening/unpause or otherwise violates the rules, execute Task 5 Step 5's complete candidate-rejection sequence, including the rejected-candidate register, bounded TTL correction, BigQueryLink removal/readback, complete candidate-dataset inventory, and confirmed retirement or owner/due-date disposition, then stop. Repeat Tasks 4-6 with a fresh property only after the preflight. Do not print pseudonymous IDs.

- [ ] **Step 4: Reconcile browser, GA4, and BigQuery event names**

For one controlled accepted session, compare the expected generic sequence with GA4 and BigQuery. Treat the application allowlist and GA automatic events as two separate closed sets.

The 23 allowed custom names are exactly:

```text
quiz_intro_viewed
quiz_started
quiz_restarted
thesis_viewed
thesis_answered
thesis_skipped
quiz_completed
weighting_started
weight_added
weight_removed
weighting_completed
party_selection_viewed
party_toggled
party_selection_completed
results_viewed
comparison_opened
comparison_candidate_added
candidate_positions_viewed
follow_waitlist_viewed
follow_waitlist_prompt_viewed
follow_waitlist_cta_clicked
follow_waitlist_registered
follow_waitlist_failed
```

The only accepted GA-generated event names are `page_view`, `session_start`, `first_visit`, and `user_engagement`; these are not counted among the 23 product events. If the platform emits any other automatic/enhanced-measurement name, either document and explicitly approve a necessary one or disable its source and observe another clean daily cycle. Record aggregate counts only, never pseudonymous identifiers.

- [ ] **Step 5: Confirm rejected traffic is absent**

Run a separate rejected-consent browser session through the quiz and follow-interest page. Confirm product/API behavior works, the database interest action is reflected if chosen, and no corresponding analytics custom events appear.

- [ ] **Step 6: Confirm GA4 settings one final time**

Recheck 2-month retention, reset off, signals/ads/user-provided data off, and the complete redaction list. Confirm only the intended Web stream is selected for BigQuery and receives traffic; the Firebase-provisioned Android mapping may remain registered only with collection disabled and zero traffic.

- [ ] **Step 7: Sign the cutover checkpoint in the evidence file**

Record the UTC acceptance time, the event date, the 72-hour maturity boundary, both early/final query timestamps, and a concise pass/fail row for each requirement. Do not proceed if any row fails or the maturity boundary has not elapsed.

### Task 7: Inventory old analytics and retire only the old GA4 property

**Files:**
- External state: old GA4 property `535804267`, old BigQuery dataset `analytics_535804267`
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: accepted clean cutover.
- Produces: a stopped old export, a precise reviewed old-data inventory, and, after a dedicated confirmation, old property `535804267` in Trash.

- [ ] **Step 1: Prove old collection stopped and stop its BigQuery export**

Compare the old property's latest event timestamp against the Firebase unlink/new-link time and confirm no post-cutover events arrived. Inventory the exact GA4 BigQuery link from property `535804267` to `analytics_535804267`, remove/disable that old export link only, and read back that it no longer exports. Do not touch the accepted clean link.

Record the last old event timestamp and convert its `event_date` boundary using
the property's `America/Sao_Paulo` time zone, the old-link removal time, and the
latest old table modification time. Compute the quiet-window end as the
maximum of:

- the end of the last event's local calendar date plus 72 hours;
- old-link removal plus 72 hours;
- latest table modification plus 72 hours.

Wait through that exact maximum, then recheck that the old property has no
newer event and the old dataset has no new or modified table. Any event,
link-state change, or table modification restarts the calculation from all
three current values; a timestamp early within the last event date never
shortens GA4's full late-update window.

- [ ] **Step 2: Inventory the old dataset and recovery settings**

```bash
set -euo pipefail
test -n "${FAROL_EVIDENCE_DIR:?Set a persistent operator evidence directory}"
test -d "$FAROL_EVIDENCE_DIR"
umask 077
inventory_dir="$FAROL_EVIDENCE_DIR/bq-old-inventory-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$inventory_dir"
old_table_ids_file="$inventory_dir/table-ids.txt"

# Validate the recovery setting without ever materializing the dataset ACL.
bq show --format=prettyjson \
  farol-politico-495210:analytics_535804267 \
  | jq -e '.maxTimeTravelHours == "168" or .maxTimeTravelHours == 168'

table_list="$(
  bq ls --max_results=10000 --format=prettyjson \
    farol-politico-495210:analytics_535804267
)"
jq -e 'type == "array"' <<<"$table_list" >/dev/null
jq -er '.[].tableReference.tableId' <<<"$table_list" \
  | LC_ALL=C sort > "$old_table_ids_file"
unset table_list
chmod 600 "$old_table_ids_file"
wc -l "$old_table_ids_file"
```

Record dataset ID, location, max time travel, total tables, counts by prefix (`events_`, `events_intraday_`, `users_`, `pseudonymous_users_`), latest table date/modification time, and the completed 72-hour quiet-window boundary. Do not copy row content.

- [ ] **Step 3: Validate every prospective table target**

```bash
set -euo pipefail
test -n "${inventory_dir:?Reuse the protected inventory directory from Step 2}"
old_table_ids_file="$inventory_dir/table-ids.txt"
test -f "$old_table_ids_file"
while IFS= read -r table_id; do
  [[ "$table_id" =~ ^(events(_intraday)?|users|pseudonymous_users)_[0-9]{8}$ ]] || {
    printf 'Unexpected table id: %s\n' "$table_id" >&2
    exit 1
  }
done < "$old_table_ids_file"
```

Expected: all IDs match the narrow known patterns. If any unexpected table exists, stop and review it rather than broadening the regex automatically.

After every ID passes, build a protected, durable metadata-only manifest for
freshness comparison and recovery planning. `FAROL_EVIDENCE_DIR` must be an
existing backed-up operator directory, not `/tmp`; record the generated
inventory-directory basename in the cutover evidence:

```bash
set -euo pipefail
test -n "${inventory_dir:?Reuse the protected inventory directory from Step 2}"
test -d "$inventory_dir"
umask 077
old_table_ids_file="$inventory_dir/table-ids.txt"
test -f "$old_table_ids_file"
: > "$inventory_dir/table-metadata.ndjson"
table_file=''
policy_file=''
trap 'rm -f "${table_file:-}" "${policy_file:-}"' EXIT
while IFS= read -r table_id; do
  table_file="$(mktemp)"
  policy_file="$(mktemp)"
  bq show --format=prettyjson \
    "farol-politico-495210:analytics_535804267.$table_id" > "$table_file"
  bq ls --row_access_policies --format=prettyjson \
    "farol-politico-495210:analytics_535804267.$table_id" > "$policy_file"
  jq -e '
    .type == "TABLE" and
    (.timePartitioning // null) == null and
    (.rangePartitioning // null) == null and
    (.clustering // null) == null and
    (.encryptionConfiguration // null) == null and
    ((.resourceTags // {}) | length == 0) and
    ([.schema.fields[]? | .. | objects | .policyTags? // empty] | length == 0)
  ' "$table_file" >/dev/null
  jq -e 'length == 0' "$policy_file" >/dev/null
  jq -c '{
    tableReference,
    type,
    creationTime,
    lastModifiedTime,
    expirationTime: (.expirationTime // null),
    requirePartitionFilter: (.requirePartitionFilter // false),
    timePartitioning: (.timePartitioning // null),
    rangePartitioning: (.rangePartitioning // null),
    clustering: (.clustering // null),
    encryptionConfiguration: (.encryptionConfiguration // null),
    resourceTags: (.resourceTags // {}),
    labels: (.labels // {}),
    description: (.description // null),
    schema
  }' "$table_file" >> "$inventory_dir/table-metadata.ndjson"
  rm -f "$table_file" "$policy_file"
  table_file=''
  policy_file=''
done < "$old_table_ids_file"
chmod 600 "$inventory_dir/table-metadata.ndjson"
sha256sum "$inventory_dir/table-ids.txt" \
  "$inventory_dir/table-metadata.ndjson"
```

Expected: the standard GA export tables have no partitioning/clustering,
row/column access policy, resource tag, or customer-managed encryption override
that the generic restore could fail to reproduce safely. Every object must be a
base `TABLE`; views, materialized views, snapshots, clones, models, or external
tables stop the operation. If any assertion fails, stop before confirmation and
write a feature-specific restore procedure; do not discard that metadata or
silently broaden this generic path. The protected manifest contains schema and
configuration metadata but no row data or pseudonymous identifiers. Record
only its protected path basename, checksums, and aggregate extrema in the
repository evidence; never copy the manifest contents into Git.

- [ ] **Step 4: Inventory every current old-property stream and request confirmation**

Immediately before asking, query property `535804267` again and inventory every
current data stream, its stream ID, platform/app mapping, and measurement ID.
This must include any additional Web stream provisioned by a recovery relink;
`G-0P9XLRYVWT` is the original known ID, not an assumption that it is still the
only ID. Reconcile the inventory to the Firebase recovery records and stop on
any unexplained stream.

Present the accepted clean-cycle evidence, exact old property ID `535804267`,
the complete current stream/measurement-ID inventory, last event time, and
Google's stated Trash recovery/deletion behavior. Obtain explicit confirmation
to move only that old property—with all listed streams—to Trash. Do not bundle
approval for Neon rows or BigQuery tables, and do not interpret prior approval
of the design as this destructive confirmation.

- [ ] **Step 5: Move only the confirmed old GA4 property to Trash**

Immediately before acting, re-read the selected property ID and repeat the
complete stream/measurement-ID inventory; require an exact match with what the
user confirmed. In GA4 Admin, move property `535804267` to Trash. Record the
exact UTC trash time and Google's displayed recovery/deletion deadline. Do not
delete the Analytics account, clean property, data streams, or either BigQuery
dataset.

### Task 8: Remove historical quiz answers in a verified Neon transaction

**Files:**
- External state: Neon PostgreSQL production database
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: active backend gate and verified Neon backup/recovery status; a fresh Neon-specific confirmation is obtained only after the dry-run.
- Produces: zero rows in `quiz_responses` and `devices`, with all out-of-scope tables unchanged.

- [ ] **Step 1: Verify Neon recovery before opening the deletion transaction**

In Neon, record the current branch, backup/PITR retention, earliest recoverable time, and a recovery procedure tested or documented for this exact branch. If recovery status is unavailable, stop.

- [ ] **Step 2: Recheck schema dependencies and writers**

Query PostgreSQL catalogs to confirm `quiz_responses.device_id -> devices.id` is the only foreign key that references `devices`, that no other table references `devices`, and that the separate `quiz_responses.thesis_id -> theses.id` relationship points from the rows being deleted to preserved parent data. Inventory every FK action in both directions, all non-internal triggers, event triggers relevant to these tables, and rewrite rules on `devices`/`quiz_responses`; prove that deleting the two targets cannot cascade, trigger, or rewrite a mutation into any preservation table. Inspect the deployed commit to confirm the gated quiz repository remains the only production writer of `devices`. Any new dependent table/writer, user trigger/rule, or cascade effect outside the two exact targets stops the operation.

- [ ] **Step 3: Record aggregate before-counts for every preservation sentinel**

Within a read-only transaction, record counts for:

```text
devices
quiz_responses
politician_follow_interests
followed_actors
iot_device_links
iot_pairing_sessions
iot_device_events
source_sync_runs
source_sync_cursors
posts
comments
comment_admission_locks
post_votes
post_reports
moderation_log
parties
candidates
themes
theses
candidate_positions
government_plans
political_actors
official_evidence
```

These are the table names in `backend/app/infrastructure/database/models.py` at the audited base. Re-resolve them from PostgreSQL immediately before cleanup and stop if the deployed schema differs. Do not print UUIDs or content.

- [ ] **Step 4: Dry-run the exact locked transaction and roll it back**

Connect through a protected `PGSERVICE`/passfile or equivalent secret channel. Never place `DATABASE_URL`, passwords, row IDs, or row content in the command line, shell history, or evidence. Invoke `psql --no-psqlrc` with `ON_ERROR_STOP`. The catalog precheck must already have proved that no external FK/trigger dependency requires a wider lock; the transaction locks only the two deletion targets so unrelated read/write paths remain available.

```sql

\set ON_ERROR_STOP on
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '2min';

LOCK TABLE devices, quiz_responses IN ACCESS EXCLUSIVE MODE;

CREATE TEMP TABLE preservation_counts_before (
  table_name text PRIMARY KEY,
  row_count bigint NOT NULL
) ON COMMIT DROP;

DO $audit$
DECLARE
  table_name text;
  current_count bigint;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'politician_follow_interests', 'followed_actors', 'iot_device_links',
    'iot_pairing_sessions', 'iot_device_events', 'source_sync_runs',
    'source_sync_cursors', 'posts', 'comments', 'comment_admission_locks',
    'post_votes', 'post_reports', 'moderation_log', 'parties', 'candidates',
    'themes', 'theses', 'candidate_positions', 'government_plans',
    'political_actors', 'official_evidence'
  ] LOOP
    EXECUTE format('SELECT count(*) FROM %I', table_name)
      INTO current_count;
    INSERT INTO preservation_counts_before VALUES (table_name, current_count);
  END LOOP;
END
$audit$;

DELETE FROM quiz_responses;
DELETE FROM devices;

DO $assertions$
DECLARE
  saved record;
  current_count bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM quiz_responses) OR EXISTS (SELECT 1 FROM devices) THEN
    RAISE EXCEPTION 'quiz cleanup targets are not empty';
  END IF;

  FOR saved IN SELECT * FROM preservation_counts_before LOOP
    EXECUTE format('SELECT count(*) FROM %I', saved.table_name)
      INTO current_count;
    IF current_count <> saved.row_count THEN
      RAISE EXCEPTION 'preservation sentinel % changed', saved.table_name;
    END IF;
  END LOOP;
END
$assertions$;

SELECT count(*) AS quiz_responses_after FROM quiz_responses;
SELECT count(*) AS devices_after FROM devices;
TABLE preservation_counts_before ORDER BY table_name;
ROLLBACK;
```

Expected: the script exits successfully, both inside-transaction counts are zero, the transaction-local before/after assertions pass for every sentinel, and a separate post-rollback read returns both targets to their Step 3 values. The printed temp table contains aggregate counts only and becomes the baseline produced by that exact run. Any SQL error, lock timeout, unexpected table, or assertion failure aborts this task.

- [ ] **Step 5: Request the Neon-specific destructive confirmation**

Present the active backend revision, PITR/recovery window, dependency/writer checks, aggregate target counts, complete sentinel list, and successful rolled-back transaction. Ask for explicit confirmation to delete all rows from exactly `quiz_responses` and `devices`. Approval for GA4 Trash or BigQuery is not approval for this database commit.

- [ ] **Step 6: Execute the same verified transaction with `COMMIT`**

After that fresh confirmation, rerun the exact Step 4 script unchanged except for replacing the final `ROLLBACK` with `COMMIT`. Keep `\set ON_ERROR_STOP on`, both timeouts, the two target-table exclusive locks, the target-zero assertion, every preservation-count assertion, and the printed commit-run temp baseline. Do not hand-edit table names between dry-run and commit. If the command exits nonzero or the client disconnects before a confirmed commit, treat the result as unknown and inspect database state before retrying.

- [ ] **Step 7: Run postchecks in a new database session**

Open a new read-only connection and assert `devices=0` and `quiz_responses=0`. Confirm every preservation table still exists and is queryable, but do not compare mutable live tables with stale Step 3 counts after locks have been released; the commit transaction's own printed baseline and assertions are the non-mutation proof. Record aggregate results only. A target mismatch or missing preservation table starts incident/recovery handling; do not continue to BigQuery deletion.

- [ ] **Step 8: Prove the gate still prevents repopulation**

Repeat Task 2's synthetic legacy submission with and without UUID, then confirm `devices=0` and `quiz_responses=0`. Smoke-test the independent interest/community paths without retaining synthetic content; do not require their mutable production counts to equal a stale snapshot.

- [ ] **Step 9: Record deletion/recovery evidence**

Record UTC transaction begin/commit times, deleted aggregate counts returned by PostgreSQL, zero postchecks, active revision, and Neon recovery window. Never record row content or identifiers.

### Task 9: Delete only the inventoried old BigQuery tables

**Files:**
- External state: old BigQuery dataset `analytics_535804267`
- Modify evidence: `docs/operations/analytics-privacy-cutover-2026-09.md`

**Interfaces:**
- Consumes: explicit table-ID file validated in Task 7; a fresh BigQuery-specific confirmation is obtained after the final inventory.
- Produces: an empty old analytics dataset while leaving the project and clean dataset intact.

- [ ] **Step 1: Recreate and compare the inventory immediately before deletion**

Set `FAROL_BQ_INVENTORY_DIR` to the protected Task 7 inventory directory and
require its two checksum-verified files. Run the Task 7 inventory logic again
to new mode-600 working files, including the same metadata-feature and row
policy assertions, then use `cmp` against
`$FAROL_BQ_INVENTORY_DIR/table-ids.txt` and
`$FAROL_BQ_INVENTORY_DIR/table-metadata.ndjson`. Revalidate every ID before
using it in `bq show`, and reconfirm that the old GA4 BigQuery link is absent.
If the list, schema/configuration metadata, or any modification time changed,
do not delete: restart the 72-hour quiet window, create a new protected
inventory directory only after revalidation, and re-present the new exact
list/count. Reconfirm the project, old dataset ID, location, table prefixes,
clean dataset ID, current time-travel window, and that the protected baseline
contains no row data.

Use this complete fresh comparison rather than reusing a prior process's
variables or metadata:

```bash
set -euo pipefail
test -n "${FAROL_BQ_INVENTORY_DIR:?Set the protected Task 7 inventory directory}"
test -d "$FAROL_BQ_INVENTORY_DIR"
umask 077
fresh_ids="$(mktemp)"
fresh_metadata="$(mktemp)"
table_file=''
policy_file=''
trap 'rm -f "$fresh_ids" "$fresh_metadata" "${table_file:-}" "${policy_file:-}"' EXIT

bq ls --max_results=10000 --format=prettyjson \
  farol-politico-495210:analytics_535804267 \
  | jq -er '.[].tableReference.tableId' \
  | LC_ALL=C sort > "$fresh_ids"

while IFS= read -r table_id; do
  [[ "$table_id" =~ ^(events(_intraday)?|users|pseudonymous_users)_[0-9]{8}$ ]] || {
    printf 'Unexpected table id: %s\n' "$table_id" >&2
    exit 1
  }
  table_file="$(mktemp)"
  policy_file="$(mktemp)"
  bq show --format=prettyjson \
    "farol-politico-495210:analytics_535804267.$table_id" > "$table_file"
  bq ls --row_access_policies --format=prettyjson \
    "farol-politico-495210:analytics_535804267.$table_id" > "$policy_file"
  jq -e '
    .type == "TABLE" and
    (.timePartitioning // null) == null and
    (.rangePartitioning // null) == null and
    (.clustering // null) == null and
    (.encryptionConfiguration // null) == null and
    ((.resourceTags // {}) | length == 0) and
    ([.schema.fields[]? | .. | objects | .policyTags? // empty] | length == 0)
  ' "$table_file" >/dev/null
  jq -e 'length == 0' "$policy_file" >/dev/null
  jq -c '{
    tableReference,
    type,
    creationTime,
    lastModifiedTime,
    expirationTime: (.expirationTime // null),
    requirePartitionFilter: (.requirePartitionFilter // false),
    timePartitioning: (.timePartitioning // null),
    rangePartitioning: (.rangePartitioning // null),
    clustering: (.clustering // null),
    encryptionConfiguration: (.encryptionConfiguration // null),
    resourceTags: (.resourceTags // {}),
    labels: (.labels // {}),
    description: (.description // null),
    schema
  }' "$table_file" >> "$fresh_metadata"
  rm -f "$table_file" "$policy_file"
  table_file=''
  policy_file=''
done < "$fresh_ids"

cmp --silent "$FAROL_BQ_INVENTORY_DIR/table-ids.txt" "$fresh_ids"
cmp --silent "$FAROL_BQ_INVENTORY_DIR/table-metadata.ndjson" "$fresh_metadata"
sha256sum "$fresh_ids" "$fresh_metadata"
rm -f "$fresh_ids" "$fresh_metadata"
trap - EXIT
```

Then perform the GA Admin API readback and require that property `535804267`
has no BigQueryLink before asking for deletion confirmation. The comparison
command must finish successfully in the same session; any `bq`, `jq`, policy,
or `cmp` failure stops the operation.

- [ ] **Step 2: Request the BigQuery-specific destructive confirmation**

Present the exact project `farol-politico-495210`, old dataset `analytics_535804267`, validated table count/names, time-travel behavior, and evidence that the clean dataset differs and is healthy. Ask for explicit confirmation to delete exactly those listed tables. Approval for the Neon transaction or property Trash is not approval for this deletion.

- [ ] **Step 3: Prevalidate every target, then delete fail-closed with a durable local log**

Before the first `bq rm`, confirm the acting identity has
`roles/bigquery.user` (or the equivalent `bigquery.jobs.create`) on the project
and `roles/bigquery.dataEditor` on the old dataset, including
`bigquery.tables.get`, `bigquery.tables.getData`, `bigquery.tables.create`, and
`bigquery.tables.update`. If any source table has or had row-access policies,
also require `bigquery.rowAccessPolicies.overrideTimeTravelRestrictions`.
Record the effective-role/permission check in evidence; a successful delete
permission check alone is not proof that restoration is authorized.

Use this narrow command only after validation, restore-permission verification,
and confirmation:

```bash
set -euo pipefail

old_project='farol-politico-495210'
old_dataset='analytics_535804267'
test -n "${FAROL_EVIDENCE_DIR:?Set a persistent operator evidence directory}"
test -d "$FAROL_EVIDENCE_DIR"
test -n "${FAROL_BQ_INVENTORY_DIR:?Set the protected Task 7 inventory directory}"
test -d "$FAROL_BQ_INVENTORY_DIR"
umask 077
mapfile -t table_ids < "$FAROL_BQ_INVENTORY_DIR/table-ids.txt"
((${#table_ids[@]} > 0))

snapshot_ms="$(date -u +%s000)"
[[ "$snapshot_ms" =~ ^[0-9]{13}$ ]]
snapshot_file="$FAROL_EVIDENCE_DIR/bq-restore-snapshot-${snapshot_ms}.txt"
printf '%s\n' "$snapshot_ms" > "$snapshot_file"
chmod 600 "$snapshot_file"

metadata=''
trap 'rm -f "${metadata:-}"' EXIT
for table_id in "${table_ids[@]}"; do
  [[ "$table_id" =~ ^(events(_intraday)?|users|pseudonymous_users)_[0-9]{8}$ ]] || {
    printf 'Unexpected table id: %s\n' "$table_id" >&2
    exit 1
  }
  metadata="$(mktemp)"
  bq show --format=prettyjson \
    "$old_project:$old_dataset.$table_id" > "$metadata"
  jq -e \
    --arg project "$old_project" \
    --arg dataset "$old_dataset" \
    --arg table "$table_id" \
    '.tableReference.projectId == $project and
     .tableReference.datasetId == $dataset and
     .tableReference.tableId == $table' \
    "$metadata" >/dev/null
  rm -f "$metadata"
  metadata=''
done

deleted_log="$FAROL_EVIDENCE_DIR/bq-deleted-$(date -u +%Y%m%dT%H%M%SZ).txt"
: > "$deleted_log"
chmod 600 "$deleted_log"
printf 'Deletion log: %s\n' "$deleted_log"
for table_id in "${table_ids[@]}"; do
  bq rm --force --table "$old_project:$old_dataset.$table_id"
  printf '%s\n' "$table_id" >> "$deleted_log"
done

bq ls --max_results=10000 --format=prettyjson \
  "$old_project:$old_dataset" \
  | jq -e 'length == 0' >/dev/null
sha256sum "$deleted_log"
trap - EXIT
```

There is no wildcard and no `-r` dataset removal. `FAROL_EVIDENCE_DIR` must be an existing backed-up/persistent operator directory, not `/tmp`; record the log basename and SHA-256 in the cutover report. Because `set -euo pipefail` stops at the first failed deletion, preserve `deleted_log` if the run partially succeeds, re-inventory authoritative state, and present the remainder before any retry. Never reuse the original full list after a partial failure.

The recorded `snapshot_ms` is the common last-known-good instant immediately
before deletion. During the dataset's self-service time-travel window, restore
one exact deleted table only into a same-region quarantine dataset with a
24-hour default TTL and minimal access. Before copying data, create that empty
dataset, replace its default project reader/writer ACL entries with only the
approved recovery operator(s), and read back the full dataset ACL plus inherited
project IAM. Stop if any unapproved principal can read table data. Keep the
operator address in a shell variable and out of repository evidence. Then use
this executable form:

```bash
set -euo pipefail
umask 077
table_id='TABLE'
snapshot_ms='SNAPSHOT_MS'
[[ "$table_id" =~ ^(events(_intraday)?|users|pseudonymous_users)_[0-9]{8}$ ]]
[[ "$snapshot_ms" =~ ^[0-9]{13}$ ]]
test -n "${FAROL_RECOVERY_OPERATOR_EMAIL:?Set the approved recovery operator}"
recovery_dataset="analytics_recovery_${snapshot_ms}"
recovered_table_id="${table_id}_recovered_${snapshot_ms}"
acl_file=''
recovered_file=''
trap 'rm -f "${acl_file:-}" "${recovered_file:-}"' EXIT

bq --location=southamerica-east1 mk --dataset \
  --default_table_expiration=86400 \
  "farol-politico-495210:${recovery_dataset}"

# Before continuing, narrow the new dataset ACL through the BigQuery API or
# console to FAROL_RECOVERY_OPERATOR_EMAIL only, then read it back. Require no
# projectReaders/projectWriters, allUsers, allAuthenticatedUsers, domain, or
# unapproved group entry and reconcile inherited project-level BigQuery roles.
acl_file="$(mktemp)"
bq show --dataset_view=FULL --format=prettyjson \
  "farol-politico-495210:${recovery_dataset}" > "$acl_file"
jq -e --arg operator "$FAROL_RECOVERY_OPERATOR_EMAIL" '
  .location == "southamerica-east1" and
  ((.defaultTableExpirationMs | tonumber) == 86400000) and
  (.access | length >= 1) and
  all(.access[];
    (.userByEmail // "") == $operator and
    (.role == "OWNER" or .role == "WRITER" or .role == "READER"))
' "$acl_file" >/dev/null
test "${FAROL_RECOVERY_PROJECT_IAM_VERIFIED:-}" = 'yes'

# Submit a copy job whose destination TTL is part of the same atomic job.
# Never replace this with `bq cp` followed by `bq update`: a crash between those
# commands can leave a recovered table without the promised bound.
copy_job_id="farol_restore_${snapshot_ms}_$(date -u +%s)"
destination_expiration="$(date -u -d '+24 hours' '+%Y-%m-%dT%H:%M:%SZ')"
source_table_id="${table_id}@${snapshot_ms}"
access_token="$(gcloud auth print-access-token)"
copy_request="$(
  jq -n \
    --arg job "$copy_job_id" \
    --arg source "$source_table_id" \
    --arg dataset "$recovery_dataset" \
    --arg destination "$recovered_table_id" \
    --arg expires "$destination_expiration" \
    '{
      jobReference: {
        projectId: "farol-politico-495210",
        jobId: $job,
        location: "southamerica-east1"
      },
      configuration: {
        copy: {
          sourceTable: {
            projectId: "farol-politico-495210",
            datasetId: "analytics_535804267",
            tableId: $source
          },
          destinationTable: {
            projectId: "farol-politico-495210",
            datasetId: $dataset,
            tableId: $destination
          },
          createDisposition: "CREATE_IF_NEEDED",
          writeDisposition: "WRITE_EMPTY",
          operationType: "COPY",
          destinationExpirationTime: $expires
        }
      }
    }'
)"
copy_response="$(
  curl --fail --silent --show-error --request POST \
    -H "Authorization: Bearer $access_token" \
    -H 'x-goog-user-project: farol-politico-495210' \
    -H 'Content-Type: application/json' \
    --data "$copy_request" \
    'https://bigquery.googleapis.com/bigquery/v2/projects/farol-politico-495210/jobs'
)"
jq -e --arg job "$copy_job_id" '
  .jobReference.jobId == $job and
  (.status.errorResult // null) == null
' <<<"$copy_response" >/dev/null

while :; do
  copy_response="$(
    curl --fail --silent --show-error \
      -H "Authorization: Bearer $access_token" \
      -H 'x-goog-user-project: farol-politico-495210' \
      "https://bigquery.googleapis.com/bigquery/v2/projects/farol-politico-495210/jobs/$copy_job_id?location=southamerica-east1"
  )"
  state="$(jq -er '.status.state' <<<"$copy_response")"
  [[ "$state" == 'DONE' ]] && break
  sleep 2
done
jq -e '
  .status.state == "DONE" and
  (.status.errorResult // null) == null and
  ((.status.errors // []) | length == 0)
' <<<"$copy_response" >/dev/null
unset access_token copy_request copy_response

recovered_file="$(mktemp)"
bq show --format=prettyjson \
  "farol-politico-495210:${recovery_dataset}.${recovered_table_id}" \
  > "$recovered_file"
deadline_ms="$(( $(date -u -d "$destination_expiration" +%s) * 1000 ))"
jq -e \
  --arg dataset "$recovery_dataset" \
  --arg table "$recovered_table_id" \
  --argjson deadline "$deadline_ms" '
  .type == "TABLE" and
  .tableReference.projectId == "farol-politico-495210" and
  .tableReference.datasetId == $dataset and
  .tableReference.tableId == $table and
  ((.resourceTags // {}) | length == 0) and
  (.expirationTime | tonumber) == $deadline and
  (.expirationTime | tonumber) > (now * 1000)
' "$recovered_file" >/dev/null
```

Replace both placeholders from the durable deletion log and snapshot file,
then validate the recovered table and its narrow dataset access before any
further action. Record an accountable owner and a re-deletion deadline no later
than that 24-hour expiration; after the recovery purpose is complete, explicitly
delete the recovered table/dataset and read back their absence rather than
relying only on expiry. Never restore into the old unbounded dataset or the
clean Analytics export dataset. This `bq cp`
path is customer-operable only within time travel. The following seven-day
fail-safe period cannot be queried or restored directly; emergency recovery
then requires Google Cloud Customer Care. After fail-safe ends, recovery is no
longer available. Time travel restores table data, not every metadata setting.
The generic recovery path is allowed only because the protected pre-deletion
manifest proved that each object was a base table with no partitioning,
clustering, row/column policy, resource tag, or customer-managed encryption
override. The REST copy job's `destinationExpirationTime` makes table creation
and the 24-hour TTL one atomic operation; the recovery dataset default remains
defense in depth, as specified by the official
[`JobConfigurationTableCopy`](https://cloud.google.com/bigquery/docs/reference/rest/v2/Job#JobConfigurationTableCopy)
contract. Preserve the original schema and metadata manifest for
validation, but never reproduce a null/unbounded historical expiration: the
quarantine TTL always wins.

- [ ] **Step 4: Verify the old dataset is empty and the clean dataset is intact**

```bash
bq ls --max_results=10000 \
  farol-politico-495210:analytics_535804267
bq ls --max_results=10000 \
  "farol-politico-495210:$new_analytics_dataset"
```

Expected: the old dataset has zero tables; the clean dataset still contains its daily event table with expiration. Record the postcheck and time-travel window.

- [ ] **Step 5: Record material deletion**

State how many tables were removed, that the old dataset itself remains, and the time-travel/recovery behavior observed. Do not claim immediate irrecoverability while BigQuery recovery windows remain.

### Task 10: Close the cutover and schedule bounded follow-interest cleanup

**Files:**
- Modify: `docs/operations/analytics-privacy-cutover-2026-09.md`
- Verify: repository docs and live `/privacidade`

**Interfaces:**
- Consumes: completed cleanup and new analytics cycle.
- Produces: final audited record plus an operational due date for the separate 180-day validation data rule.

- [ ] **Step 1: Re-run the complete public smoke path**

Verify health, Home, Acompanhar registration/withdrawal, Quiz calculation, Results, sharing preview, Community read/write boundaries, privacy route, and all three analytics states. Do not leave synthetic community content in production.

- [ ] **Step 2: Reconcile live policy with actual vendors/settings**

Confirm the live `/#/privacidade` notice names the actual controller, public email, Google/Firebase/GA4/BigQuery, Neon, NVIDIA NIM, ImprovMX/email handling, Cloud logs, transient sensitive quiz processing, persisted community political content, and current retention rules. Correct any statement not supported by configuration.

- [ ] **Step 3: Establish the follow-interest expiry operation without a scheduler**

Record the earliest `politician_follow_interests.created_at`, the exact next-expiry deadline (`min(created_at) + interval '180 days'`), and the experiment closure criterion. Put that deadline in the operator due-date register with an owner and review it early enough that deletion completes no later than the deadline; a generic monthly review is insufficient when it could run late. At each cleanup, delete rows whose individual `created_at + 180 days` is due by an explicit date-bounded SQL statement after aggregate inventory and approval, then recompute and register the next earliest expiry. When the validation experiment closes, inventory and delete every remaining row in this table after a separate explicit approval, regardless of age. Never include this table in quiz cleanup or reuse its identifier for another purpose.

- [ ] **Step 4: Complete the evidence document**

Include:

- code/CI commit and run IDs;
- active Cloud Run and Hosting releases;
- browser pending/denied/granted/revoked results;
- clean GA4 property/stream settings;
- new BigQuery dataset, TTL, table types, and consent checks;
- old GA4 trash/recovery deadline;
- old BigQuery and Neon aggregate deletions/recovery windows;
- preserved-table invariants;
- mailbox delivery result and outbound-address limitation;
- follow-interest next-expiry deadline, owner, and experiment-closure criterion;
- every rejected candidate's full inventory, bounded-TTL proof, BigQueryLink
  removal state, and confirmed retirement reference or concrete owner/due date.

- [ ] **Step 5: Close the rejected-candidate register**

Re-read every candidate property created during the operation, including those
that failed before BigQuery linking, and reconcile it to exactly one register
entry. For each rejected property, verify all streams/measurement IDs and any
BigQueryLink/dataset/tables are present in the entry, every extant table has a
bounded expiration, and either the separately confirmed retirement is complete
or an accountable owner and concrete due date are recorded. Any missing entry,
unbounded table, or open item without both owner and due date blocks this task
and the final commit.

- [ ] **Step 6: Commit the final operational record**

```bash
git add -f docs/operations/analytics-privacy-cutover-2026-09.md
git commit -m "docs: record analytics privacy cutover"
```
