# Phase 04 — Tests, docs, verification

## Context links

- `tasks/TASK-0006/brief.md` — AC-7 test matrix, AC-8 docs, verification mapping table
- `dau-viet-mobile/test/widget_test.dart` — existing full-journey test (mock-dependent)
- `docs/backend-runbook.md` — how to run backend (`docker compose up -d`, `spring-boot:run -Dspring-boot.run.profiles=local`, `localhost:8080`)
- `tasks/TASK-0005/handoff.md` — seed id `00000000-0000-0000-0000-000000000001`, slug `bach-dang-938`, `JAVA_HOME` quirk
- `docs/AGENT_WORKFLOW.md` — evidence needs real command/cwd/exit code

## Overview

- **Priority:** required for done
- **Status:** in progress
- **Effort:** Medium
- **AC coverage:** AC-7 (tests + analyze/test green), AC-8 (docs), plus honest verification evidence in `tasks/TASK-0006/handoff.md`

## Requirements

### Unit tests (`dau-viet-mobile/test/`)

- `events_dto_test.dart` — parse contract-notes §1 JSON: summary fields, nullable detail fields (`description`/`location`/`publishedAt`), tags list, page envelope; malformed/missing required field → `TypeError`/`FormatException` surfaced (not silent null).
- `events_repository_test.dart` —
  - `ApiEventsRepository` over a stub `EventsApiClient`/`ApiClient` (inject a fake returning canned DTOs): success maps to `TimelineMilestoneModel`/`HistoricalEventModel` per adapter; empty content → empty list; `ApiException(EVENT_NOT_FOUND)` propagates; pagination params forwarded.
  - `MockEventsRepository` — returns mock milestones; `getEventById` accepts both seed UUID and `evt_bach_dang_938`.
  - Do NOT use a live HTTP mock server; constructor-inject a stub client (keeps it simple, no extra dep).
- `asset_resolver_test.dart` — known slug → path; unknown/null → null; key is never returned as a URL.
- `api_client_test.dart` (optional but cheap) — `ApiException` mapping for a crafted error envelope; timeout classification.

### Widget tests

- `timeline_events_test.dart` — `ProviderScope(overrides: [eventsRepositoryProvider.overrideWithValue(FakeRepo)])`:
  loading state shows spinner; success renders milestone title; error renders retry button and tapping it re-requests; empty list shows empty state.
- `campaign_detail_test.dart` — `eventDetailProvider` override: hero `EventCoverImage` placeholder renders when `coverAssetKey` unknown (missing-asset AC-6); error+retry state.
- `mock_mode_test.dart` — `USE_MOCK` path: `MockEventsRepository` via provider override produces the Bạch Đằng journey list/detail (asserts flag-driven separation, AC-5).
- Existing `widget_test.dart` full journey — update to override `eventsRepositoryProvider` with `MockEventsRepository` inside `ProviderScope(overrides: ...)` so it does not depend on compile-time `USE_MOCK`. Keep all assertions identical.

### Commands (evidence)

Run from `dau-viet-mobile/`:
- `flutter analyze` — expect "No issues found!".
- `flutter test` — all tests green incl. updated journey test.
- Live end-to-end (optional, separate step): backend up (`docker compose up -d` + `mvnw spring-boot:run -Dspring-boot.run.profiles=local`), then
  `flutter run -d <device> --dart-define=API_BASE_URL=http://localhost:8080` (desktop/Chrome) or `http://10.0.2.2:8080` (Android emulator); verify Timeline + Detail render seed event. Record result or `NOT VERIFIED` + reason (e.g. no emulator on box).

### Docs (AC-8)

- Update `dau-viet-mobile/README.md` (or `docs/backend-runbook.md` cross-link): `--dart-define=API_BASE_URL`, per-platform defaults, `USE_MOCK=true`, how to start backend first.
- `docs/backend-flutter-contract-notes.md` — append "consumed by TASK-0006" line + any deviations found during implementation.
- `tasks/TASK-0006/task.json` — `evidenceRefs`, `reviewRefs`, `nextAction`, status per workflow.
- `tasks/TASK-0006/handoff.md` — files changed, real commands + exit codes, limitations, next action.

## Related code files

**Create**
- `dau-viet-mobile/test/events_dto_test.dart`
- `dau-viet-mobile/test/events_repository_test.dart`
- `dau-viet-mobile/test/asset_resolver_test.dart`
- `dau-viet-mobile/test/timeline_events_test.dart`
- `dau-viet-mobile/test/campaign_detail_test.dart`
- `dau-viet-mobile/test/mock_mode_test.dart`
- `tasks/TASK-0006/handoff.md`

**Modify**
- `dau-viet-mobile/test/widget_test.dart` (provider override)
- `dau-viet-mobile/README.md` (or create minimal run notes inside it if absent — check first)
- `docs/backend-runbook.md` (mobile section) or `docs/backend-flutter-contract-notes.md` (consumed-by note)
- `tasks/TASK-0006/task.json`

## Implementation steps

1. Write DTO + repository + resolver unit tests; run `flutter test` until green.
2. Write widget tests with provider overrides; update `widget_test.dart` override.
3. `flutter analyze` — fix all reported issues (don't add ignore comments to force green).
4. Update runbook/README + contract-notes consumed-by; fill `task.json` evidence.
5. Attempt live run; record outcome in `handoff.md` (or `NOT VERIFIED` + reason).
6. Handoff: summarize files, commands, exit codes, limitations.

## Todo checklist

- [ ] DTO parse tests incl. nullable + malformed
- [ ] Repository success/error/empty/404 tests (stub client)
- [ ] Mock repo test (both ids)
- [ ] AssetResolver + missing-asset widget test
- [ ] Timeline loading/error-retry/empty widget test
- [ ] CampaignDetail widget test
- [ ] Mock-flag test proves API failure never swaps to mock
- [ ] `widget_test.dart` updated + still green
- [ ] `flutter analyze` clean, `flutter test` green — recorded with cwd + exit code
- [ ] Docs updated; task.json + handoff.md written
- [ ] Live run evidence or `NOT VERIFIED`

## Success criteria

- `flutter test` all green; `flutter analyze` clean.
- Each AC maps to a named test/check artifact.
- Handoff honestly states what ran (and what could not, with reason).

## Risks

- Flutter SDK absent/broken on box → `NOT VERIFIED`, recommend tester agent runs on a machine with Flutter.
- Dio stubbing: avoid adding `mockito`/`mocktail` unless needed — a hand-written fake `EventsApiClient` subclass is enough (YAGNI).
