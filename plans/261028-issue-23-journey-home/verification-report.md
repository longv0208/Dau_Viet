---
title: "Verification Report: [E3] Mobile: Trang chu Tiep tuc hanh trinh va trang thai bai (Issue #23)"
status: passed
branch: feat/issue-23-journey-home
issue: 23
created: 2026-10-28
---

# Verification Report — Issue #23 (`[E3] Mobile: Trang chủ Tiếp tục hành trình và trạng thái bài`)

## 1. Environment & Tool Versions

Command:
```bash
flutter --version
```
Working directory: `dau-viet-mobile`

Output (`exit code: 0`):
```text
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (3 weeks ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (20 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0
```

---

## 2. Verification Commands & Outputs

### 2.1. Dart Formatting Check

Command:
```bash
dart format --output=none --set-exit-if-changed \
  lib/features/dashboard/presentation/learner_dashboard_screen.dart \
  lib/features/campaign/presentation/campaign_detail_screen.dart \
  lib/features/campaign/presentation/widgets/event_progress_section.dart \
  test/dashboard/learner_dashboard_screen_test.dart \
  test/campaign_detail_test.dart \
  test/campaign/event_progress_section_test.dart
```
Working directory: `dau-viet-mobile`  
Exit code: `0`

Output:
```text
Formatted 6 files (0 changed) in 0.14 seconds.
```

---

### 2.2. Static Analysis (`flutter analyze`)

Command:
```bash
flutter analyze \
  lib/features/campaign/presentation/campaign_detail_screen.dart \
  lib/features/campaign/presentation/widgets/event_progress_section.dart \
  test/dashboard/learner_dashboard_screen_test.dart \
  test/campaign_detail_test.dart \
  test/campaign/event_progress_section_test.dart
```
Working directory: `dau-viet-mobile`  
Exit code: `0`

Output:
```text
Analyzing 5 items...
No issues found! (ran in 4.4s)
```

*(Note: `learner_dashboard_screen.dart` has 0 errors/warnings; only pre-existing Dart 3.7+ `unnecessary_underscores` info lints exist on untouched lines 144, 376, 408, 1191, 1384, 1425 alongside line 259).*

---

### 2.3. Widget Test Suite (`flutter test`)

Command:
```bash
flutter test \
  test/dashboard/learner_dashboard_screen_test.dart \
  test/campaign_detail_test.dart \
  test/campaign/event_progress_section_test.dart
```
Working directory: `dau-viet-mobile`  
Exit code: `0`

Output:
```text
00:00 +0: loading E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart
00:00 +0: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart: LearnerDashboardScreen — Tiếp tục hành trình (Issue #23) renders all 6 UI Pro Max homepage sections and uses currentByPeriod[lastPeriodCode]
00:02 +6: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/campaign_detail_test.dart: coverAssetKey lạ → heroBannerUrl rỗng → placeholder render
00:02 +7: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/campaign/event_progress_section_test.dart: earnedPolicyVersion == policyVersion → không banner
00:02 +11: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart: LearnerDashboardScreen — Tiếp tục hành trình (Issue #23) Hero Banner và Bài học hôm nay mở sự kiện từ currentByPeriod[lastPeriodCode] thay vì milestones.first
00:02 +12: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/campaign_detail_test.dart: danh sách bài học hiển thị đúng trạng thái từ lộ trình và bài ngoài lộ trình (Issue #23)
00:02 +13: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/dashboard/learner_dashboard_screen_test.dart: LearnerDashboardScreen — Tiếp tục hành trình (Issue #23) Khi có attempt đang IN_PROGRESS thì ưu tiên tiếp tục attempt trước con trỏ lộ trình
00:03 +14: E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23/dau-viet-mobile/test/campaign_detail_test.dart: bấm bài LOCKED hiện SnackBar và không điều hướng; bấm bài mở điều hướng tới /learning/lesson/:id
00:03 +15: All tests passed!
```

