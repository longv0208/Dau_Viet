# TASK-0028 — Issue #36: Học trực tiếp trên Bản đồ Dấu Ấn

## Bối cảnh
`/map` (HistoricalMapScreen) vẽ đường đi từ `map_locations` → bài học không gắn di tích "vắng mặt". `/journey` (PeriodSelectionScreen/PeriodJourneyScreen) là danh sách chữ tách rời đi qua `CampaignDetailScreen`. Issue #36 hợp nhất: **Bản đồ Dấu Ấn = trục học** lấy `GET /api/v1/me/learning-path` làm nguồn; di tích là lớp phụ mở khóa sau khi học (ghim vệ tinh).

## Quyết định đã chốt
1. `/journey` → redirect `/map` (`/journey/:periodCode` → `/map?period=`); xóa 2 screen cũ.
2. Bottom-nav tab 1 label "Hành trình"; `/journey` prefix về tab 1.
3. Di tích đã mở = ghim vệ tinh inline cạnh node sự kiện trên canvas → `LocationProfileSheet`.

## Phạm vi
Mobile (chính), Admin (copy tùy chọn), Docs. **Backend Java/Flyway: không đổi.**

## Chi tiết & AC
Xem `plans/261029-issue-36-map-learning/plan.md` và `task.json` (AC-1..AC-4).
