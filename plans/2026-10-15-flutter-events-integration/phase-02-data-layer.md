# Phase 02 — Data layer

## Context links

- `docs/backend-flutter-contract-notes.md` §1 (payloads), §2 (field-by-field delta — THE map), §3 decisions 2 & 4
- `dau-viet-mobile/lib/mock/models/timeline_models.dart` — `TimelineMilestoneModel`
- `dau-viet-mobile/lib/mock/models/lesson_models.dart` — `HistoricalEventModel`
- `dau-viet-mobile/lib/mock/repositories/mock_lesson_repository.dart` — existing repo+provider pattern to mirror
- `dau-viet-mobile/lib/mock/data/mock_timeline_data.dart`, `mock_bach_dang_data.dart`
- `dau-viet-mobile/assets/images/` — flat dir; `dv_EVT_ngoquyen_bachdang_hero_v01.jpg`

## Overview

- **Priority:** blocking (phase 03 consumes it)
- **Status:** done
- **Effort:** Medium
- **AC coverage:** AC-2 (DTO + repository abstraction, typed JSON), AC-5 (clear API vs mock repo separation), AC-6 (AssetResolver + fallback)

## Requirements

### DTOs (new, under `lib/features/events/data/` or `lib/data/events/` — match feature layout)

- `HistoricalEventSummaryDto` — `{String id, String slug, String title, String era, String period, int startYear, String summary, String? coverAssetKey, List<String> tags}`.
- `HistoricalEventDetailDto` — extends summary shape with `{String? description, String? location, String? publishedAt}`.
- `EventsPageDto` — `{List<HistoricalEventSummaryDto> content, int page, int size, int totalElements, int totalPages}`.
- All `fromJson` use `as` casts + null-safety; parse `content` via `.cast<Map<String,dynamic>>().map(HistoricalEventSummaryDto.fromJson)`.

### API client for events

- `EventsApiClient` (uses phase-01 `ApiClient`):
  - `Future<EventsPageDto> getEvents({int page = 0, int size = 20, String sort = 'startYear,asc'})`
  - `Future<HistoricalEventDetailDto> getEventById(String id)` — id must be UUID; don't pre-validate client-side beyond non-empty (server returns `MALFORMED_ID`).

### Repository seam

- `abstract class EventsRepository { Future<EventsPageResult> getEvents({page,size,sort}); Future<HistoricalEventModel> getEventById(String id); }`
- `ApiEventsRepository` — wraps `EventsApiClient`, maps DTOs → app models via adapter.
- `MockEventsRepository` — returns `MockTimelineData.milestones`/`MockBachDangData.event`; accepts both the seed UUID `00000000-0000-0000-0000-000000000001` and legacy `evt_bach_dang_938` in `getEventById` so mock mode + existing tests keep working.
- Keep separate file per repo impl; provider file exposes
  `eventsRepositoryProvider = Provider<EventsRepository>((ref) => ApiConfig.useMock ? MockEventsRepository() : ApiEventsRepository(ref.watch(eventsApiClientProvider)))`.

### Adapter (DTO → UI models, per contract-notes §2)

- `EventModelAdapter` static methods:
  - `toTimelineMilestone(HistoricalEventSummaryDto, {required bool isActive, required String? heroAssetPath})` → `TimelineMilestoneModel(id: dto.id, yearLabel: dto.period, yearValue: dto.startYear, title, era, description: dto.summary, subtitle: dto.period, badgeText: dto.tags.isNotEmpty ? dto.tags.first : null, isActive, eventId: dto.id)`.
  - `toHistoricalEvent(HistoricalEventDetailDto, {required String heroAssetPath})` → `HistoricalEventModel(id, title, era, year: startYear, heroBannerUrl: resolvedAsset, summary, lessonIds: const [])` (lessons out of scope — empty list, UI already handles).
- `isActive` rule: adapter marks only the event whose id == `activeEventId` (provider supplies first item of the list) — no event-specific literal in adapter.

### AssetResolver + fallback widget

- `AssetResolver` (`lib/core/assets/asset_resolver.dart`):
  - `String? resolveEventCover(String? coverAssetKey, String? slug)` — table-driven slug→filename map, e.g. `{ 'bach-dang-938': 'assets/images/dv_EVT_ngoquyen_bachdang_hero_v01.jpg' }`. Returns `null` when unknown. Never builds a public URL from the key.
- `EventCoverImage` widget (`lib/core/widgets/event_cover_image.dart`): `Image.asset(path, errorBuilder: → branded placeholder Container + Icon)`; when path is `null`, render the placeholder directly (no layout breakage, AC-6).

## Related code files

**Create**
- `lib/features/events/data/historical_event_dto.dart` (summary+detail+page)
- `lib/features/events/data/events_api_client.dart`
- `lib/features/events/data/events_repository.dart` (abstract + result type)
- `lib/features/events/data/api_events_repository.dart`
- `lib/features/events/data/mock_events_repository.dart`
- `lib/features/events/data/event_model_adapter.dart`
- `lib/features/events/data/events_providers.dart`
- `lib/core/assets/asset_resolver.dart`
- `lib/core/widgets/event_cover_image.dart`

**Modify**
- none (existing mock files untouched)

## Implementation steps

1. Write DTO file with typed `fromJson` (mirror contract-notes §1 JSON).
2. Write `events_api_client.dart` over `ApiClient`.
3. Write `events_repository.dart` (abstract + `EventsPageResult`).
4. Write `event_model_adapter.dart` implementing the §2 map.
5. Write `asset_resolver.dart` + `event_cover_image.dart`.
6. Write `api_events_repository.dart` and `mock_events_repository.dart`.
7. Write `events_providers.dart` with `eventsApiClientProvider`, `eventsRepositoryProvider`, `assetResolverProvider`.

## Todo checklist

- [ ] DTOs parse verified payload (contract-notes §1) incl. nullable detail fields
- [ ] `EventsApiClient` sends `page/size/sort` query params
- [ ] `ApiEventsRepository` + `MockEventsRepository` behind one abstraction
- [ ] Adapter maps every field per §2; no `if (id == 'bach-dang-938')` literals
- [ ] `AssetResolver` returns path or null, never URL
- [ ] `EventCoverImage` renders placeholder on null path and on asset load error
- [ ] `flutter analyze` clean

## Success criteria

- `mock_events_repository` reproduces the current Timeline/Demo data exactly.
- `api_events_repository` returns the same UI models from DTOs.
- Each file <200 lines.

## Risks

- `tags` → `badgeText` is lossy (takes first tag) — acceptable per §2; revisit if
  product wants multi-badge.
- `subtitle` has no backend source — derived from `period`; flag in handoff if a
  dedicated field is desired later.
