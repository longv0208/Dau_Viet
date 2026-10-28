---
title: "[E4] Mobile: Bản đồ Di sản và hồ sơ địa điểm (Issue #24)"
description: "Refactor Heritage Map to API v2 without hardcoded slugs/UUIDs or map-based timeline mode, add Location Profile screen/sheet with dynamic Ảnh/Video/Tư liệu tabs (hiding empty tabs), ensure locked PUBLIC/ALWAYS_VISIBLE locations still display name and pin, and redirect TimelineScreen to /journey."
status: complete
priority: P1
effort: 4h
branch: feat/issue-24-heritage-map
tags: [mobile, heritage-map, location-profile, timeline, issue-24]
created: 2026-10-28
---

# [E4] Mobile: Bản đồ Di sản và hồ sơ địa điểm (Issue #24)

## 1. Goal & Scope

Implement the Flutter mobile Heritage Map v2 and Location Profile flow for **Issue #24 (`TASK-0024`)**:
- **Scope**:
  - `dau-viet-mobile/lib/features/map/**`
  - `dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`
  - `dau-viet-mobile/test/map/**`
  - `dau-viet-mobile/test/timeline_events_test.dart`
  - `plans/261028-issue-24-heritage-map/**`, `tasks/TASK-0024/**`
- **Hard Constraints**:
  - Do NOT edit `dau-viet-mobile/lib/app/router.dart` or `dau-viet-mobile/lib/features/learning_path/**` to guarantee zero merge conflicts with sibling branches `E1`–`E5`.
  - Keep `enum ExploreViewMode { timeline, map }` and `HistoricalMapScreen({this.initialMode = ExploreViewMode.map, this.initialEventId})` constructor signature intact so `router.dart` compiles without change.

## 2. Requirements & Architecture

### 2.1. Remove `_metaBySlugOrId` & Map-Based Timeline Mode (AC-1)
- Delete `_EventChronologicalMeta`, `_metaBySlugOrId`, `_resolveMeta`, `_buildViewModeSwitcher`, and `_buildTimelineView` from `dau-viet-mobile/lib/features/map/presentation/historical_map_screen.dart`.
- Remove all hardcoded slugs (`hung-vuong`, `hai-ba-trung`, `bach-dang`, `nhu-nguyet`, `dien-bien`) and hardcoded UUIDs (`00000000-0000-0000-0000-000000000001`..`000000000005`, `a0000000-...`) from `lib/features/map/**`.
- Render chapter headers and map canvas metadata dynamically from API v2 fields (`title`, `eventTitle`, `events`, `shortSummary`, `kind`, `coordinatePrecision`, `coverAssetId`) without guessing historical dates or slugs.
- If `HistoricalMapScreen` is entered with `initialMode == ExploreViewMode.timeline` and `/journey` is registered in `GoRouter`, redirect to `/journey`.

### 2.2. Map API v2 Data Layer (`lib/features/map/data/`)
- **`map_location_dto.dart`**:
  - Upgrade `MapLocationDto` to parse and expose all backend `MapLocationDto.java` v2 fields:
    - `id`, `eventId` (nullable/empty-safe), `eventTitle`, `slug`, `title`, `shortSummary`, `description`, `latitude`, `longitude`
    - `kind` (`HERITAGE_SITE` | `BATTLEFIELD` | `ANCIENT_CAPITAL` | `ARCHAEOLOGICAL_SITE` | `MEMORIAL` | `SCHEMATIC_REGION`)
    - `coordinatePrecision` (`EXACT` | `APPROXIMATE` | `SCHEMATIC_ONLY`)
    - `visibility` (`ALWAYS_VISIBLE` | `PUBLIC` | `HIDDEN_UNTIL_UNLOCKED`)
    - `unlockMode` (`NONE` | `ANY` | `ALL`)
    - `unlocked` (`bool`, defaulting to `unlockState != MapUnlockState.locked` when omitted in v1 fixtures)
    - `unlockState` (`AVAILABLE` | `LOCKED` | `UNLOCKED`)
    - `coverAssetId` (`String?`)
    - `requiredLesson` (`RequiredLessonRef?`)
    - `eventIds` (`List<String>`)
    - `events` (`List<MapLocationLinkedEventDto>`: `{eventId, title, yearLabel, role, sortOrder}`)
    - `unlockLessons` (`List<MapLocationUnlockLessonDto>`: `{lessonId, title, completed, accessible}`)
    - `media` (`List<MapLocationMediaDto>`: `{id, mediaType, title, caption, assetId, assetUrl, externalUrl, visibility, sortOrder}`)
  - Maintain backward compatibility for existing `const MapLocationDto(...)` calls in tests.
- **`map_api_client.dart` & `map_repository.dart` & `api_map_repository.dart`**:
  - `listLocations({String? periodCode, String? eventId, String? kind, bool? unlocked})` calling `GET /api/v1/map/locations` with optional query parameters.
  - `getLocationDetail(String locationId)` calling `GET /api/v1/map/locations/{locationId}`.
- **`mock_map_repository.dart`**:
  - Provide v2 heritage locations with symbolic IDs (no hardcoded production UUIDs), covering `PUBLIC` / `ALWAYS_VISIBLE` / `HIDDEN_UNTIL_UNLOCKED`, `NONE` / `ANY` / `ALL` unlock modes, linked events, unlock lessons, and rich media (`IMAGE_2D`, `PANORAMA_360`, `DOCUMENTARY_CLIP`, `AUDIO_GUIDE`).
