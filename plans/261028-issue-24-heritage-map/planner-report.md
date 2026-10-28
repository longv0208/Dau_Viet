# Planner-Researcher Report — TASK-0024 (Issue #24)

- **Role**: `planner` (executed via `PlannerResearcher` scout subagent)
- **Task**: `TASK-0024` — `[E4] Mobile: Ban do Di san va ho so dia diem`
- **Plan**: `plans/261028-issue-24-heritage-map/plan.md`

## Findings
1. **Hardcoded Slugs/UUIDs & Map-Based Timeline Removal (AC-1)**:
   - `historical_map_screen.dart` previously defined `_EventChronologicalMeta`, `_metaBySlugOrId` (`hung-vuong`, `hai-ba-trung`, `bach-dang`, `nhu-nguyet`, `dien-bien`), and `_resolveMeta` matching UUID suffixes `000000000001`..`000000000005`, alongside an embedded timeline mode (`_buildTimelineView`, `_buildViewModeSwitcher`).
   - All hardcoded slug/UUID maps and the map-based timeline mode must be removed so `HistoricalMapScreen` renders purely from `MapLocationDto` v2 fields.
   - Keep `enum ExploreViewMode { timeline, map }` and `HistoricalMapScreen({this.initialMode, this.initialEventId})` constructor parameters for source compatibility with `lib/app/router.dart` (which is out of scope for E4).
2. **Backend Map v2 Contract Alignment**:
   - `GET /api/v1/map/locations` supports optional `periodCode`, `eventId`, `kind`, `unlocked` query params.
   - `GET /api/v1/map/locations/{locationId}` returns full location detail including `events[]`, `unlockLessons[]`, and `media[]` (`IMAGE_2D`, `PANORAMA_360`, `AUDIO_GUIDE`, `DOCUMENTARY_CLIP`).
3. **Locked Location Visibility (AC-2)**:
   - Locked locations with `visibility = PUBLIC` (or `ALWAYS_VISIBLE`) must remain visible on the map with both their pin (`JourneyMapNode` lock icon) and their `title` label, whereas locked locations with `visibility = HIDDEN_UNTIL_UNLOCKED` are hidden until unlocked.
4. **Location Profile Screen (`LocationProfileScreen`)**:
   - Displays location metadata (`kind`, `coordinatePrecision`, `unlockState`, `title`, `shortSummary`, `coverAssetId`) and dynamic tabs (`Ảnh`, `Video`, `Tư liệu`) where any empty tab is hidden.
5. **Timeline Redirect to `/journey`**:
   - `TimelineScreen` redirects to `/journey` when mounted inside a `GoRouter` that registers `/journey`, while keeping a safe fallback when `/journey` is not registered (e.g., standalone widget tests).
