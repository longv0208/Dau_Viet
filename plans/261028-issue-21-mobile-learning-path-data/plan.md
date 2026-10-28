---
title: "[E1] Mobile: Data Layer Learning Path (Issue #21)"
description: "Mobile data layer for Learning Path 2.0 (ERA -> PERIOD -> PHASE -> EVENT -> LESSON), per-period progression, touch endpoint, API + Mock repositories, Riverpod providers, and DTO unit tests."
status: complete
priority: P1
effort: 4h
branch: feat/issue-21-learning-path
tags: [mobile, learning-path, riverpod, dto, issue-21]
created: 2026-10-28
---

# [E1] Mobile: Data Layer Learning Path (Issue #21)

## 1. Goal & Scope
Implement the Flutter mobile data layer for **Learning Path 2.0** (`HISTORY_MAIN`) under `dau-viet-mobile/lib/features/learning_path/data/`, strictly scoped to avoid merge conflicts with parallel branches/worktrees (`E2` in `lib/features/learning_path/presentation/` and `E3` in `learner_dashboard_screen.dart`, `campaign_detail_screen.dart`, `event_progress_section.dart`).

### Target Files
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_dto.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_dtos.dart` (re-export barrel for singular/plural import compatibility)
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_api_client.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/api_learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/mock_learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_providers.dart`
- `dau-viet-mobile/test/learning_path/learning_path_dto_test.dart`
- `dau-viet-mobile/test/learning_path/learning_path_repository_test.dart`

## 2. Backend Contract Alignment (Contract A2 & Phase B)

### Endpoints
1. `GET /api/v1/me/learning-path` (Authenticated learner):
   - Auto-enrolls/upgrades learner to latest `PUBLISHED` version of `HISTORY_MAIN`.
   - Returns `{pathCode, pathVersion, enrolled, summary, current, chapters[], periodProgress[], currentByPeriod, lastPeriodCode}`.
2. `POST /api/v1/me/learning-path/periods/{periodCode}/touch` (Authenticated learner):
   - Updates `user_path_period_state.last_touched_at` for `periodCode`.
   - Returns `{periodCode, chapterId, touchedAt}`.
3. `GET /api/v1/learning-path?code=HISTORY_MAIN` (Public / Authenticated):
   - Returns `{pathCode, pathVersion, title, description, chapters[]}`.

### Domain Enums & DTOs
- `PathNodeType`: `ERA`, `PERIOD`, `PHASE` (default `PERIOD` when null/absent).
- `LearnerPathStatus`: `LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY` (with Vietnamese labels and semantic helpers `canStart`, `isUnlocked`, `isDone`, etc. for E2/E3).
- `PathContentStatus`: `PLAYABLE`, `NO_PUBLISHED_LESSON`, `NO_COMPLETION_POLICY`, `CONTENT_REVIEW_REQUIRED`.
- `ParticipationType`: `REQUIRED`, `EXPLORATION_ONLY`.
- `EventDatePrecision` (`DatePrecision`): `EXACT`, `CIRCA`, `CENTURY`, `PERIOD`.
- `LearningPathSummaryDto`: `completedEvents`, `totalRequiredEvents`, `completedLessons`, `totalRequiredLessons`, progress fractions.
- `LearningPathCurrentDto`: `chapterId`, `eventNodeId`, `lessonId`.
- `PeriodProgressDto`: `chapterId`, `code`, `title`, `completedEvents`, `requiredEvents`, `completedLessons`, `requiredLessons`, `percent`.
- `LearningPathChapterDto`: `chapterId`, `parentId`, `nodeType`, `code`, `title`, `description`, `startYear`, `endYear`, `periodLabel`, `sortOrder`, `themeKey`, `events[]`.
- `LearningPathEventNodeDto`: `eventNodeId` (`nodeId` fallback), `eventId`, `slug`, `title`, `startYear`, `endYear`, `datePrecision`, `yearLabel`, `period`, `coverAssetKey`, `sortOrder`, `participationType`, `status`, `contentStatus`, `lessons[]`.
- `LearningPathLessonNodeDto`: `lessonNodeId`, `lessonId`, `title`, `sortOrder`, `status`.
- `TouchPeriodResponseDto`: `periodCode`, `chapterId`, `touchedAt`.
- `LearningPathDto` (`LearnerLearningPathDto` alias): full tree + hierarchy/lookup helpers (`eras`, `periods`, `periodsOfEra`, `phasesOfPeriod`, `eventsOfPeriod`, `buildTree`, `eraGroups`, `effectiveCurrent`, `findEventByNodeId`, `findEventById`, `findLessonById`, `lessonStatusOf`, `lessonStatusMap`, `progressForPeriod`).

## 3. Mock Repository Requirements (AC-2)
- Contains **3 ERA** root chapters (`ERA_ANCIENT_MEDIEVAL`, `ERA_EARLY_MODERN`, `ERA_MODERN`).
- Contains **6 PERIOD** child chapters across the 3 ERAs (`FOUNDING_ERA`, `NORTHERN_DOMINATION`, `EARLY_INDEPENDENCE`, `LY_DYNASTY`, `PATRIOTIC_MOVEMENTS`, `ANTI_FRENCH_RESISTANCE`) + optional `PHASE` support.
- Covers **all 6 `LearnerPathStatus` values** (`COMPLETED`, `MASTERED`, `IN_PROGRESS`, `AVAILABLE`, `LOCKED`, `NOT_READY`), both `ParticipationType` values (`REQUIRED`, `EXPLORATION_ONLY`), and multiple `PathContentStatus` values (`PLAYABLE`, `NO_PUBLISHED_LESSON`).
- Supports stateful `touchPeriod(periodCode)` in memory (validates `PERIOD` existence, updates `lastPeriodCode` and `current`).


## 5. Verification & Review Notes (2026-10-28)
- `dart format --output=none --set-exit-if-changed lib/features/learning_path test/learning_path` (`cwd: dau-viet-mobile`): **PASS** (0 changed).
- `flutter analyze lib/features/learning_path test/learning_path` (`cwd: dau-viet-mobile`): **PASS** (`No issues found!`).
- `flutter test test/learning_path` (`cwd: dau-viet-mobile`): **PASS** (`9/9` tests pass).
- `git diff --check`: **PASS** (0 whitespace/conflict issues).
- Scope isolation: Only `dau-viet-mobile/lib/features/learning_path/data/**`, `dau-viet-mobile/test/learning_path/**`, and `plans/261028-issue-21-mobile-learning-path-data/plan.md` were added, ensuring zero merge conflicts with sibling branches `feat/issue-22-period-journey` (E2) and `feat/issue-23-journey-home` (E3).
- Tool/role limitation note: Subagent `reviewer` via `task` tool returned `Error: No model selected` in local CLI config; self-review against backend `LearnerLearningPathResponse.java`, `LearningPathResponse.java`, `docs/API_SPEC.md`, and `docs/LEARNING_PATH_2_0.md` was completed directly.
## 4. Acceptance Criteria Mapping
| AC | Requirement | Verification |
|---|---|---|
| AC-1 | Parse đủ contract A2 | `test/learning_path/learning_path_dto_test.dart` covering learner response, public response, touch response, hierarchy tree, edge/null cases |
| AC-2 | Mock có 3 ERA, nhiều PERIOD, đủ trạng thái | `test/learning_path/learning_path_repository_test.dart` asserting 3 ERAs, >=5 PERIODs, all 6 `LearnerPathStatus` states, and `touchPeriod` behavior |
| AC-3 | Unit test DTO | `flutter test test/learning_path/` + `flutter analyze` + `dart format` |
