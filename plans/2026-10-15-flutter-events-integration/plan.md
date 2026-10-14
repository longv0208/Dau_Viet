# TASK-0006 — Flutter Historical Events API Integration

> Plan: wire `dau-viet-mobile` to the real Spring Boot events API (TASK-0005) while
> keeping the Bạch Đằng 938 mock journey intact behind an explicit `USE_MOCK` flag.
> Contract source: `docs/backend-flutter-contract-notes.md` + `docs/API_SPEC.md` §events.

## Goal

`GET /api/v1/events` drives the Timeline list; `GET /api/v1/events/{id}` drives Event
Detail (Campaign). No UI/animation redesign — swap the data source only.

## Key decisions

1. **State mgmt:** Riverpod (already `flutter_riverpod ^3.4.3` in pubspec). Use plain
   `FutureProvider` / `Provider` — matches existing `lessonRepositoryProvider` pattern
   in `lib/mock/repositories/mock_lesson_repository.dart`. No codegen, no bloc.
2. **HTTP:** add `dio` to pubspec. One `ApiClient` wrapper (timeouts, `ApiException`
   mapping of `{code,message,details,traceId}` envelope + `X-Request-Id`).
3. **Base URL:** `--dart-define=API_BASE_URL`; defaults `http://10.0.2.2:8080` on
   Android, `http://localhost:8080` elsewhere.
4. **Mock flag:** `--dart-define=USE_MOCK=true` selects `MockEventsRepository` at the
   provider seam. API failure NEVER falls back to mock implicitly.
5. **IDs:** backend UUID becomes the app `eventId` (replaces `evt_bach_dang_938` in
   real mode). Route stays `/campaign/:eventId`. `MockEventsRepository` accepts both
   the seed UUID `00000000-0000-0000-0000-000000000001` and the legacy mock id so the
   existing full-journey widget test keeps passing.
6. **Assets:** `AssetResolver` maps `coverAssetKey` (`events/bach-dang-938/hero.jpg`)
   → bundled path under `assets/images/` via a slug→filename table (current assets are
   flat: `dv_EVT_ngoquyen_bachdang_hero_v01.jpg`), unknown → `null` → fallback widget.
   Never treats the key as a URL.
7. **Mapping:** adapter converts `HistoricalEventSummaryDto` → `TimelineMilestoneModel`
   and `HistoricalEventDetailDto` → `HistoricalEventModel` per contract-notes §2
   (`period`→`yearLabel`, `startYear`→`yearValue`/`year`, `summary`→`description`/`summary`,
   `coverAssetKey`→resolved asset, `tags`→`badgeText` first tag or null, `isActive`
   = `eventId == activeEventId` where active = first published event — keeps the demo CTA
   on Bạch Đằng without event-specific `if` in UI).

## Phases

| # | Phase | Status | Effort |
|---|---|---|---|
| 01 | API infrastructure (dio, ApiClient, ApiException, apiConfig) | done | S |
| 02 | Data layer (DTOs, EventsApiClient, repo + adapter, AssetResolver) | done | M |
| 03 | State + UI wiring (providers, Timeline + CampaignDetail, error/empty/retry) | done | M |
| 04 | Tests + docs + verification (analyze, test, runbook, evidence) | in progress | M |

Each phase file has context links, AC mapping, file create/modify list, steps,
todo checklist, success criteria, risks.

## Constraints honored

- Files <200 lines, kebab-case dart filenames, no business logic in widgets,
  constructor injection, typed JSON (no `dynamic` soup).
- No backend changes unless a real contract bug is found (flag, don't fix).
- No auth/admin/learning-engine scope.
- Live end-to-end vs a running backend is a separate verification step — recorded
  honestly in `tasks/TASK-0006/handoff.md` (or `NOT VERIFIED` + reason).

## Risks

- **R1** `flutter`/Android SDK not runnable on this box → verify `flutter doctor`
  early (phase 04); if absent, record `NOT VERIFIED`.
- **R2** Asset convention drift (flat vs per-slug dirs) → keep resolver table-driven;
  fallback widget covers missing keys (AC-6).
- **R3** Existing `widget_test.dart` full journey relies on mock — must still pass;
  mock flag keeps default `DauVietApp()` mock-safe only if we default `USE_MOCK`
  sensibly. Decision: **default `USE_MOCK=false`** (real API is the product) BUT the
  journey test overrides via `ProviderScope` override of `eventsRepositoryProvider`
  with `MockEventsRepository` — no reliance on `--dart-define` inside tests.
- **R4** Route default `'evt_bach_dang_938'` is not a UUID → backend would 400. Keep
  the literal only as a fallback when param missing; real flow always passes UUID.

## Open questions (need user decision if they matter)

- **Q1** `isActive` semantics: plan marks the *first* published event as the
  "active" milestone (single published seed today). Alternative: mark none active →
  hides the "Khám phá Chiến dịch" CTA. Recommend first-published rule; flag if product
  wants a dedicated `featuredEvent` flag later.
- **Q2** `subtitle` has no backend field — adapter derives `subtitle = period` when
  absent. Acceptable for now per contract-notes §2.
