# Phase 04 — Flutter map screen + navigation

## Context links

- `dau-viet-mobile/lib/app/router.dart` — add `/map` route
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart` — entry point (`_buildQuickShortcuts`)
- `dau-viet-mobile/lib/features/learning/data/learning_providers.dart` — provider conventions: `attemptRepositoryProvider` picks Mock/Api by `ApiConfig.useMock`; `withAuth(...)` wraps real calls
- `dau-viet-mobile/lib/features/learning/data/mock_attempt_repository.dart` — mock pattern
- `dau-viet-mobile/lib/core/api/api_client.dart` — `apiClientProvider` (Dio wrapper)
- `dau-viet-mobile/lib/core/theme/dau_viet_colors.dart` — `cinnabarRed`, `imperialGold`, `parchmentSurface`, `parchmentContainer`, `inkText`, `inkMuted`, `natureGreen`, `riverBlue`, `woodBrown`, `outlineVariant`
- `dau-viet-mobile/lib/core/widgets/parchment_card.dart`, `dong_son_button.dart`, `heritage_scaffold.dart`, `async_state_view.dart`
- `dau-viet-mobile/pubspec.yaml` — no map lib present
- `dau-viet-mobile/test/fakes/fake_attempt_repository.dart` — widget test seam

## Overview

- Priority: P0 for learner-facing value
- New feature dir `lib/features/map/` with `data/` + `presentation/`.
- `HistoricalMapScreen`: parchment/Dong Son styled map — custom `CustomPainter` backdrop (stylized VN coastline / river motif) + positioned marker widgets; list fallback view; detail bottom sheet; CTA → campaign/lesson.

## Map rendering decision (locked)

Custom painter, NOT `flutter_map`:

- Zero new dependencies; no tile-server licensing/attribution/network-failure modes.
- Brief allows "simpler custom painter if deps must be avoided" — choose it.
- Visual: `ParchmentMapPainter` draws coastline path + rivers in `riverBlue`/parchment tones over `parchmentSurface`; markers placed by projecting (lat,lng) → canvas rect via simple linear interpolation over a declared bounding box (e.g. Vietnam: lat 8.0–23.5, lng 102.0–110.5) — bounding box constants in `map_projection.dart`, clearly documented as display-only (not geodesic).
- This is a stylized illustration, not a GIS view — consistent with mockup aesthetic and FR-35 intent.

## Data layer

Files to create:

- `lib/features/map/data/map_location_dto.dart`:

```dart
class MapLocationDto {
  final String id, eventId, eventTitle, eventSlug, title;
  final String? description;
  final double latitude, longitude;
  final MapUnlockState unlockState; // enum available|locked|unlocked
  final RequiredLessonDto? requiredLesson; // {lessonId,title} only when locked
}
```

- `lib/features/map/data/map_repository.dart` — interface:

```dart
abstract class MapRepository {
  Future<List<MapLocationDto>> listLocations();
  Future<MapLocationDto> getLocation(String id);
}
```

- `lib/features/map/data/api_map_repository.dart` — `GET /api/v1/map/locations`, `GET /api/v1/map/locations/{id}` via `LearningApiClient`-style thin client or direct `apiClientProvider` Dio calls (check `learning_api_client.dart` pattern; create `map_api_client.dart` if it keeps separation cleaner — prefer small dedicated client, mirrors `events_api_client.dart`).
- `lib/features/map/data/mock_map_repository.dart` — fixture Bạch Đằng locations (demo coords inside fixture file OK — mock is explicitly demo data; not backend seed).
- `lib/features/map/data/map_providers.dart`:

```dart
final mapRepositoryProvider = Provider<MapRepository>((ref) =>
    ApiConfig.useMock ? MockMapRepository()
                      : ApiMapRepository(ref.watch(mapApiClientProvider)));

