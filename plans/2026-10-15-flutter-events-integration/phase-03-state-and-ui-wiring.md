# Phase 03 — State + UI wiring

## Context links

- `dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart` — current StatefulWidget reading `MockTimelineData` directly
- `dau-viet-mobile/lib/features/campaign/presentation/campaign_detail_screen.dart` — takes `eventId`, reads `MockBachDangData` + hard-coded hero asset
- `dau-viet-mobile/lib/app/router.dart` — `/campaign/:eventId`, `/traces/:eventId`, fallback `'evt_bach_dang_938'`
- `dau-viet-mobile/lib/main.dart`, `lib/app/app.dart` — `ProviderScope` root
- `docs/backend-flutter-contract-notes.md` §3 decision 5 (slug/deep-link)

## Overview

- **Priority:** core deliverable
- **Status:** done
- **Effort:** Medium
- **AC coverage:** AC-3 (Riverpod loading/success/empty/error+retry, no redundant calls, keep state across navigation), AC-4 (Timeline ← list API, Detail ← detail API, design preserved, Bạch Đằng flow unbroken), AC-5 (USE_MOCK flag at provider seam)

## Requirements

### Providers (`lib/features/events/data/events_providers.dart` or a sibling `presentation/providers.dart` matching feature layout)

- `eventsRepositoryProvider` — `Provider<EventsRepository>`; chooses `MockEventsRepository` vs `ApiEventsRepository` via `ApiConfig.useMock` (overrideable in tests).
- `eventsListProvider` — `FutureProvider<List<TimelineMilestoneModel>>` (or `FutureProvider<EventsPageResult>`); `ref.keepAlive()`/`keepAlive` so navigation doesn't refetch (Riverpod 3: `ref.keepAlive()`). Maps list → milestones via adapter; computes `activeEventId = content.isEmpty ? null : content.first.id` (first published = Bạch Đằng).
- `eventDetailProvider` — `FutureProvider.family<HistoricalEventModel, String>` keyed on `eventId`; returns `HistoricalEventModel` with resolved `heroBannerUrl`.

### Timeline screen (minimal diff)

- Convert `TimelineScreen` → `ConsumerStatefulWidget` (keep `_selectedEra` in `State`).
- Replace `MockTimelineData.milestones` with `ref.watch(eventsListProvider)`:
  `AsyncValue.when(data: → existing ListView; loading: → centered branded spinner/shimmer over same scaffold; error: → error card with message + 'Thử lại' button calling `ref.invalidate(eventsListProvider)`; empty list → empty-state card)`.
- Era filter chips: derive era list from loaded milestones (`{ 'Tất cả', ...milestones.map((m)=>m.era).toSet() }`) instead of `MockTimelineData.eras`.
- Keep `_buildTimelineItem`, node/CTA visuals, bottom nav unchanged. The CTA already navigates `/campaign/${item.eventId}` — adapter now sets `eventId` = backend UUID, so no UI change needed for the id.
- Only the `isActive` milestone shows CTAs — adapter-driven `isActive` preserves this.

### Campaign detail screen (minimal diff)

- Convert to `ConsumerWidget`; `ref.watch(eventDetailProvider(eventId))` for event metadata (title, era, year, hero image path, summary).
- Replace `Image.asset('assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg')` with `EventCoverImage(path: AssetResolver.resolveEventCover(detail.coverAssetKey, detail.slug))` — keep the same AspectRatio 16/9 + overlay text (overlay copy stays as today since it is marketing copy, not API data).
- `lesson`/`historicalQuestion`/`4 Dấu Vết` metadata remain from `MockBachDangData` for now — learning engine/lessons are out of scope; only the hero banner + event header data swap to API (per AC-4 "existing design preserved"). Add loading/error+retry wrapper like Timeline.
- Back-button fallback `context.go('/timeline')` unchanged.

### Navigation & ids

- Route `/campaign/:eventId` keeps its signature; the fallback literal `'evt_bach_dang_938'` stays only for missing-param safety in mock mode (mock repo accepts it). Real flow passes the UUID from the list item.
- No new routes; no slug route yet (contract-notes decision 5 is a nice-to-have — skip to avoid scope creep; deep links still work by UUID).

### Mock flag

- `USE_MOCK` only gates `eventsRepositoryProvider` construction; API errors surface to UI as error state — never transparently swap to mock.

## Related code files

**Create**
- `lib/features/events/presentation/events_providers.dart` (or keep in data/ — pick one, stay consistent)

**Modify**
- `lib/features/timeline/presentation/timeline_screen.dart` — ConsumerStatefulWidget + AsyncValue handling
- `lib/features/campaign/presentation/campaign_detail_screen.dart` — ConsumerWidget + `eventDetailProvider` + `EventCoverImage`
- `lib/app/router.dart` — no change required (keep `/campaign/:eventId`)

## Implementation steps

1. Add providers file: `eventsRepositoryProvider`, `eventsListProvider` (with adapter + activeEventId logic + `keepAlive`), `eventDetailProvider.family`.
2. Timeline: wrap body in `ref.watch(eventsListProvider).when(...)`; derive eras from data; wire retry → `ref.invalidate`.
3. Campaign detail: `ref.watch(eventDetailProvider(eventId))`; swap hero `Image.asset` → `EventCoverImage`; error+retry wrapper.
4. Verify mock mode (`USE_MOCK=true`) still shows the full Bạch Đằng journey; verify real mode (backend up) hits the API.
5. Ensure no duplicate fetches: rely on `keepAlive`; don't `ref.invalidate` on `build`.

## Todo checklist

- [ ] `eventsListProvider` + `eventDetailProvider` with `keepAlive`/family
- [ ] Timeline renders loading / error+retry / empty / data states
- [ ] Era chips built from fetched data
- [ ] Campaign detail hero uses `EventCoverImage` + `AssetResolver`
- [ ] CTA passes backend UUID to `/campaign/`
- [ ] `USE_MOCK=true` path end-to-end demo green
- [ ] `flutter analyze` clean

## Success criteria

- Real mode: Timeline lists the seed `bach-dang-938` event; tapping CTA opens detail
  populated by `GET /api/v1/events/00000000-0000-0000-0000-000000000001`.
- Mock mode: identical UI journey as before this task (full-journey widget test still passes).
- API-down real mode: error card + retry, no mock data shown.

## Risks

- Riverpod 3 API naming (`ref.keepAlive()` vs codegen-free provider modifiers) — verify
  against installed `flutter_riverpod ^3.4.3` before writing providers; if `keepAlive`
  differs, use the matching API and note it in handoff.
- Existing full-journey `widget_test.dart` may break if mock is not the default in test
  env: tests override `eventsRepositoryProvider` with `MockEventsRepository` explicitly
  (do NOT rely on `--dart-define` inside `flutter test`).
