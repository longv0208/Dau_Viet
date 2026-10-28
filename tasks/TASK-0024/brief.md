# TASK-0024 — [E4] Mobile: Bản đồ Di sản và hồ sơ địa điểm (Issue #24)

## Mục tiêu
Cập nhật tính năng Bản đồ Di sản (`lib/features/map/**`) và Dòng thời gian (`lib/features/timeline/presentation/timeline_screen.dart`) trên ứng dụng Flutter (`dau-viet-mobile`) theo kiến trúc Learning Path & Heritage Locations 2.0:
1. **Xóa `_metaBySlugOrId` và chế độ timeline dựa trên map**:
   - Xóa toàn bộ bảng hardcode slug/UUID (`_metaBySlugOrId`, `_resolveMeta`) và chế độ xem timeline nhúng trong `HistoricalMapScreen`.
2. **Bản đồ Di sản dùng API v2**:
   - Cập nhật `MapLocationDto`, `MapApiClient`, `MapRepository`, `ApiMapRepository`, `MockMapRepository`, và `map_providers.dart` theo hợp đồng `GET /api/v1/map/locations` và `GET /api/v1/map/locations/{id}`.
   - Địa điểm đang khóa (`LOCKED`) vẫn hiển thị tên và ghim trên bản đồ nếu `visibility` là công khai (`PUBLIC` / `ALWAYS_VISIBLE`); ẩn nếu `HIDDEN_UNTIL_UNLOCKED`.
3. **Màn Hồ sơ địa điểm (`LocationProfileScreen`)**:
   - Hiển thị chi tiết địa điểm di sản với 3 nhóm tab động: **Ảnh** (`IMAGE_2D`, `PANORAMA_360`), **Video** (`DOCUMENTARY_CLIP`, `AUDIO_GUIDE`), và **Tư liệu** (mô tả lịch sử, sự kiện liên kết, bài học mở khóa).
   - Tự động ẩn mọi tab rỗng (không có dữ liệu).
4. **Timeline chuyển sang `/journey`**:
   - `TimelineScreen` tự động điều hướng sang `/journey` khi route `/journey` khả dụng trong `GoRouter`.

## Phạm vi
- `dau-viet-mobile/lib/features/map/**`
- `dau-viet-mobile/lib/features/timeline/presentation/timeline_screen.dart`
- `dau-viet-mobile/test/map/**`
- `dau-viet-mobile/test/timeline_events_test.dart`

## Tiêu chí nghiệm thu (Acceptance Criteria)
- **AC-1**: Không còn hardcode slug/UUID.
- **AC-2**: Địa điểm khóa vẫn hiện tên và ghim nếu `visibility = PUBLIC`.
