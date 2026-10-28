# Planner-Researcher Report — TASK-0022 (Issue #22)

- **Role**: `planner` (executed via `PlannerResearcher` scout subagent)
- **Task**: `TASK-0022` — `[E2] Mobile: man Chon thoi ky va Hanh trinh thoi ky`
- **Plan**: `plans/261028-issue-22-period-journey/plan.md`

## Findings
1. **E1 Data Layer Alignment**:
   - Consumes `learning_path_dto.dart` (`PathNodeType`, `LearnerPathStatus`, `PathContentStatus`, `ParticipationType`, `PeriodProgressDto`, `LearningPathChapterDto`, `LearningPathEventNodeDto`, `LearningPathLessonNodeDto`, `LearningPathDto`) and `learning_path_providers.dart` (`learningPathRepositoryProvider`, `learningPathProvider`).
2. **Issue #22 Requirements Coverage**:
   - **Group by ERA (`Nhóm theo ERA`)**: `PeriodSelectionScreen` groups `PERIOD` chapters under `ERA` chapters.
   - **Hide 1-item tier (`Ẩn tầng chỉ có 1 mục`)**:
     - `PeriodSelectionScreen`: Hides ERA header tier when `<= 1` ERA group exists.
     - `PeriodJourneyScreen`: Hides `PHASE` header tier when the period has `<= 1` phase group; hides multi-lesson sub-list on an event card when `event.lessons.length <= 1`.
   - **Touch on period entry (`Gọi touch khi vào thời kỳ`)**: Calls `touchPeriod(periodCode)` (`POST /api/v1/me/learning-path/periods/{periodCode}/touch`) when entering a period.
   - **Tap event opens `CampaignDetailScreen` (`Bấm event mở campaign_detail_screen`)**: Tapping an event card navigates to `CampaignDetailScreen(eventId: event.eventId)` (via `GoRouter` `/campaign/:eventId` or `Navigator.push` fallback).
   - **AC-1 (`Trạng thái có icon + nhãn, không chỉ dùng màu`)**: `PathStatusBadge` renders both an `Icon` and a Vietnamese text label wrapped in `Semantics` for all 6 `LearnerPathStatus` values (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`).
   - **AC-2 (`Widget test`)**: `dau-viet-mobile/test/learning_path/period_journey_screen_test.dart` verifies all requirements and edge cases.
3. **Scope Safety**:
   - Zero modifications to `dau-viet-mobile/lib/features/map/`.