- **`map_providers.dart`**:
  - Keep `mapLocationsProvider` session-scoped via `_mapSessionKey`.
  - Add `mapLocationDetailProvider = FutureProvider.family<MapLocationDto, String>` session-scoped via `_mapSessionKey` and authenticated via `withAuth`.

### 2.3. Locked Location Visibility on Map (AC-2)
- **"Địa điểm khóa vẫn hiện tên và ghim nếu visibility = PUBLIC"**:
  - `MapLocationDto.isPublicVisibility`: `true` when `visibility.toUpperCase()` is `'PUBLIC'` or `'ALWAYS_VISIBLE'` (or empty/default).
  - `MapLocationDto.shouldDisplayOnMap`: `true` when `isUnlocked` (`unlocked == true` or `unlockState != MapUnlockState.locked`) OR `isPublicVisibility` (`visibility` is `PUBLIC` / `ALWAYS_VISIBLE`); `false` when locked and `visibility == 'HIDDEN_UNTIL_UNLOCKED'`.
  - On the map (`JourneyMapNode`) and location chip bar (`JourneyLocationList`), locked locations with `visibility = PUBLIC` / `ALWAYS_VISIBLE` render both their pin (with lock icon) and their `title` label.

### 2.4. Location Profile Screen (`location_profile_screen.dart`)
- Dedicated screen/modal widget (`LocationProfileScreen`) opened when tapping a map pin or location chip, and directly mountable for `/heritage/:locationId` or widget tests.
- Watches `mapLocationDetailProvider(locationId)` while displaying `initialLocation` immediately while detail loads (or fetches by `locationId` when `initialLocation` is null).
- Displays header metadata:
  - Unlock status badge (icon + Vietnamese label), `kind` badge (Vietnamese label), `coordinatePrecision` badge, `title`, and `shortSummary`.
  - Cover illustration if `coverAssetId` is present (via `LearningAssetImage`).
- **Dynamic Tabs (`Ảnh`, `Video`, `Tư liệu`) — hide empty tabs**:
  - **Tab `Ảnh`**: Media items with `mediaType` in `{'IMAGE_2D', 'PANORAMA_360'}` (filtered so `UNLOCKED_ONLY` items are excluded when `!location.isUnlocked`). Hidden when empty.
  - **Tab `Video`**: Media items with `mediaType` in `{'DOCUMENTARY_CLIP', 'AUDIO_GUIDE'}` (filtered so `UNLOCKED_ONLY` items are excluded when `!location.isUnlocked`). Hidden when empty.
  - **Tab `Tư liệu`**: Historical description (`description`), linked historical events (`events` / `eventTitle`), and unlock rules/lessons (`unlockMode`, `unlockLessons`, `requiredLesson`). Hidden when all of those are empty.
  - Only non-empty tabs are rendered in the tab bar; if only 1 tab is non-empty, its content is shown cleanly without dead/empty tabs.
- Action buttons:
  - `HỌC ĐỂ MỞ` / `ÔN BÀI HỌC` (when `requiredLesson` or `unlockLessons` has an `accessible` lesson) -> navigates to `/learning/lesson/{lessonId}`.
  - `XEM SỰ KIỆN` (when `primaryEventId` is available) -> navigates to `/campaign/{eventId}`.

### 2.5. Timeline Redirect to `/journey` (`timeline_screen.dart`)
- Update `TimelineScreen` (`dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`):
  - When mounted inside a `GoRouter` that defines `/journey` in its route tree, automatically redirect to `/journey` via `WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/journey'))`.
  - Provide an explicit `"Mở Hành trình (/journey)"` banner/button that navigates to `/journey` when available, while preserving safe fallback rendering when mounted in standalone tests (`MaterialApp(home: TimelineScreen())` or pre-merge `appRouter` in `widget_test.dart` where `/journey` route is not yet registered).

## 3. Acceptance Criteria Mapping

| AC / Requirement | Implementation | Verification |
|---|---|---|
| **AC-1**: Không còn hardcode slug/UUID | Delete `_metaBySlugOrId` & `_resolveMeta` in `historical_map_screen.dart`; replace UUID literals in `mock_map_repository.dart` | `grep` check on `lib/features/map/**` + widget tests in `test/map/journey_map_ui_test.dart` |
| **AC-2**: Địa điểm khóa vẫn hiện tên và ghim nếu `visibility = PUBLIC` | `shouldDisplayOnMap` keeps locked `PUBLIC`/`ALWAYS_VISIBLE` locations and hides locked `HIDDEN_UNTIL_UNLOCKED`; `JourneyMapNode` renders pin + `location.title` | Unit + widget tests in `test/map/historical_map_test.dart` and `test/map/journey_map_ui_test.dart` |
| **API v2 & Location Profile Tabs** | `MapLocationDto` v2 + `getLocationDetail` + `LocationProfileScreen` with `Ảnh`/`Video`/`Tư liệu` tabs hiding empty tabs | Unit + widget tests in `test/map/historical_map_test.dart` and `test/map/journey_map_ui_test.dart` |
| **Timeline chuyển sang `/journey`** | `TimelineScreen` auto-redirects to `/journey` when route is available in `GoRouter` | Widget test in `test/timeline_events_test.dart` |
