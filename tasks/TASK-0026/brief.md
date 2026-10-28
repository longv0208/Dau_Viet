# TASK-0026 — [F1] Tích hợp end-to-end, rà soát UX, cập nhật tài liệu (Issue #26)

## Mục tiêu
Hoàn tất tích hợp toàn trình (End-to-End), rà soát các trạng thái UX và cập nhật đồng bộ tài liệu cho Epic **Luồng học theo thời kỳ và Bản đồ Di sản 2.0**:
1. Kết nối điều hướng GoRouter (`/journey`, `/journey/:periodCode`, `/heritage/:locationId`) và kiểm chứng luồng `Trang chủ -> Thời kỳ -> Sự kiện -> Bài -> Kết quả có địa điểm -> Bản đồ` trên backend thật (PostgreSQL) và Flutter mobile.
2. Đảm bảo đủ trạng thái UX (`rỗng`, `đang tải`, `khóa`, `lỗi`) và chuyển đổi qua lại giữa các thời kỳ không làm mất tiến độ đã học.
3. Chốt quyết định kiến trúc (ADR-009) về thời điểm và điều kiện gỡ bỏ 2 cột deprecated `map_locations.event_id` và `map_locations.unlock_lesson_id`.
4. Cập nhật đầy đủ `docs/*`, `docs/project-changelog.md`, `docs/development-roadmap.md`.

## Phạm vi
- Chỉ sửa lỗi tích hợp (`dau-viet-mobile/lib/app/router.dart`, `dau-viet-mobile/lib/core/widgets/main_bottom_nav.dart`), bổ sung kiểm thử E2E (`dau-viet-backend/src/test/java/com/dauviet/path/LearningFlowHeritageEndToEndIT.java`, `dau-viet-mobile/test/learning_path/learning_flow_e2e_integration_test.dart`) và cập nhật tài liệu (`docs/*`, `docs/project-changelog.md`, `docs/development-roadmap.md`).
- Không chạm vào các file thuộc phạm vi riêng của Issue #24 (`lib/features/map/**`, `timeline_screen.dart`) và Issue #25 (`attempt_dtos.dart`, `lesson_player_screen.dart`, `lesson_result_screen.dart`, `unlocked_location_banner.dart`).

## Tiêu chí nghiệm thu (Acceptance Criteria)
- **AC-1**: Luồng Trang chủ -> Thời kỳ -> Sự kiện -> Bài -> Kết quả có địa điểm -> Bản đồ chạy trên backend thật.
- **AC-2**: Đủ trạng thái rỗng, đang tải, khóa, lỗi.
- **AC-3**: Đổi thời kỳ và quay lại không mất tiến độ.
