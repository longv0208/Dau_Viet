# TASK-0037: Issue #45 — Kiểm thử End-to-End toàn diện từ Admin đến Học viên & Đánh giá UX / Ý nghĩa học tập

## Mục tiêu
Thực hiện kiểm thử **End-to-End (E2E) toàn diện** kết hợp **Đánh giá & Tinh chỉnh Trải nghiệm Người dùng (UI/UX & Pedagogical Audit)** xuyên suốt 4 luồng theo [Issue #45](https://github.com/longv0208/Dau_Viet/issues/45):
1. **Luồng 1 (Admin — Sự kiện & Học liệu):** Tạo Sự kiện lịch sử mới (`coverAssetKey`, `backgroundConfig` + Mobile Preview), tải lên Assets, tạo & duyệt 4 nhóm Bằng chứng (`APPROVED`), tạo & xuất bản Hồ sơ lịch sử (`PUBLISHED`, liên kết `event_dossiers`), tạo Địa điểm di tích trên Bản đồ (`map_locations` với media `PUBLIC_PREVIEW` / `UNLOCKED_ONLY`).
2. **Luồng 2 (Admin — Bài học có/không gắn Bản đồ & Chính sách hoàn thành):**
   - Bài học A (gắn mở khóa Địa điểm di tích trên `/map`, chuỗi hoạt động 4 giai đoạn tư duy lịch sử: *Khám phá & Thu thập bằng chứng -> Đặt giả thuyết -> Kiểm chứng -> Kết luận CER / Dựng lại sự kiện*): validate, preview, publish.
   - Bài học B (không gắn với bất kỳ `map_locations` nào): validate, preview, publish.
   - Cấu hình và xuất bản Chính sách hoàn thành Sự kiện (`requiredLessonIds`, `optionalLessonIds`) + xuất bản Sự kiện.
3. **Luồng 3 (Admin — Lộ trình học tập `HISTORY_MAIN`):** Nhân bản/tạo bản nháp mới của lộ trình `HISTORY_MAIN`, cấu hình Thời kỳ (`PERIOD`) với `backgroundConfig`, gắn Sự kiện (`REQUIRED`) và sắp xếp thứ tự Bài học A + Bài học B, kiểm toán (`validate`) 0 lỗi và xuất bản (`publish`).
4. **Luồng 4 (Học viên — Hành trình học tập & Mở khóa trên `dau-viet-mobile`):**
   - Khám phá `/dashboard` -> `/journey` -> `/journey/:periodCode` (Dynamic Heritage Background, tiến độ thời kỳ, timeline sự kiện & bài học).
   - Học Bài học A (có gắn Bản đồ): trả lời sai (phản hồi, gợi ý, trừ Thể lực, revise loop), trả lời đúng qua chặng, hoàn thành -> màn Kết quả nhận EXP, Điểm Sử Ký, Bằng chứng (`/me/collection`), thông báo Mở khóa Địa điểm Di tích -> sang `/map` mở `LocationProfileSheet` xác nhận địa điểm và tư liệu `UNLOCKED_ONLY` đã mở khóa.
   - Quay lại hành trình: Bài học A `Đã hoàn thành`, Bài học B tự động mở khóa (`Sẵn sàng học`) không cần reload thủ công. Học và hoàn thành Bài học B (không gắn Bản đồ) -> màn Kết quả không hiển thị banner địa điểm lỗi/rỗng, cập nhật hoàn thành Sự kiện, mở khóa Hồ sơ lịch sử (`dossiers`) và cập nhật tiến độ Thời kỳ.

## Kế hoạch chi tiết
Xem [`plans/261030-issue-45-e2e-flows-ux-audit/plan.md`](../../plans/261030-issue-45-e2e-flows-ux-audit/plan.md).

## Ánh xạ Kiểm chứng (AC → Check)
| AC | Kiểm tra | Kỳ vọng |
|---|---|---|
| AC-1 | Chạy E2E Luồng 1–3 trên Admin Web + API Backend | Tạo & xuất bản thành công Sự kiện, Assets, 4 Bằng chứng, Hồ sơ, Địa điểm Bản đồ, Bài học A (gắn Map), Bài học B (không gắn Map), Chính sách hoàn thành, và Lộ trình `HISTORY_MAIN` |
| AC-2 | Chạy E2E Luồng 4 trên Mobile/Web Learner + API Backend | Học trọn vẹn Bài học A & B; mở khóa tuần tự, cộng thưởng EXP/Điểm Sử Ký, thu thập bằng chứng, mở khóa Địa điểm `/map` (Bài A) + `UNLOCKED_ONLY` media, và mở khóa Hồ sơ sự kiện (Bài B) |
| AC-3 | Kiểm tra UI/UX Admin & Learner + Unit/Widget tests | Có chỉ dẫn thứ tự xuất bản rõ ràng, phân nhóm 4 dấu vết bằng chứng, sửa lỗi phân trang `/map-locations`, giữ ngữ cảnh điều hướng `?return=`, hiển thị rõ số lượng cần chọn ở `EVIDENCE_SELECT` |
| AC-4 | Kiểm tra Lesson Player & chuyển tiếp màn hình | Bằng chứng thu thập ở Chặng 1 được liên thông sang Giả thuyết / Kiểm chứng / Kết luận CER; `VERIFICATION` hiển thị rõ phản hồi và không bị soft-lock; hoàn thành bài học tự động invalidate state để mở khóa bài kế tiếp mượt mà |
| AC-5 | `mvnw test`, `npx vitest run`, `flutter test`, và E2E smoke test thực tế | Toàn bộ test suites liên quan pass và có báo cáo/ảnh chụp kiểm chứng E2E |
