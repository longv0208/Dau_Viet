# Code Review Report — TASK-0024 (Issue #24)

- **Role**: `code-reviewer` (executed via `CodeReviewer` scout subagent; `reviewer` role model unavailable on host)
- **Task**: `TASK-0024` — `[E4] Mobile: Ban do Di san va ho so dia diem`
- **Verdict**: `APPROVE` (0 blockers, 0 warnings)

## Summary
1. **Scope Compliance**:
   - All changes are strictly under `dau-viet-mobile/lib/features/map/**`, `dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`, `dau-viet-mobile/test/map/**`, `dau-viet-mobile/test/timeline_events_test.dart`, `plans/261028-issue-24-heritage-map/**`, and `tasks/TASK-0024/**`.
   - `dau-viet-mobile/lib/app/router.dart` and `dau-viet-mobile/lib/features/learning_path/**` are 100% untouched.
2. **AC-1 (`Không còn hardcode slug/UUID`)**:
   - `_EventChronologicalMeta`, `_metaBySlugOrId`, `_resolveMeta`, and the map-based timeline view have been completely removed from `historical_map_screen.dart`.
   - `mock_map_repository.dart` uses clean symbolic IDs (`loc_den_hung`, `loc_hat_mon`, `loc_ben_bach_dang`, etc.) with zero hardcoded UUIDs.
   - Confirmed via `grep` across `lib/features/map` and `lib/features/timeline`: 0 matches for `_metaBySlugOrId`, `_resolveMeta`, or UUID literals.
3. **AC-2 (`Địa điểm khóa vẫn hiện tên và ghim nếu visibility = PUBLIC`)**:
   - `MapLocationDto.shouldDisplayOnMap` returns `true` when `unlocked || !isHiddenUntilUnlocked`.
   - Locked locations with `visibility = PUBLIC` (or `ALWAYS_VISIBLE`) render both their pin (`JourneyMapNode` with `Icons.lock_rounded`) and their `title` label on the map canvas and chip list, while locked `HIDDEN_UNTIL_UNLOCKED` locations are hidden.
4. **API v2 & Location Profile Dynamic Tabs**:
   - `MapLocationDto` parses all API v2 fields (`slug`, `shortSummary`, `kind`, `coordinatePrecision`, `visibility`, `unlockMode`, `unlocked`, `coverAssetId`, `eventIds`, `events`, `unlockLessons`, `media`).
   - `LocationProfileScreen` / `LocationProfileSheet` renders dynamic tabs (`Ảnh`, `Video`, `Tư liệu`) and hides any empty tab.
   - `TimelineScreen` automatically redirects to `/journey` when `/journey` is registered in `GoRouter`.
5. **Verification**:
   - `dart format --output=none --set-exit-if-changed` -> `0 changed`, exit 0.
   - `flutter analyze --no-pub` -> `No issues found!`, exit 0.
   - `flutter test --no-pub test/map/historical_map_test.dart test/map/journey_map_ui_test.dart test/timeline_events_test.dart` -> `31/31 tests passed`, exit 0.
