---
title: "[E2] Mobile: Màn Chọn thời kỳ và Hành trình thời kỳ (Issue #22)"
description: "Mobile presentation layer for Learning Path 2.0: Period Selection screen (grouped by ERA, hide 1-item tier) and Period Journey screen (touch period on entry, phase/event progression, tap event opens CampaignDetailScreen, accessible icon+label status badges, widget tests)."
status: complete
priority: P1
effort: 4h
branch: feat/issue-22-period-journey
tags: [mobile, learning-path, presentation, widget-test, issue-22]
created: 2026-10-28
---

# [E2] Mobile: Màn Chọn thời kỳ và Hành trình thời kỳ (Issue #22)

## 1. Goal & Scope

Implement the Flutter mobile presentation layer for **Learning Path 2.0** (`HISTORY_MAIN`) under `dau-viet-mobile/lib/features/learning_path/presentation/`, consuming the `E1` data layer (`lib/features/learning_path/data/`).

### Hard Constraints (from Issue #22)
- **Scope**: `dau-viet-mobile/lib/features/learning_path/presentation/` (plus widget tests under `dau-viet-mobile/test/learning_path/`).
- **Non-goal / Forbidden**: **DO NOT modify any file in `dau-viet-mobile/lib/features/map/`.**
- **Accessibility (AC-1)**: Every status badge/indicator (period, event, lesson) MUST render both an **Icon** and a **text label** (plus `Semantics`), never relying on color alone.
- **Verification (AC-2)**: Comprehensive widget tests covering all behaviors and states (`loading`, `error` + retry, `empty`, ERA grouping, single-item tier hiding, `touchPeriod` invocation on period entry, event tap opening `CampaignDetailScreen`, and icon+label status badges).

## 2. Target Files

### Presentation Layer (`dau-viet-mobile/lib/features/learning_path/presentation/`)
1. `path_status_badge.dart`
   - Reusable, accessible badge widget for `LearnerPathStatus` (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) and `PathContentStatus` / `ParticipationType`.
   - Always pairs a distinct `IconData` with a Vietnamese text label and `Semantics(label: ...)`:
     - `MASTERED`: `Icons.workspace_premium_rounded` + `"Tinh thông"`
     - `COMPLETED`: `Icons.check_circle_rounded` + `"Đã hoàn thành"`
     - `IN_PROGRESS`: `Icons.timelapse_rounded` + `"Đang học"`
     - `AVAILABLE`: `Icons.play_circle_fill_rounded` + `"Sẵn sàng"`
     - `LOCKED`: `Icons.lock_rounded` + `"Đang khóa"`
     - `NOT_READY`: `Icons.hourglass_empty_rounded` + `"Đang biên soạn"`
2. `period_selection_screen.dart` (Màn Chọn thời kỳ — route `/journey`)
   - Consumes `learningPathProvider` (`AsyncValue<LearningPathDto>`).
   - Groups `PERIOD` chapters under their parent `ERA` chapters (`nodeType == PathNodeType.era`).
   - **Single-item tier hiding ("ẩn tầng chỉ có 1 mục")**:
     - If the path has `<= 1` ERA group (e.g., flat v1 path or single-ERA path), hides the ERA header tier and renders the `PERIOD` cards directly.
     - If an ERA has `>= 2` ERAs in the path, renders each ERA section header (title, periodLabel/years, description) followed by its child `PERIOD` cards.
     - Also if an ERA has only 1 child item whose title duplicates the ERA or if a child sub-tier has only 1 item, avoids redundant nested chrome.
   - Displays per-period progress (`PeriodProgressDto`: `completedEvents/requiredEvents`, `completedLessons/requiredLessons`, `percent%`), status badge (icon + label), and `"Đang theo học"` badge when `period.code == path.lastPeriodCode`.
   - When the learner taps a `PERIOD` card:
     - Calls `touchPeriod(period.code)` via repository/controller (`POST /api/v1/me/learning-path/periods/{periodCode}/touch`).
     - Opens `PeriodJourneyScreen(periodCode: period.code)` (via `GoRouter` `/journey/${period.code}` if configured, or `Navigator.push` fallback so standalone widget tests work seamlessly).
3. `period_journey_screen.dart` (Màn Hành trình thời kỳ — route `/journey/:periodCode`)
   - Accepts `periodCode` (and optional `initialPath` / callbacks).
   - **Calls `touchPeriod(periodCode)` on entry** (`initState` / when `periodCode` changes, idempotent with tap handler so entering via deep-link `/journey/:periodCode` or direct widget mount always triggers `touchPeriod`).
   - Renders the selected `PERIOD` header (title, `periodLabel`, description, progress summary, status badge with icon + label).
   - **Single-item tier hiding ("ẩn tầng chỉ có 1 mục")**:
     - Inspects `PHASE` sub-chapters (`nodeType == PathNodeType.phase`, `parentId == period.chapterId`).
     - If the `PERIOD` has `<= 1` phase group (0 phases or only 1 phase), **hides the `PHASE` tier header** and renders the ordered `EVENT` nodes directly.
     - If the `PERIOD` has `>= 2` phase groups, renders each `PHASE` header and its events.
     - Within an event node card, if `event.lessons.length <= 1`, hides the multi-lesson sub-tree list; if `event.lessons.length > 1`, displays the lessons list with icon + status label per lesson.
   - **Tap Event opens `CampaignDetailScreen` ("bấm event mở campaign_detail_screen")**:
     - Tapping an event card navigates to `CampaignDetailScreen(eventId: event.eventId)` (via `GoRouter` `/campaign/${event.eventId}` when route is registered, or `MaterialPageRoute(builder: (_) => CampaignDetailScreen(eventId: event.eventId))` fallback).
4. `learning_path_presentation.dart`
   - Barrel file exporting `period_selection_screen.dart`, `period_journey_screen.dart`, and `path_status_badge.dart`.

### Tests (`dau-viet-mobile/test/learning_path/`)
- `dau-viet-mobile/test/learning_path/period_journey_screen_test.dart`
  - Widget tests verifying:
    1. Grouping `PERIOD` chapters by `ERA` on `PeriodSelectionScreen` (3 ERAs, multiple PERIODs).
    2. Hiding single-item hierarchy tiers ("ẩn tầng chỉ có 1 mục"):
       - Single ERA in path -> ERA tier header hidden.
       - Period with 0 or 1 `PHASE` -> PHASE tier header hidden; Period with 2 `PHASE`s -> PHASE tier headers shown.
    3. Calling `touchPeriod(periodCode)` when entering a period (both via tapping a period on `PeriodSelectionScreen` and mounting `PeriodJourneyScreen`).
    4. Tapping an event in `PeriodJourneyScreen` opens `CampaignDetailScreen` with the tapped `eventId`.
    5. AC-1: Status badges for all `LearnerPathStatus` values (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) render both an `Icon` and a text label (never color-only).
    6. Loading, error + retry (`THỬ LẠI`), and empty/not-found period states.

## 3. Acceptance Criteria Mapping

| AC | Requirement | Verification |
|---|---|---|
| AC-1 | Trạng thái có icon + nhãn, không chỉ dùng màu | `PathStatusBadge` renders `Icon` + text label + `Semantics`; verified in `period_journey_screen_test.dart` across all statuses |
| AC-2 | Nhóm theo ERA; ẩn tầng chỉ có 1 mục; gọi touch khi vào thời kỳ; bấm event mở `campaign_detail_screen`; Widget test | Verified in `period_journey_screen_test.dart` via `flutter test` and `flutter analyze` |
