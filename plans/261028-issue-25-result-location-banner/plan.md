---
title: "[E5] Mobile: Banner địa điểm vừa mở trên màn kết quả (Issue #25)"
description: "Mobile presentation & DTO integration for newly unlocked heritage locations banner on LessonResultScreen, with Xem địa điểm & Tiếp tục học CTAs, one-time unlock animation, anti-replay on deep-link, and widget tests."
status: complete
priority: P1
effort: 3h
branch: feat/issue-25-result-location-banner
tags: [mobile, learning-flow, heritage-location, result-screen, widget-test, issue-25]
created: 2026-10-28
---

# [E5] Mobile: Banner địa điểm vừa mở trên màn kết quả (Issue #25)

## 1. Goal & Scope

Implement **Issue #25 (`[E5] Mobile: banner dia diem vua mo tren man ket qua`)**:
- Display a celebratory newly-unlocked heritage location banner on `LessonResultScreen` ONLY when `newlyUnlockedLocations` is non-empty (`result.newlyUnlockedLocations.isNotEmpty`).
- Include two clear action buttons in the banner: **"Xem địa điểm"** and **"Tiếp tục học"**.
- Ensure **deep-link / reload** of the result screen (`/learning/result/:attemptId` without `state.extra` / `initialResult`) and widget rebuilds **never replay the unlock animation**.
- Provide comprehensive unit and widget tests covering DTO parsing, banner rendering, empty state hiding, button actions (`Xem địa điểm`, `Tiếp tục học`), and deep-link anti-replay behavior.

### Target Files
- `dau-viet-mobile/lib/features/learning/data/attempt_dtos.dart` (A3/C2 contract alignment: `UnlockedLocationCueDto`, `CompleteResultDto.newlyUnlockedLocations`, `LessonResultDto.newlyUnlockedLocations`)
- `dau-viet-mobile/lib/features/learning/presentation/lesson_player_screen.dart` (forward `complete.newlyUnlockedLocations` via route `extra` to `LessonResultScreen`, and invalidate `learnerLearningPathProvider` on completion)
- `dau-viet-mobile/lib/features/learning/presentation/widgets/unlocked_location_banner.dart` (new banner widget `UnlockedLocationBanner`)
- `dau-viet-mobile/lib/features/learning/presentation/lesson_result_screen.dart` (integrate `UnlockedLocationBanner`, pass `isFreshCompletion: initialResult != null`, re-export banner widget)
- `dau-viet-mobile/test/fakes/fake_attempt_repository.dart` (add optional `completeResult` field so player->result tests can script `newlyUnlockedLocations`)
- `dau-viet-mobile/test/learning/learning_dtos_test.dart` (unit tests for `UnlockedLocationCueDto` and `CompleteResultDto.newlyUnlockedLocations`)
- `dau-viet-mobile/test/learning/unlocked_location_banner_test.dart` (widget tests for `UnlockedLocationBanner` and `LessonResultScreen` deep-link / fresh completion flows)

---

## 2. Backend Contract Alignment (A2 / A3 / C2)

From `CompleteAttemptResponse.java` and `docs/API_SPEC.md`:
- `POST /api/v1/attempts/{attemptId}/complete` returns additive `newlyUnlockedLocations`:
  ```json
  "newlyUnlockedLocations": [
    {
      "locationId": "a0000000-0000-0000-0000-000000000004",
      "slug": "bai-coc-bach-dang",
      "title": "Bãi cọc Bạch Đằng (Yên Giang)",
      "kind": "HERITAGE_SITE",
      "coverAssetId": "d7a70000-0000-4000-8000-000000000003"
    }
  ]
  ```
- On idempotent replay of `POST /complete` (`alreadyCompleted == true`), server returns `newlyUnlockedLocations: []`.
- On `GET /api/v1/attempts/{attemptId}/result` (`LessonResultResponse`), server returns persisted attempt result without `newlyUnlockedLocations` (transient completion cue only).

---

## 3. Detailed Design

### 3.1. DTO Layer (`attempt_dtos.dart`)
- `UnlockedLocationCueDto`:
  - Fields:
    - `final String locationId;` (parses `json['locationId'] ?? json['id'] ?? ''`)
    - `final String? slug;`
    - `final String title;`
    - `final String? kind;`
    - `final String? coverAssetId;`
  - Helper `String get kindLabelVi`:
    - `'HERITAGE_SITE'` -> `'Di tích lịch sử'`
    - `'BATTLEFIELD'` -> `'Chiến trường cổ'`
    - `'ANCIENT_CAPITAL'` -> `'Kinh đô cổ'`
    - `'ARCHAEOLOGICAL_SITE'` -> `'Di chỉ khảo cổ'`
    - `'MEMORIAL'` -> `'Khu tưởng niệm'`
    - `'SCHEMATIC_REGION'` -> `'Vùng chiến lược'`
    - fallback -> `'Địa điểm di sản'`
