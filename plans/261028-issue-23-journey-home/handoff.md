---
title: "Handoff: [E3] Mobile: Trang chu Tiep tuc hanh trinh va trang thai bai (Issue #23)"
status: completed
branch: feat/issue-23-journey-home
issue: 23
created: 2026-10-28
---

# Handoff — Issue #23 (`[E3] Mobile: Trang chủ Tiếp tục hành trình và trạng thái bài`)

## 1. Summary of Changes

Implemented the mobile home continuation target resolution and campaign lesson/event path status integration for **Learning Path 2.0** (`HISTORY_MAIN`):

1. **Home Continuation Target (`LearnerDashboardScreen`)**:
   - Replaced the legacy `eventsListProvider` -> `page.milestones.first` fallback with `_resolveJourneyTarget(path)` consuming `learnerLearningPathProvider`.
   - When no active lesson attempt (`progress.inProgress`) exists, the Home Hero Banner and "Bài học hôm nay" section resolve the continuation target from `currentByPeriod[lastPeriodCode]`, falling back to `path.current` / `path.effectiveCurrent` when `lastPeriodCode` is `null` or the period's current pointer is absent.
   - Preserves top priority for active attempts (`progress.inProgress.isNotEmpty` -> `/learning/attempt/{attemptId}`).
   - Displays period progress (`completedLessons/requiredLessons bài học`) and navigates to `/campaign/{eventId}` when a target event is resolved, or `/map` when all periods are completed / loading / error.

2. **Campaign Lesson List Path Status (`CampaignDetailScreen`)**:
   - Replaced the static lesson list in `campaign_detail_screen.dart` with `_CampaignPathLessonListSection`, watching both `eventLessonsProvider(eventId)` and `learnerLearningPathProvider`.
   - Maps each lesson's `LearnerPathStatus` from `path.lessonStatusOf(lesson.id)` (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) and out-of-path lessons (`status == null` -> `'Tự do khám phá'`).
   - Renders both a semantic icon and Vietnamese status label (`labelVi` / `'Tự do khám phá'`) on every lesson card (never relying on color alone).
   - Gates `LOCKED` and `NOT_READY` lessons: tapping shows an explanatory Vietnamese `SnackBar` instead of navigating, while `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, and out-of-path (`null`) lessons navigate to `/learning/lesson/{lessonId}`.

3. **Event Progress Path Status Enrichment (`EventProgressSection`)**:
   - Preserves all existing GAME-04 states (`loading`, `error`, `NOT_CONFIGURED`, `IN_PROGRESS`, `EVENT_COMPLETED`, `EVENT_MASTERED`, policy version banner, and unlocked dossiers CTA).
   - Watches `learnerLearningPathProvider` (non-blocking via `.maybeWhen`) to render the event's path status badge (`pathEvent.status.labelVi` + `'Khám phá tự do'` when `EXPLORATION_ONLY`) and a compact lesson status summary breakdown when the event exists in the learning path.

---

## 2. Files Modified & Synced

### Issue #23 Primary Implementation Files
- `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart`
- `dau-viet-mobile/lib/features/campaign/presentation/campaign_detail_screen.dart`
- `dau-viet-mobile/lib/features/campaign/presentation/widgets/event_progress_section.dart`

### Issue #23 Test Files Updated
- `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`
- `dau-viet-mobile/test/campaign_detail_test.dart`
- `dau-viet-mobile/test/campaign/event_progress_section_test.dart`

### E1 Data Layer Dependency Files (Synced from `feat/issue-21-learning-path`)
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_dto.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_dtos.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_api_client.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/api_learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/mock_learning_path_repository.dart`
- `dau-viet-mobile/lib/features/learning_path/data/learning_path_providers.dart`

---

## 3. Verification Summary

- **Widget & Unit Tests**:
  - `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`: Verifies `currentByPeriod[lastPeriodCode]` resolution on Home Hero Banner and Today Lesson card, fallback to `path.current` when `lastPeriodCode == null`, completed period handling, and `progress.inProgress` priority.
  - `dau-viet-mobile/test/campaign_detail_test.dart`: Verifies Vietnamese status chips and icons for `LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`, and out-of-path (`null` -> `'Tự do khám phá'`), SnackBar gating on locked/not-ready lessons, and navigation on unlocked lessons.
  - `dau-viet-mobile/test/campaign/event_progress_section_test.dart`: Verifies all GAME-04 states remain intact alongside the new learning-path event status badge and lesson breakdown.
- **Static Analysis**:
  - `flutter analyze` on touched mobile files and E1 data layer files passes with zero issues.
- **Scope Isolation**:
  - No files under `lib/features/learning_path/presentation/` (owned by E2 / Issue #22) were modified.

---

## 4. Next Action

- Merge `feat/issue-23-journey-home` **after** `feat/issue-21-learning-path` (E1 data layer) or alongside the Epic E integration branch.
- Since the E1 data layer files (`lib/features/learning_path/data/*`) are identical to `feat/issue-21-learning-path`, git merge / rebase onto `feat/issue-21-learning-path` will resolve cleanly without conflict.
