# TASK-0022 — [E2] Mobile: Màn Chọn thời kỳ và Hành trình thời kỳ (Issue #22)

## Mục tiêu
Triển khai tầng giao diện (presentation layer) cho Luồng học theo thời kỳ (Learning Path 2.0) trên ứng dụng Flutter (`dau-viet-mobile`):
1. **Màn Chọn thời kỳ (`PeriodSelectionScreen`)**:
   - Nhóm các thời kỳ (`PERIOD`) theo đại thời kỳ (`ERA`).
   - Ẩn tầng phân cấp khi chỉ có 1 mục (ví dụ chỉ có 1 `ERA` thì ẩn tiêu đề tầng `ERA`).
   - Hiển thị tiến độ từng thời kỳ (`periodProgress`), trạng thái kèm icon + nhãn văn bản, và đánh dấu thời kỳ đang theo học (`lastPeriodCode`).
2. **Màn Hành trình thời kỳ (`PeriodJourneyScreen`)**:
   - Tự động gọi `touchPeriod(periodCode)` khi người học vào thời kỳ.
   - Hiển thị chuỗi sự kiện lịch sử trong thời kỳ theo thứ tự sư phạm; ẩn tầng `PHASE` nếu thời kỳ chỉ có 0 hoặc 1 `PHASE`, hiện tầng `PHASE` khi có từ 2 `PHASE` trở lên; ẩn danh sách bài học con khi sự kiện chỉ có <= 1 bài.
   - Bấm vào sự kiện mở `CampaignDetailScreen(eventId: event.eventId)`.
   - Mọi trạng thái (`LOCKED`, `AVAILABLE`, `IN_PROGRESS`, `COMPLETED`, `MASTERED`, `NOT_READY`) đều có cả biểu tượng (`Icon`) và nhãn chữ tiếng Việt rõ ràng (không chỉ phân biệt bằng màu sắc).

## Phạm vi
- Chỉ thêm/sửa trong `dau-viet-mobile/lib/features/learning_path/presentation/` (và đồng bộ tầng `data` từ E1, cùng widget test trong `dau-viet-mobile/test/learning_path/`).
- Tuyệt đối không sửa file trong `dau-viet-mobile/lib/features/map/`.

## Tiêu chí nghiệm thu (Acceptance Criteria)
- **AC-1**: Trạng thái có icon + nhãn, không chỉ dùng màu.
- **AC-2**: Nhóm theo ERA; ẩn tầng chỉ có 1 mục; gọi touch khi vào thời kỳ; bấm event mở `campaign_detail_screen`; có đầy đủ Widget test kiểm chứng.