- `CompleteResultDto`:
  - Add `final List<UnlockedLocationCueDto> newlyUnlockedLocations;` (default `const []`).
- `LessonResultDto`:
  - Add `final List<UnlockedLocationCueDto> newlyUnlockedLocations;` (default `const []`).

### 3.2. Player-to-Result Handoff (`lesson_player_screen.dart`)
- Store `List<UnlockedLocationCueDto> _newlyUnlockedLocations = const [];` in `_LessonPlayerScreenState`.
- In `_complete()`:
  - If `complete.newlyUnlockedLocations.isNotEmpty`, store `_newlyUnlockedLocations = complete.newlyUnlockedLocations`.
  - Also invalidate `learnerLearningPathProvider` / `learningPathProvider` alongside `mapLocationsProvider` so learning path & map state stay fresh.
- In `_fetchResult()`:
  - Pass `newlyUnlockedLocations: _newlyUnlockedLocations` into `enriched = LessonResultDto(...)` sent via `context.pushReplacement('/learning/result/${widget.attemptId}', extra: enriched)`.

### 3.3. `UnlockedLocationBanner` Widget (`widgets/unlocked_location_banner.dart`)
- `StatefulWidget` with `SingleTickerProviderStateMixin`:
  - Props:
    - `final List<UnlockedLocationCueDto> locations;`
    - `final bool animate;` (default `true`)
    - `final void Function(UnlockedLocationCueDto location)? onViewLocation;`
    - `final VoidCallback? onContinueLearning;`
  - Empty guard:
    - If `locations.isEmpty`, returns `const SizedBox.shrink()`.
  - One-shot entrance animation & anti-replay:
    - Uses `AnimationController` (`600ms`, `Curves.easeOutBack` scale `0.92 -> 1.0` + `Curves.easeOut` fade `0.0 -> 1.0` + icon pulse).
    - Tracks `bool _hasAnimated = false;` (exposed via `hasAnimated` on State for testability).
    - Plays `.forward()` in `initState()` **only** when `widget.animate == true` and `!_hasAnimated`.
    - When `widget.animate == false` (e.g., deep-link mount) or `MediaQuery.maybeDisableAnimationsOf(context) == true`, sets `_controller.value = 1.0` immediately without animating (`_hasAnimated` remains `false`, `isAnimating` is `false`).
    - `didUpdateWidget` never resets or replays `_controller`.
  - Visual layout (Dong Son / Parchment Heritage aesthetic):
    - Header badge with map/compass icon + `'ĐỊA ĐIỂM DI SẢN VỪA MỞ KHÓA'` (or `'ĐÃ MỞ KHÓA ${locations.length} ĐỊA ĐIỂM DI SẢN'` when `locations.length > 1`).
    - Lists each `UnlockedLocationCueDto`:
      - Leading icon badge (`Icons.place_rounded` / `Icons.temple_buddhist_rounded` / `Icons.shield_rounded` based on `kind`).
      - Location `title` + `kindLabelVi` subtitle chip.
    - Action buttons row:
      1. **`Xem địa điểm`** (`FilledButton.icon` / primary button):
         - Calls `onViewLocation!(locations.first)` if provided.
         - Otherwise navigates via `GoRouter`:
           - If `/heritage/:locationId` route is registered in `GoRouter`, navigates to `/heritage/${locations.first.locationId}`.
           - Else navigates to `/map?locationId=${Uri.encodeComponent(locations.first.locationId)}` (matches `/map` route while passing `locationId` query parameter).
      2. **`Tiếp tục học`** (`OutlinedButton.icon` / secondary button):
         - Calls `onContinueLearning!()` if provided.
         - Otherwise navigates via `GoRouter`:
           - If `/journey` route is registered and `/dashboard` is not, navigates to `/journey`; otherwise navigates to `/dashboard` (matching `LessonResultScreen`'s primary flow).

### 3.4. Integration in `LessonResultScreen` (`lesson_result_screen.dart`)
- Pass `isFreshCompletion: initialResult != null` into `_ResultView` and `_ResultBody`.
- When `initialResult == null` (deep-link `/learning/result/:attemptId` without `extra`):
  - `_ResultView` does not re-trigger `UnlockCelebrationDialog` popups (`isFreshCompletion == false`).
  - `_resultProvider(attemptId)` fetches `GET /api/v1/attempts/{id}/result` where `newlyUnlockedLocations` is empty (`const []`), so `UnlockedLocationBanner` is not rendered.
  - Even if a caller/test supplies `newlyUnlockedLocations` via `getResult` while `initialResult == null`, `animate: isFreshCompletion` is `false`, guaranteeing zero animation replay on deep-link.
- When `result.newlyUnlockedLocations.isNotEmpty`, `_ResultBody` renders `UnlockedLocationBanner(locations: result.newlyUnlockedLocations, animate: isFreshCompletion, ...)`.

---

## 4. Impact Analysis & Risk Assessment

- **GitNexus status**: `.gitnexus/run.cjs` unavailable in worktree; performed targeted reference analysis via `grep` across `dau-viet-mobile/`.
- **Blast radius**:
  - `CompleteResultDto` and `LessonResultDto`: additive optional `newlyUnlockedLocations = const []` parameter with default value; 0 breaking changes to existing callers.
  - `LessonResultScreen`: additive optional callbacks (`onViewLocation`, `onContinueLearning`) and conditional `UnlockedLocationBanner` rendering when `result.newlyUnlockedLocations.isNotEmpty`; existing tests (`lesson_recap_test.dart`, `lesson_player_test.dart`, `resume_test.dart`) unaffected.
  - Merge safety: No changes to `router.dart`, `lib/features/map/`, `lib/features/learning_path/`, or `lib/features/dashboard/`, ensuring zero conflicts with sibling branches E2 (`#22`), E3 (`#23`), and E4 (`#24`).

---

## 5. Acceptance Criteria & Verification Mapping

| AC | Requirement | Verification |
|---|---|---|
| AC-1 | Chỉ hiện khi `newlyUnlockedLocations` không rỗng; có nút `Xem địa điểm` và `Tiếp tục học` | `test/learning/unlocked_location_banner_test.dart`: verify banner hidden when `newlyUnlockedLocations` is empty, visible with title/kind when non-empty, and both `Xem địa điểm` and `Tiếp tục học` buttons navigate/invoke callbacks |
| AC-2 | Deep-link mở lại kết quả không phát lại animation | `test/learning/unlocked_location_banner_test.dart`: verify (1) completing lesson from player shows banner + plays animation once; (2) deep-link reopening `/learning/result/:id` (`extra: null` / `initialResult: null`) does not replay animation or re-show transient cue; (3) widget rebuilds do not replay animation |
| AC-3 | Widget test & static analysis | `flutter test test/learning/unlocked_location_banner_test.dart test/learning/learning_dtos_test.dart test/learning/lesson_player_test.dart test/learning/lesson_recap_test.dart` + `flutter analyze` |

---

## 6. Verification & Review Evidence (2026-10-28)

- `dart format --output=none --set-exit-if-changed lib/features/learning/data/attempt_dtos.dart lib/features/learning/data/mock_attempt_repository.dart lib/features/learning/presentation/lesson_player_screen.dart lib/features/learning/presentation/lesson_result_screen.dart lib/features/learning/presentation/widgets/unlocked_location_banner.dart test/fakes/fake_attempt_repository.dart test/learning/learning_dtos_test.dart test/learning/unlocked_location_banner_test.dart` (`cwd: dau-viet-mobile`): **PASS** (0 changed).
- `flutter analyze lib/features/learning/presentation/widgets/unlocked_location_banner.dart lib/features/learning/data/attempt_dtos.dart test/learning/unlocked_location_banner_test.dart test/learning/learning_dtos_test.dart` (`cwd: dau-viet-mobile`): **PASS** (`No issues found!`).
- `flutter test test/learning/unlocked_location_banner_test.dart test/learning/learning_dtos_test.dart test/learning/lesson_recap_test.dart test/learning/lesson_player_test.dart` (`cwd: dau-viet-mobile`): **PASS** (`38/38` tests pass).
- `git diff --check`: **PASS** (0 whitespace/conflict issues).
- Tool/role limitation note: `.gitnexus/run.cjs` not present in worktree; impact analysis and code review performed via targeted `grep` reference checks and contract verification against `CompleteAttemptResponse.java` and `docs/API_SPEC.md`.