final mapLocationsProvider = FutureProvider<List<MapLocationDto>>(retry: _noRetry, (ref) {
  final repo = ref.watch(mapRepositoryProvider);
  if (ApiConfig.useMock) return repo.listLocations();
  return ref.read(authRepositoryProvider).withAuth(repo.listLocations);
});
```

Real mode never falls back to mock on error (existing rule — reuse `_noRetry` pattern; hoist the retry lambda into a shared spot or duplicate the 1-liner per existing convention in `learning_providers.dart`).

## UI

`lib/features/map/presentation/historical_map_screen.dart` (~200 lines max — split if needed):

- `HeritageScaffold`-style shell (check widget's API) with title "Bản Đồ Di Sản".
- `mapLocationsProvider.when(...)` — reuse `AsyncStateView` for loading/error/empty.
- Map area: `LayoutBuilder` → `CustomPaint(painter: ParchmentMapPainter())` + `Stack` of `MapMarker` widgets at projected offsets.
- `MapMarker` (widget): tap → detail sheet. Visuals by state:
  - UNLOCKED: cinnabar red seal + check
  - AVAILABLE: imperial gold pin
  - LOCKED: muted ink pin + lock icon, desaturated
- Detail bottom sheet (`showModalBottomSheet`): title, description preview, event name; LOCKED → "Hoàn thành bài học '{requiredLesson.title}' để mở khoá" + CTA to `/learning/lesson/{lessonId}`; AVAILABLE/UNLOCKED → CTA "Khám phá sự kiện" → `/campaign/{eventId}`.
- List fallback: toggle icon in AppBar → `ListView` of `ParchmentCard` rows (accessibility + small screens).
- Refresh: pull-to-refresh (`RefreshIndicator`) → `ref.invalidate(mapLocationsProvider)`.

Files:

- `lib/features/map/presentation/historical_map_screen.dart`
- `lib/features/map/presentation/widgets/parchment_map_painter.dart`
- `lib/features/map/presentation/widgets/map_marker.dart`
- `lib/features/map/presentation/widgets/location_detail_sheet.dart`
- `lib/features/map/presentation/widgets/map_location_list.dart` (list fallback)
- `lib/features/map/data/map_projection.dart` — lat/lng → `Offset` helper, unit-testable.

## Navigation integration

`router.dart`:

```dart
GoRoute(path: '/map', name: 'historical_map',
        builder: (context, state) => const HistoricalMapScreen()),
```

Add `'/map'` to `_learningPrefixes`? No — map requires auth in real mode anyway at API level; guard-wise treat like dashboard (not in `_learningPrefixes` since mock guest mode must access it; real-mode unauthorized gets 401 → auth repository's refresh flow / error state). Decision: keep unguarded like `/dashboard` — consistent.

Dashboard (`learner_dashboard_screen.dart` `_buildQuickShortcuts`): add a third shortcut card "Bản Đồ Di Sản" → `context.go('/map')`. Keep existing Sa Bàn + Timeline cards (do not break TASK-0019/0020).

Completion → refresh loop: after returning from `/learning/result/:id` or lesson player, map screen must reflect new unlock. Since `mapLocationsProvider` is a `FutureProvider`, invalidate when the map screen rebuilds (e.g. in `initState`/`didChangeDependencies` no — simplest: invalidate inside the CTA navigation return, OR call `ref.invalidate(mapLocationsProvider)` in the screen's `build` guarded to first build like dashboard's resume-card comment). DECISION: `ref.invalidate` inside `initState` via `Future.microtask` — refetches on every screen mount; safe because provider is not auto-dispose? Keep provider non-autoDispose and invalidate on mount for fresh state.

## Todo

- [ ] DTO + repository interface + api + mock impls
- [ ] `map_providers.dart`
- [ ] `map_projection.dart` + unit test coverage (phase 05)
- [ ] `HistoricalMapScreen` + widgets
- [ ] Route + dashboard shortcut
- [ ] `flutter analyze` clean

## Success criteria

- `USE_MOCK=true` → map renders demo markers with all 3 states visible.
- Real mode → markers reflect server `unlockState`; locked marker sheet shows required lesson title; CTA navigates to lesson entry.
- After completing the linked lesson and returning to `/map`, marker shows UNLOCKED.
- No `flutter_map`/new deps in pubspec.
- No `if (eventId == ...)` anywhere — all data-driven.

## Risks

- Projection edge cases (locations outside bbox) — clamp offsets to canvas bounds rather than hiding.
- Bottom nav: dashboard nav bar has fixed 5 items; do NOT retarget an existing item — map reachable via shortcut card only (document decision; avoids breaking TASK-0019/0020 nav tests).

## Security considerations

- No coords/userId sent client→server beyond the path id.
- Locked detail sheet displays only fields the locked DTO exposes.
