# TASK-0006: Flutter Historical Events API Integration

## Goal

Wire `dau-viet-mobile` to the real Spring Boot backend (TASK-0005): Timeline lists published events from `GET /api/v1/events`, Event Detail loads `GET /api/v1/events/{id}` — data from PostgreSQL, not hard-coded UI. Keep the Bạch Đằng 938 demo journey intact and mock mode available behind a flag.

## Requirements and acceptance criteria

- AC-1: Dio-based `EventsApiClient` + shared API client; base URL via `--dart-define=API_BASE_URL` with sensible per-platform defaults (Android emulator `10.0.2.2`, iOS sim/desktop `localhost`); timeouts + typed error handling; no infinite retry.
- AC-2: `HistoricalEventDto` + `HistoricalEventRepository` abstraction with API impl matching existing structure; type-safe JSON parsing, no rampant `dynamic`.
- AC-3: Riverpod state: loading/success/empty/error + retry; no redundant API calls on rebuild; keep state across navigation where sensible.
- AC-4: Timeline ← `GET /api/v1/events`; Event Detail ← `GET /api/v1/events/{id}`; existing design/animations preserved; Bạch Đằng demo flow unbroken.
- AC-5: Mock fallback behind explicit flag (`USE_MOCK`/`--dart-define`); mock never silently replaces real data on API failure; clear separation API repo vs mock repo.
- AC-6: `AssetResolver` maps `coverAssetKey` → asset path; image fallback widget, no layout breakage on missing assets; no assumption key = public URL.
- AC-7: Tests: JSON parse, success/error, pagination, empty, 404, loading/retry, Timeline→Detail navigation, mock mode, missing-asset widget. `flutter analyze` clean + `flutter test` green.
- AC-8: Run/config docs updated (API URL per platform, mock flag); no scope creep into auth/admin/learning engine.

## Scope

- `dau-viet-mobile/lib/` (new `data/` layer, providers, screen wiring)
- `dau-viet-mobile/pubspec.yaml` (dio + test deps)
- `dau-viet-mobile/test/` (new tests)
- `tasks/TASK-0006/`, `plans/…` (plan + reports)
- `docs/` (run/config notes update)
- `dau-viet-backend/` only if a contract fix is needed (prefer not — backend is done)

## Constraints and risk

- Risk: normal (client-side wiring; no schema/API change expected).
- Depends on TASK-0005 contract: `docs/backend-flutter-contract-notes.md`.
- Keep mock path working for offline demo.
- Windows dev box: backend runs on `localhost:8080`; Android emulator needs `10.0.2.2:8080`.
- `pwsh` absent locally — harness `verify`/`finish` runs on pwsh-7 host (same limitation as TASK-0005).

## Plan

`plans/2026-10-15-flutter-events-integration/plan.md` (planner agent)

## Verification mapping

| AC | Check | Evidence |
|---|---|---|
| AC-1,2 | `EventsApiClient` tests + code review | plans/reports/… |
| AC-3,4 | provider/widget tests + manual run vs live backend | plans/reports/… |
| AC-5 | mock-mode test | plans/reports/… |
| AC-6 | missing-asset widget test | plans/reports/… |
| AC-7 | `flutter analyze`, `flutter test` | plans/reports/… |
| AC-8 | docs diff | docs/… |

## Handoff

Record real checks + live-integration evidence (or NOT VERIFIED + reason) in `tasks/TASK-0006/handoff.md`.
