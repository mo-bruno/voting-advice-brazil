# Direct mobile sharing implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship direct banner sharing in the real mobile website, using the best available paths for Instagram, X and WhatsApp.
**Architecture:** Conditional Dart web adapter prepares native browser File/Blob objects before the user gesture. Existing Flutter sharing page invokes it directly and shows alternatives only on failure or on demand.
**Tech Stack:** Flutter 3.41.6, Dart JS interop, package:web 1.1.1, Web Share/Clipboard, Firebase Hosting REST.
**Spec:** `docs/superpowers/specs/2026-09-30-mobile-sharing-flow.md`

## Global Constraints

- Site no celular e worktree isolada; produção autorizada.
- Main base `162e357`; preservar privacidade e variáveis públicas.
- Arquivos preparados antes do toque, cancelamento sem ação secundária.
- PNG permanece utilizável quando a conversão JPEG falha.
- Não anunciar publicação nem garantir destinatário que o navegador não informa.

## Review Focus

- JPEG indisponível não deve impedir PNG ou tornar preparação infinita.
- Share e clipboard precisam ser chamados dentro do gesto original.
- Fechar o menu não deve baixar/abrir apps ou dizer que publicou.
- Formato/cores alterados não devem reutilizar File de outro banner.
- Release concorrente não deve ser substituída por snapshot antigo.

### Task 1: Direct sharing and alternatives

**Files:** Modify `mobile/lib/features/results/sharing/result_share_{page,service,data}.dart`, `mobile/pubspec.yaml`, `mobile/test/result_share_{page,service,data}_test.dart`, README. Create `result_share_browser.dart` and `result_share_browser_stub.dart` next to the service.
**Interfaces:** `PreparedResultShareImage` contains PNG, format and optional opaque web payload. `prepareImage(bytes, format)` runs before clicks; `sharePrepared(image, network, origin, text:)` invokes the browser immediately. Browser adapter exports `prepare`, `share`, `copyImage` and `canCopyImage` with matching stubs.

- [ ] Change widget assertions for direct X/Instagram and explicit failure fallback first. Run focused widget tests. Expected: fail on current behavior.
- [ ] Add prebuilt PNG/JPEG browser files, iPhone `.igo` Post/`.wai` WhatsApp selection, synchronous share/write and AbortError dismissal. Use conditional imports for VM tests. Keep PNG when JPEG cannot encode.
- [ ] Replace initial Instagram help with direct share, make X send image, offer an alternatives sheet with PNG/copy/save/open links. Add enum Instagram and Story-aware launch URI. Add contract tests for prepared PNG and network URI; run sharing tests and analyze changed files. Expected: pass.
- [ ] Build release with current production defines. Expected: success. Independent whole-branch review before deployment.

### Task 2: Authorized production release

**Files:** Local release artifacts under `.superpowers/sdd/2026-09-30-mobile-sharing-flow/`.
**Interfaces:** Consume tested build and current Hosting manifest/config. Produce preserved static files plus new Flutter runtime assets and a rollback receipt.

- [ ] Fetch current release/config/manifest; compare current remote main with branch base. Encode new build files as deterministic gzip/SHA256 and merge into manifest, retaining unrelated production paths.
- [ ] Create/finalize new version, compare remote full manifest/config, then guard current release identity before publishing. Expected: exact hashes/config, no concurrent change.
- [ ] Publish using existing authorization and verify live HTML/runtime hashes over HTTPS. Expected: new build publicly served and current privacy configuration preserved.
- [ ] Record completion and provide site URL, implemented behavior and real-device validation limits.