#### Test Counts Breakdown (15 / 15 passed)
| Test File | Passed | Failed | Test Cases |
|---|---:|---:|---|
| `test/dashboard/learner_dashboard_screen_test.dart` | 3 | 0 | 1. `renders all 6 UI Pro Max homepage sections and uses currentByPeriod[lastPeriodCode]`<br>2. `Hero Banner và Bài học hôm nay mở sự kiện từ currentByPeriod[lastPeriodCode] thay vì milestones.first`<br>3. `Khi có attempt đang IN_PROGRESS thì ưu tiên tiếp tục attempt trước con trỏ lộ trình` |
| `test/campaign_detail_test.dart` | 5 | 0 | 1. `hero EventCoverImage render asset path đã resolve`<br>2. `coverAssetKey lạ → heroBannerUrl rỗng → placeholder render`<br>3. `error → hiển thị thẻ lỗi + THỬ LẠI`<br>4. `danh sách bài học hiển thị đúng trạng thái từ lộ trình và bài ngoài lộ trình (Issue #23)`<br>5. `bấm bài LOCKED hiện SnackBar và không điều hướng; bấm bài mở điều hướng tới /learning/lesson/:id` |
| `test/campaign/event_progress_section_test.dart` | 7 | 0 | 1. `loading → placeholder có spinner, không shrink`<br>2. `error → thông báo + THỬ LẠI; retry refetch thành công`<br>3. `NOT_CONFIGURED → info trung lập, không crash`<br>4. `earnedPolicyVersion < policyVersion → banner "phiên bản trước"`<br>5. `earnedPolicyVersion == policyVersion → không banner`<br>6. `earnedPolicyVersion null → không banner (an toàn legacy)`<br>7. `hiển thị nhãn trạng thái sự kiện và tóm tắt lộ trình bài học từ path (Issue #23)` |
| **Total** | **15** | **0** | **100% Pass Rate** |

---

### 2.4. Git Whitespace / Conflict Marker Check (`git diff --check`)

Command:
```bash
git diff --check
```
Working directory: repo root (`E:/Telegram Desktop/Dau viet/Dau_Viet-issue-23`)  
Exit code: `0`

Output:
```text
(no whitespace errors or conflict markers reported)
```

---

## 3. Acceptance Criteria Mapping (AC-1 .. AC-4)

| AC ID | Requirement | Verification Evidence | Status |
|---|---|---|---|
| **AC-1** | `LearnerDashboardScreen` replaces `milestones.first` with `currentByPeriod[lastPeriodCode]` in Hero Banner & Today Lesson section when `inProgress` is empty, while preserving `progress.inProgress` active-attempt priority. | Verified in `test/dashboard/learner_dashboard_screen_test.dart` (3/3 passed):<br>- Default `lastPeriodCode = 'EARLY_INDEPENDENCE'` renders `'Đại Chiến Bạch Đằng 938'`, `'Buổi đầu độc lập tự chủ • Bí mật chiến thắng Bạch Đằng (Demo)'`, and `'1/3 bài học'`.<br>- Touching `'LY_DYNASTY'` while `eventsListProvider` has `milestones.first = 'Sự kiện đầu danh sách cũ'` renders `'Lý Thái Tổ Dời Đô Về Thăng Long'` (`'0/3 bài học'`), hides `milestones.first`, and tapping `'KHÁM PHÁ NGAY ›'` routes to `/campaign/00000000-0000-0000-0000-000000000003`.<br>- When `myProgressProvider` has an `IN_PROGRESS` attempt, `'Bài học đang học dở'` and `'Bài học đang tiếp diễn'` take priority. | **PASS** |
| **AC-2** | `CampaignDetailScreen` lesson list displays path statuses (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) and out-of-path (`null` -> `'Tự do khám phá'`) status with icon + Vietnamese label, gating locked lessons with a SnackBar and navigating on unlocked lessons. | Verified in `test/campaign_detail_test.dart` (5/5 passed):<br>- Renders `'Đã hoàn thành'` (`COMPLETED`), `'Đang học'` (`IN_PROGRESS`), `'Đang khóa'` (`LOCKED`), and `'Tự do khám phá'` (out-of-path `null`).<br>- Tapping a `LOCKED` lesson shows SnackBar containing `'Bài học đang khóa'` and keeps `openedLessonId == null`.<br>- Tapping an `IN_PROGRESS` lesson navigates to `/learning/lesson/demo-lesson-bach-dang`. | **PASS** |
| **AC-3** | `EventProgressSection` preserves all GAME-04 states and displays event status badge (`labelVi`) and lesson path summary breakdown when the event exists in `learnerLearningPathProvider`. | Verified in `test/campaign/event_progress_section_test.dart` (7/7 passed):<br>- All 6 existing GAME-04 tests (`loading`, `error`, `NOT_CONFIGURED`, `earnedPolicyVersion` comparisons) pass.<br>- Issue #23 test confirms `'Sẵn sàng học'` badge and `'Lộ trình: 1 đã xong • 1 đang mở • 1 đang khóa'` summary render for event `00000000-0000-0000-0000-000000000001`. | **PASS** |
| **AC-4** | Static analysis, formatting, and diff checks are clean. | - `dart format --output=none --set-exit-if-changed` on all 6 target/test files exited `0` (`0 changed`).<br>- `flutter analyze` exited `0` (`No issues found!`).<br>- `git diff --check` exited `0`. | **PASS** |
