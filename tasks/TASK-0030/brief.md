# TASK-0030 — Issue #36: Học trực tiếp trên Bản đồ Dấu Ấn & Mở khóa Di tích sau khi học

## Mục tiêu

Đưa trục học chính của learner vào màn **Bản Đồ Dấu Ấn** (`/map`) thay vì các màn danh sách rời rạc (`/journey` Period Selection + Period Journey). Nguồn đường đi trên canvas lấy từ `GET /api/v1/me/learning-path` (không còn `map_locations`); địa điểm di tích trở thành lớp phụ mở khóa sau khi học — hiện như **ghim vệ tinh** cạnh nút sự kiện, tap → `LocationProfileSheet`.

## Phạm vi

- Mobile (`dau-viet-mobile`): `features/map/`, `features/learning_path/`, router, bottom-nav, dashboard/timeline/banner/result CTAs, lesson_player refresh hook, tests.
- Admin (`dau-viet-admin`): copy trong `unlocked-locations-card.tsx` + tab `unlock` của `map-locations-page.tsx` (không đổi API/mutation).
- Backend/Flyway: **không đổi** — contract hiện đủ (`learning-path` tree + `newlyUnlockedLocations` + `GET /map/locations?eventId=`/`?periodCode=` + `POST .../periods/{code}/touch`).

## Quyết định đã chốt (user confirm 2026-10-29)

1. `/journey` + `/journey/:periodCode` → `redirect` sang `/map`/`/map?period=`; **xóa hẳn** `PeriodSelectionScreen`/`PeriodJourneyScreen`.
2. Bottom-nav tab 1 label = **"Hành trình"** (route `/journey` → redirect `/map`).
3. Ghim di tích = **vệ tinh inline** trên canvas cạnh node sự kiện (không màn riêng).

## Acceptance criteria

- **AC-1**: Xem lộ trình Thời kỳ → Sự kiện → Bài học và bấm Bắt đầu/Tiếp tục học trực tiếp trên Bản đồ Dấu Ấn.
- **AC-2**: Bài học không gắn di tích vẫn hiển thị và mở khóa bài tiếp liền mạch trên bản đồ.
- **AC-3**: Hoàn thành bài có gắn di tích → mở khóa, banner trên `LessonResultScreen`, ghim vệ tinh → `LocationProfileSheet` trên bản đồ.
- **AC-4**: Tests luồng mới pass; `flutter analyze` sạch; admin lint/test sạch.

## Plan

`plans/261029-issue-36-map-learning/plan.md` — trục learning-path, period chapters, EventActionSheet, satellite pins, deep-links, invalidation, tests.

## Lưu ý task id

Branch này bắt đầu là `tasks/TASK-0028`; khi merge, `main` đã có `TASK-0028` (Issue #35) và `TASK-0029` (Issue #29) → đổi sang **`TASK-0030`** để tránh đụng ID.
