---
title: "[E3] Mobile: Trang chu Tiep tuc hanh trinh va trang thai bai (Issue #23)"
description: "Technical implementation plan for Issue #23: LearnerDashboardScreen currentByPeriod[lastPeriodCode] continuation, CampaignDetailScreen & EventProgressSection path-derived lesson status integration, and widget tests."
status: completed
priority: P1
effort: 4h
branch: feat/issue-23-journey-home
tags: [mobile, dashboard, campaign, learning-path, riverpod, issue-23]
created: 2026-10-28
---

# [E3] Mobile: Trang chủ Tiếp tục hành trình và trạng thái bài (Issue #23)

## 1. Goal, Scope & Module Impact

### Goal
Integrate **Learning Path 2.0** (`HISTORY_MAIN`, via E1's `lib/features/learning_path/data/`) into the mobile learner home dashboard (`LearnerDashboardScreen`) and campaign detail experience (`CampaignDetailScreen` + `EventProgressSection`) so that:
1. When no active lesson attempt (`progress.inProgress`) exists, the Home Hero Banner and "Bài học hôm nay" section resolve the learner's continuation target from `currentByPeriod[lastPeriodCode]` (falling back to `path.current` / `path.effectiveCurrent`) instead of hardcoding `eventsListProvider` -> `page.milestones.first`.
2. In `CampaignDetailScreen` and `EventProgressSection`, the event's lesson list and progress header reflect each lesson's `LearnerPathStatus` (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) from `learnerLearningPathProvider`, while allowing out-of-path lessons (`status == null`) to be freely accessed.

### Scope (`## Phạm vi`)
- **Primary Issue #23 Target Files**:
  - `dau-viet-mobile/lib/features/dashboard/presentation/learner_dashboard_screen.dart`
  - `dau-viet-mobile/lib/features/campaign/presentation/campaign_detail_screen.dart`
  - `dau-viet-mobile/lib/features/campaign/presentation/widgets/event_progress_section.dart`
- **Data Dependency (E1 - Issue #21)**:
  - `dau-viet-mobile/lib/features/learning_path/data/` (`learning_path_dto.dart`, `learning_path_dtos.dart`, `learning_path_api_client.dart`, `learning_path_repository.dart`, `api_learning_path_repository.dart`, `mock_learning_path_repository.dart`, `learning_path_providers.dart`)
- **Test Files**:
  - `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`
  - `dau-viet-mobile/test/campaign_detail_test.dart`
  - `dau-viet-mobile/test/campaign/event_progress_section_test.dart`

### Module Impact & Risk Classification
- **Affected module**: `dau-viet-mobile` (`mobile` only — no backend or admin changes).
- **Risk level**: **Normal** (UI state wiring + Riverpod provider consumption; no auth/payment/schema migrations, preserves all existing GAME-04 `EventProgressSection` states and `inProgress` active-attempt priority).
- **Merge isolation**: Does not touch `lib/features/learning_path/presentation/` (owned by E2 / Issue #22).

---

## 2. E1 Data Layer Symbols Consumed

From `package:dau_viet_mobile/features/learning_path/data/learning_path_providers.dart` and `learning_path_dto.dart`:
- `learnerLearningPathProvider`: `FutureProvider<LearningPathDto>` watching `authSessionProvider` and fetching `GET /api/v1/me/learning-path` (or `MockLearningPathRepository` when `ApiConfig.useMock` is enabled).
- `LearningPathDto`:
  - `lastPeriodCode`: `String?`
  - `currentByPeriod`: `Map<String, LearningPathCurrentDto?>`
  - `current`: `LearningPathCurrentDto?`
  - `effectiveCurrent`: `LearningPathCurrentDto?` — resolves `(lastPeriodCode != null ? currentByPeriod[lastPeriodCode!] : null) ?? current`
  - `summary`: `LearningPathSummaryDto` (`completedEvents`, `totalRequiredEvents`, `completedLessons`, `totalRequiredLessons`, `lessonFraction`, `eventFraction`)
  - `findEventByNodeId(String? eventNodeId)` -> `LearningPathEventNodeDto?`
  - `findEventById(String? eventId)` -> `LearningPathEventNodeDto?`
  - `findChapterById(String? chapterId)` -> `LearningPathChapterDto?`
  - `findChapterByCode(String? code)` -> `LearningPathChapterDto?`
  - `findLessonById(String? lessonId)` -> `LearningPathLessonNodeDto?`
  - `lessonStatusOf(String lessonId)` -> `LearnerPathStatus?`
  - `lessonStatusMap` -> `Map<String, LearnerPathStatus>`
  - `progressForPeriod(String? periodCode)` -> `PeriodProgressDto?`
- `LearnerPathStatus`:
  - Values: `LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`
  - Helpers:
    - `labelVi`: Vietnamese display label (`'Đang khóa'`, `'Sẵn sàng'`, `'Đang học'`, `'Đã hoàn thành'`, `'Tinh thông'`, `'Chưa sẵn sàng'`)
    - `canStart` / `isUnlocked`: `true` for `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`; `false` for `LOCKED`, `NOT_READY`
    - `isDone`: `true` for `COMPLETED`, `MASTERED`

---

## 3. Detailed Design

### 3.1. `LearnerDashboardScreen` (`learner_dashboard_screen.dart`)

#### Current Behavior (Before E3)
- Watches `myProgressProvider` and `eventsListProvider`.
- When `progress.inProgress` is empty, both `_buildHeroBanner()` and `_buildTodayLessonSection()` fall back to `eventsAsync` and pick `page.milestones.first`.

#### New Behavior (E3)
1. Watch `learnerLearningPathProvider` alongside `myProgressProvider`:
   ```dart
   final learningPathAsync = ref.watch(learnerLearningPathProvider);
   ```
2. **Continuation Resolution Helper** (`_ResolvedJourneyTarget`):
   Given `LearningPathDto path`:
   - Resolve `LearningPathCurrentDto? current = (path.lastPeriodCode != null ? path.currentByPeriod[path.lastPeriodCode!] : null) ?? path.current;` (or `path.effectiveCurrent`).
   - Resolve `LearningPathEventNodeDto? currentEvent = path.findEventByNodeId(current?.eventNodeId);`
   - If `currentEvent == null` (e.g., all events in `lastPeriodCode` completed or `current` is null):
     - Check if `path.lastPeriodCode != null`: look up `periodChapter = path.findChapterByCode(path.lastPeriodCode)` and find the first unlocked/available event or the last event in that period (`path.eventsOfPeriod(periodChapter.chapterId)`), or fall back to the first playable event in `path.allEvents`.
   - Resolve `LearningPathChapterDto? periodChapter`:
     - Prefer `path.findChapterByCode(path.lastPeriodCode)` if `lastPeriodCode != null`, else `path.findChapterById(current?.chapterId)` (walking up to parent `PERIOD` if `current.chapterId` is a `PHASE`).
   - Resolve `LearningPathLessonNodeDto? currentLesson = path.findLessonById(current?.lessonId);`
   - Resolve `PeriodProgressDto? periodProgress = path.progressForPeriod(periodChapter?.code ?? path.lastPeriodCode);`

3. **Hero Banner (`_buildHeroBanner`)**:
   - **Priority 1 (`progress.inProgress.isNotEmpty`)**: Unchanged. Heading `'Bài học đang học dở'`, CTA `'Tiếp tục học →'` navigating to `/learning/attempt/${attempt.attemptId}`.
   - **Priority 2 (`progress.inProgress.isEmpty`)**:
     - Inspect `learningPathAsync`:
       - When `data(path)` resolves a `currentEvent`:
         - Headline: `path.lastPeriodCode != null ? 'Tiếp tục hành trình' : 'Bắt đầu hành trình'` (or keep `'Bắt đầu hành trình'` when `summary.completedLessons == 0 && path.lastPeriodCode == null`, and show period/event context in subtitle if available).
         - Note: Ensure existing widget test expectations or clear Vietnamese labels work seamlessly. Specifically, if `currentEvent != null`, CTA button `'KHÁM PHÁ NGAY ›'` (or `'TIẾP TỤC HÀNH TRÌNH ›'`) navigates to `/campaign/${currentEvent.eventId}`. To preserve backward compatibility with tests checking `find.widgetWithText(DongSonButton, 'KHÁM PHÁ NGAY ›')`, keep the CTA button label `'KHÁM PHÁ NGAY ›'` when no active attempt is in progress, while routing `onTap` to `context.go('/campaign/${currentEvent.eventId}')`!
       - When `currentEvent == null`, `loading`, or `error`:
         - CTA `'KHÁM PHÁ NGAY ›'` navigates to `context.go('/map')`.

4. **Today Lesson Section (`_buildTodayLessonSection`)**:
   - **Priority 1 (`progress.inProgress.isNotEmpty`)**: Unchanged (`'Bài học đang tiếp diễn'`, navigates to `/learning/attempt/${attempt.attemptId}`).
   - **Priority 2 (`progress.inProgress.isEmpty`)**:
     - Use `learningPathAsync.when(...)`:
       - `data(path)`:
         - If `currentEvent != null`:
           - `title`: `currentEvent.title`
           - `subtitle`: If `currentLesson != null && periodChapter != null`, `'${periodChapter.title} • ${currentLesson.title}'` (or `periodChapter?.title ?? currentLesson?.title ?? currentEvent.period ?? 'Hành trình lịch sử'`).
           - `progressFraction`: `periodProgress != null ? (periodProgress.requiredLessons > 0 ? periodProgress.completedLessons / periodProgress.requiredLessons : (periodProgress.percent / 100.0)) : path.summary.lessonFraction`
           - `progressText`:
             - If `periodProgress != null && periodProgress.requiredLessons > 0`: `'${periodProgress.completedLessons}/${periodProgress.requiredLessons} bài học'`
             - Else if `path.summary.totalRequiredLessons > 0`: `'${path.summary.completedLessons}/${path.summary.totalRequiredLessons} bài học'`
             - Else if `progress.completedCount > 0`: `'${progress.completedCount} bài đã hoàn thành'`
             - Else: `'Sẵn sàng bắt đầu'`
           - `onTap`: `() => context.go('/campaign/${currentEvent.eventId}')`
         - If `currentEvent == null` (e.g. entire path or period completed and no events exist):
           - `title`: `periodChapter != null ? 'Đã hoàn thành ${periodChapter.title}' : 'Khám phá Bản đồ Dấu Ấn'`
           - `subtitle`: `'Chọn thời kỳ tiếp theo trên bản đồ'`
           - `progressFraction`: `periodProgress != null ? 1.0 : 0.0`
           - `progressText`: `periodProgress != null ? 'Hoàn thành kỳ này' : 'Chưa bắt đầu'`
           - `onTap`: `() => context.go('/map')`
       - `loading`:
         - `_buildTodayLessonCard(title: 'Đang tải bài học...', subtitle: 'Đang đồng bộ dữ liệu', progressFraction: 0.0, progressText: '—', onTap: () => context.go('/map'))`
       - `error`:
         - Fallback card `'Khám phá Bản đồ Dấu Ấn'`, `onTap: () => context.go('/map')`.

---

### 3.2. `CampaignDetailScreen` (`campaign_detail_screen.dart`) & `EventProgressSection` (`event_progress_section.dart`)

#### Requirement Analysis
- Scope files for Issue #23 are `learner_dashboard_screen.dart`, `campaign_detail_screen.dart`, and `event_progress_section.dart`.
- Note: `LessonListSection` lives in `lib/features/learning/presentation/lesson_list_section.dart` (outside Issue #23's 3 listed scope files).
- How should `CampaignDetailScreen` and `EventProgressSection` render the lesson list with path statuses while keeping strict scope discipline?
  - In `CampaignDetailScreen`:
    - Replace or wrap the lesson list rendering inside `campaign_detail_screen.dart` (e.g. `_CampaignLessonListSection(eventId: eventId)`) that watches both `eventLessonsProvider(eventId)` and `learnerLearningPathProvider`!
    - Let's verify if `campaign_detail_test.dart` or any other test checks `find.byType(LessonListSection)`:
      - `campaign_detail_test.dart` only overrides `attemptRepositoryProvider` and checks `'CHI TIẾT CHIẾN DỊCH'`, `Image`, `Icons.sailing_rounded`, and error retry.
      - `test/learning/lesson_list_test.dart` tests `LessonListSection` directly in isolation.
    - By implementing path-aware lesson list rendering directly in `campaign_detail_screen.dart` (watching `eventLessonsProvider(eventId)` and `learnerLearningPathProvider`), all changes stay 100% within the 3 target files of Issue #23 (`learner_dashboard_screen.dart`, `campaign_detail_screen.dart`, `event_progress_section.dart`)!
  - Let's design both `CampaignDetailScreen`'s path-aware lesson list and `EventProgressSection`'s path status integration in detail:

#### A. Path-Aware Lesson List in `CampaignDetailScreen` (`campaign_detail_screen.dart`)
1. Watch `eventLessonsProvider(eventId)` and `learnerLearningPathProvider`.
2. Also fallback to `pathEvent.lessons` when `eventLessonsProvider(eventId)` returns empty in mock/path-only scenarios, or merge statuses for `LessonListItemDto` items returned by `eventLessonsProvider(eventId)`:
   - For each `LessonListItemDto lesson` from `eventLessonsProvider(eventId)`:
     - Look up `LearnerPathStatus? status = path?.lessonStatusOf(lesson.id);`
     - Determine unlock state:
       - **Out-of-path lesson (`status == null`)**: Unlocked (`canOpen = true`), badge `'Tự do khám phá'` (icon `Icons.explore_outlined`, neutral/green tint).
       - **`AVAILABLE`**: Unlocked (`canOpen = true`), badge `'Sẵn sàng'` (icon `Icons.play_circle_outline_rounded`, heritage green / cinnabar red).
       - **`IN_PROGRESS`**: Unlocked (`canOpen = true`), badge `'Đang học'` (icon `Icons.timelapse_rounded`, amber / cinnabar red).
       - **`COMPLETED`**: Unlocked (`canOpen = true`), badge `'Đã hoàn thành'` (icon `Icons.check_circle_rounded`, heritage green).
       - **`MASTERED`**: Unlocked (`canOpen = true`), badge `'Tinh thông'` (icon `Icons.workspace_premium_rounded`, imperial gold).
       - **`LOCKED`**: Locked (`canOpen = false`), badge `'Đang khóa'` (icon `Icons.lock_outline_rounded`, muted ink/grey).
       - **`NOT_READY`**: Locked (`canOpen = false`), badge `'Chưa sẵn sàng'` (icon `Icons.hourglass_empty_rounded`, muted ink/grey).
3. **Interaction & Accessibility**:
   - Never rely on color alone: every lesson card renders both the status `Icon` and the Vietnamese status chip (`labelVi` / `'Tự do khám phá'`).
   - When `canOpen == true` (`AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, or `status == null`):
     - Tapping the lesson card navigates to `context.push('/learning/lesson/${lesson.id}')`.
   - When `canOpen == false` (`LOCKED` or `NOT_READY`):
     - Card has distinct muted border/background (`DauVietColors.outlineVariant`) and lock/hourglass trailing icon instead of chevron.
     - Tapping shows a `SnackBar` with clear Vietnamese explanation:
       - `LOCKED`: `'Bài học đang khóa. Hãy hoàn thành bài học trước đó trong lộ trình.'`
       - `NOT_READY`: `'Nội dung bài học đang được biên soạn và chưa sẵn sàng.'`
     - Does NOT navigate to `/learning/lesson/...`.

#### B. Path Status Enrichment in `EventProgressSection` (`event_progress_section.dart`)
1. `EventProgressSection` continues to watch `eventProgressProvider(eventId)` and preserves all existing GAME-04 behaviors and tests:
   - `loading` -> `'Đang tải tiến độ sự kiện…'` + `CircularProgressIndicator`
   - `error` -> `'Không tải được tiến độ'` + `'THỬ LẠI'` button
   - `NOT_CONFIGURED` -> `'Sự kiện này chưa có mục tiêu hoàn thành — hãy khám phá các bài học bên dưới.'`
   - `IN_PROGRESS` / `EVENT_COMPLETED` / `EVENT_MASTERED` -> progress bar `${p.requiredLessonsCompleted}/${p.requiredLessonsTotal}`, `earnedPolicyVersion < policyVersion` banner, unlocked dossiers CTA.
2. Additionally, `EventProgressSection` watches `learnerLearningPathProvider` (using `.maybeWhen` so it never blocks or breaks `eventProgressProvider` loading/error states when `learnerLearningPathProvider` is not overridden or still loading):
   - Lookup `final pathEvent = pathAsync.maybeWhen(data: (path) => path.findEventById(eventId), orElse: () => null);`
   - When `pathEvent != null`:
     - Display an event path status badge (icon + `pathEvent.status.labelVi`, plus `'Khám phá tự do'` if `pathEvent.participationType == ParticipationType.EXPLORATION_ONLY`).
     - If `pathEvent.lessons.isNotEmpty`, display a compact lesson status breakdown row/chips (e.g., completed/mastered count, in-progress/available count, locked count) derived from the path node's lessons, even when `p.status == 'NOT_CONFIGURED'` (while keeping the `'chưa có mục tiêu'` text intact so existing `event_progress_section_test.dart` assertions pass).

---

## 4. Edge Cases & Fallback Rules

| Edge Case | Handling Strategy |
|---|---|
| `lastPeriodCode == null` (new learner, never touched a period) | `(path.lastPeriodCode != null ? path.currentByPeriod[path.lastPeriodCode!] : null)` is null -> falls back to `path.current` (first `AVAILABLE` lesson in first period). |
| `currentByPeriod[lastPeriodCode]` is `null` (e.g., learner completed all lessons in `lastPeriodCode`) | Falls back to `path.current`; if `path.current` is also `null` (entire path completed), resolves the `PERIOD` chapter for `lastPeriodCode` and shows its last/first event or `'Đã hoàn thành ...'` card linking to `/map`. |
| Active attempt exists (`progress.inProgress.isNotEmpty`) | Active attempt takes highest priority in both Hero Banner (`'Bài học đang học dở'`, `/learning/attempt/{id}`) and Today Lesson Card (`'Bài học đang tiếp diễn'`). |
| Out-of-path event or lesson (`path.lessonStatusOf(lessonId) == null`) | Lesson is treated as unlocked / free to learn (`'Tự do khám phá'`), tapping navigates to `/learning/lesson/{id}`. |
| `LOCKED` or `NOT_READY` lesson in Campaign Detail | Renders lock/hourglass icon + `'Đang khóa'` / `'Chưa sẵn sàng'` label; tapping is blocked and shows an informative `SnackBar` instead of navigating. |
| `learnerLearningPathProvider` loading or error | Dashboard Hero Banner & Today Lesson gracefully show loading/fallback state (`'KHÁM PHÁ NGAY ›'` -> `/map`); `CampaignDetailScreen` still renders `eventLessonsProvider` lessons (treating statuses as `null`/unlocked while path is unavailable) so network error on path doesn't brick campaign lessons. |
| Mock mode (`USE_MOCK=true`) vs Real API (`USE_MOCK=false`) | `learnerLearningPathProvider` automatically switches between `MockLearningPathRepository` and `ApiLearningPathRepository`. In default widget tests without backend, `learnerDashboardScreen` gracefully handles unauthenticated/mock fallback or overridden providers. |

---

## 5. Acceptance Criteria & Verification Mapping

| AC ID | Requirement | Test File & Assertions | Command |
|---|---|---|---|
| **AC-1** | `LearnerDashboardScreen` replaces `milestones.first` with `currentByPeriod[lastPeriodCode]` in Hero Banner & Today Lesson section when `inProgress` is empty | `dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart`:<br>- Test when `lastPeriodCode = 'EARLY_INDEPENDENCE'` and `currentByPeriod['EARLY_INDEPENDENCE']` points to `evt-bach-dang-938`, Today Lesson displays `'Chiến thắng Bạch Đằng 938'` + period progress `'0/2 bài học'` (NOT `milestones.first` `'Thời Hùng Vương'`), and Hero Banner / Today Lesson tap navigates to `/campaign/evt-bach-dang-938`.<br>- Test fallback when `lastPeriodCode == null` uses `path.current`.<br>- Test fallback when `currentByPeriod[lastPeriodCode] == null` (completed period).<br>- Test `progress.inProgress.isNotEmpty` still prioritizes active attempt. | `flutter test test/dashboard/learner_dashboard_screen_test.dart` |
| **AC-2** | `CampaignDetailScreen` lesson list displays path statuses (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) and out-of-path (`null`) status, gating locked lessons | `dau-viet-mobile/test/campaign_detail_test.dart`:<br>- Test lesson cards display Vietnamese status badges (`'Đã hoàn thành'`, `'Đang học'`, `'Sẵn sàng'`, `'Đang khóa'`, `'Chưa sẵn sàng'`, `'Tự do khám phá'`).<br>- Test tapping `LOCKED` or `NOT_READY` lesson shows SnackBar and does not navigate.<br>- Test tapping `AVAILABLE` or out-of-path (`null`) lesson navigates to `/learning/lesson/{id}`. | `flutter test test/campaign_detail_test.dart` |
| **AC-3** | `EventProgressSection` preserves GAME-04 states and displays event/lesson path status summary when available | `dau-viet-mobile/test/campaign/event_progress_section_test.dart`:<br>- Existing 6 GAME-04 widget tests pass (`loading`, `error`, `NOT_CONFIGURED`, `earnedPolicyVersion < policyVersion`, etc.).<br>- New widget test verifying path event status badge (`'Đang học'` / `'Đã hoàn thành'`) renders when `learnerLearningPathProvider` has matching event. | `flutter test test/campaign/event_progress_section_test.dart` |
| **AC-4** | Static analysis & formatting clean | Zero errors/warnings in `flutter analyze` and `dart format --output=none --set-exit-if-changed` on touched files. | `flutter analyze` |
