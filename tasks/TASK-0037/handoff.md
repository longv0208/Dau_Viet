# Handoff — TASK-0037 (Issue #45: Kiểm thử End-to-End toàn diện từ Admin đến Học viên & Đánh giá UX / Ý nghĩa học tập)

## 1. Tóm tắt kết quả
Đã thực hiện kiểm thử **End-to-End (E2E) toàn diện** xuyên suốt 4 luồng từ **Admin khởi tạo nội dung (`dau-viet-admin` -> `dau-viet-backend`)** đến **Học viên trải nghiệm hành trình học tập (`dau-viet-mobile` -> `dau-viet-backend`)**, kết hợp đánh giá và khắc phục triệt để các điểm nghẽn về UI/UX, tính liền mạch dữ liệu và ý nghĩa sư phạm lịch sử.

## 2. Các vấn đề phát hiện trong quá trình E2E & Bản sửa lỗi đã triển khai

### A. Phía Admin Web (`dau-viet-admin`) & Backend (`dau-viet-backend`) — Luồng 1, 2, 3
1. **Đồng bộ 2 chiều giữa Địa điểm Di tích độc lập (`/map-locations`) và Không gian Sự kiện (`/events/[id]?tab=info`):**
   - *Vấn đề:* Tạo địa điểm tại `/map-locations` và liên kết sự kiện qua `PUT /admin/map-locations/{id}/events` chỉ ghi vào bảng `map_location_events` mà không cập nhật `map_locations.event_id`, khiến tab `Thông tin & địa điểm` của Sự kiện (`GET /admin/events/{eventId}/map-locations`) không hiển thị địa điểm đó.
   - *Khắc phục:* Cập nhật `AdminMapLocationService.replaceEvents` đồng bộ `event_id` theo sự kiện `PRIMARY` (hoặc sự kiện đầu tiên), mở rộng `AdminMapLocationService.list(eventId)` & `load(eventId, locationId)` đọc cả liên kết trong `map_location_events`, đồng thời bổ sung banner điều hướng nhanh sang `/map-locations?eventId=${eventId}` trong `MapLocationsSection`.
2. **Sửa lỗi mất chọn địa điểm khi phân trang trên `/map-locations` (`map-locations-page.tsx`):**
   - *Vấn đề:* `selectedLocation` trước đây chỉ tìm trong mảng 8 bản ghi của trang hiện tại (`locations.find(...)`). Khi tạo địa điểm mới hoặc mở `/map-locations?highlight=<id>` trong DB có $\ge 8$ địa điểm khiến bản ghi nằm ở trang khác, `selectedLocation` bị `null` làm khóa cứng các Tab `2. Sự kiện`, `3. Mở khóa`, `4. Media`.
   - *Khắc phục:* Bổ sung `selectedDetailQuery` (`GET /admin/map-locations/${selectedId}`) và cập nhật cache khi tạo/sửa để luôn nạp đầy đủ thông tin địa điểm đang chọn bất kể vị trí trang; đổi mặc định `unlockRuleMode` khi tạo mới thành `"NONE"` (hiển thị rõ `"Mở sẵn (0 bài)"`) và cảnh báo khi chọn `ANY`/`ALL` nhưng chưa tích bài học nào.
3. **Hướng dẫn thứ tự xuất bản & Kiểm tra Chính sách hoàn thành (`event-overview-tab.tsx`, `publish-readiness-card.tsx`, `policy-editor.tsx`, `policy-publish-dialog.tsx`, `dossier-picker-dialog.tsx`):**
   - Bổ sung chỉ dẫn rõ ràng trên `EventOverviewTab` và `PublishReadinessCard` rằng cần bấm **"Xuất bản sự kiện"** trước khi xuất bản Bài học, Địa điểm di tích và Chính sách hoàn thành.
   - Khóa nút `"Kiểm tra"` trong `PolicyEditor` khi chính sách nháp mới chưa được lưu; hiển thị chi tiết `validation.errors` và khóa nút xác nhận xuất bản trong `PolicyPublishDialog` khi `validation.valid === false`; thêm liên kết tạo/xuất bản Hồ sơ mới trong `DossierPickerDialog`.
4. **Giữ ngữ cảnh điều hướng Bằng chứng, Ánh xạ 4 Nhóm Dấu vết & Tối ưu Lesson Builder (`use-evidence-submit.ts`, `evidence-editor-page.tsx`, `evidence-form-sections.tsx`, `lesson-wizard.tsx`, `use-builder.ts`, `builder-page.tsx`, `draft-local-validator.ts`, `evidence-ref-picker.tsx`, `builder-types.ts`):**
   - Giữ nguyên tham số `?return=` sau khi tạo bằng chứng mới và thêm nút `"← Quay lại Sự kiện"` trên `EvidenceEditorPage` để sau khi bấm `"Phê duyệt"` (`APPROVED`), Admin quay về Sự kiện chỉ với 1 cú nhấp; bổ sung khung hướng dẫn ánh xạ 4 Nhóm Dấu vết Điều tra (*Hiện vật, Địa hình/Bản đồ, Nhân vật/Lời kể, Cổ thư*).
   - `LessonWizard` tự động chuyển sang Bước 2 khi đã có `?event=` và mở thẳng `/lessons/${id}/builder` sau khi tạo bài học; `makeActivity` mặc định `required: true` và điền sẵn câu phản hồi tiếng Việt chuẩn để không chặn thao tác lưu nháp và giúp `EVIDENCE_SELECT` hiển thị ngay trong dropdown của `VERIFICATION`/`CER_CHOICE`.

### B. Phía Học viên (`dau-viet-mobile`) & Learning Engine (`dau-viet-backend`) — Luồng 4
1. **Rõ ràng mục tiêu số lượng chọn & Gợi ý chấm điểm ở `EVIDENCE_SELECT` (`LearnerProjectionService.java`, `SelectionHandlers.java`, `evidence_select_renderer.dart`, `attempt_dtos.dart`):**
   - `LearnerProjectionService` chiếu thêm `expectedCount` (số lượng `acceptedEvidenceIds` khi `graded: true`) vào `config` an toàn cho học viên (vẫn ẩn tuyệt đối `acceptedEvidenceIds`), và `SelectionHandlers` trả thêm `totalItems = accepted.size()`. Nhờ đó `EvidenceSelectRenderer` hiển thị chính xác `"THU THẬP DẤU VẾT · CHỌN ĐỦ 3 DẤU VẾT CHÍNH XÁC (Đã chọn 2/3)"` và `InlineGradingHint` báo đúng `"Đúng 2/3 mục"` khi trả lời thiếu (`PARTIAL`).
2. **Liên thông Bằng chứng xuyên suốt 4 Giai đoạn Tư duy Lịch sử & Chống kẹt `VERIFICATION` (`ReasoningHandlers.java`, `hypothesis_renderer.dart`, `verification_renderer.dart`, `cer_choice_renderer.dart`, `cer_renderer.dart`, `activity_renderer.dart`):**
   - Cả Backend (`VerificationHandler.evidenceGiven`) và 4 Renderer (`HypothesisRenderer`, `VerificationRenderer`, `CerChoiceRenderer`, `CerRenderer`) đều tự động quét `priorOutputs` để lấy `selectedEvidenceIds` từ bước `EVIDENCE_SELECT` khi bài học không khai báo thủ công `priorEvidenceSource`/`evidenceSource`.
   - `VerificationRenderer` truyền đầy đủ `lastEvaluation`, yêu cầu học viên chọn 1 trong 3 kết luận kiểm chứng (`Chứng thực` / `Một phần` / `Mâu thuẫn`) trước khi bấm `"KIỂM CHỨNG"`, và `VerificationHandler` giới hạn tối đa 2 lượt thử tại chỗ nếu Admin không cấu hình nhánh quay lại (`onPartial`/`onContradicted`), triệt tiêu nguy cơ kẹt bài học vô hạn.
3. **Tính liền mạch khi chuyển tiếp màn hình & Mở khóa (`learner_dashboard_screen.dart`, `lesson_player_screen.dart`, `lesson_result_screen.dart`, `unlocked_location_banner.dart`, `period_journey_screen.dart`):**
   - Chuẩn hóa toàn bộ CTA hành trình học tập trên `LearnerDashboardScreen` điều hướng về `/journey` (hoặc `/journey/:periodCode`) thay vì `/map`; sửa lỗi tràn bố cục (`RenderFlex overflow`) trên màn nhỏ/font rộng.
   - `UnlockedLocationBanner` ("Xem địa điểm") điều hướng sang `/map?locationId=:id` để mở ngay `LocationProfileSheet` trên Bản đồ Dấu Ấn; `LessonResultScreen` ("TIẾP TỤC HỌC") điều hướng về `/campaign/:eventId` (hoặc `/journey/:periodCode`) và bổ sung nút `"Xem Bộ sưu tập tư liệu →"` (`/collection`).
   - Khi hoàn thành bài học, `LessonPlayerScreen` invalidate đồng bộ `mapLocationsProvider`, `mapLocationDetailProvider` (đảm bảo tư liệu `UNLOCKED_ONLY` hiển thị ngay lập tức), `eventProgressProvider`, `collection*`, `dossier*`, và `learningPath*`.

## 3. Bằng chứng Kiểm chứng (Verification Evidence)
- **Live E2E Execution (Luồng 1 -> Luồng 4):** [`tasks/TASK-0037/e2e_audit_report.json`](./e2e_audit_report.json)
  - Tạo & xuất bản Sự kiện `Chiến thắng Phòng tuyến Như Nguyệt 1077`, 4 Assets, 4 Bằng chứng (`APPROVED`), 1 Hồ sơ (`PUBLISHED`), 1 Địa điểm Bản đồ kèm 2 media (`PUBLIC_PREVIEW` + `UNLOCKED_ONLY`), Bài học A (gắn Map), Bài học B (không gắn Map), Chính sách hoàn thành (`PUBLISHED`), và Lộ trình `HISTORY_MAIN` v6 (`PUBLISHED`).
  - Học viên hoàn thành Bài học A (kiểm chứng phản hồi `PARTIAL`, `Revise Loop` ở bước Kiểm chứng, trừ `-10` Thể lực khi trả lời `INCORRECT`, nhận `+100 EXP` & `+50 Điểm Sử Ký`, thu thập 3 bằng chứng, mở khóa Địa điểm & tư liệu `UNLOCKED_ONLY`) -> Bài học B tự động mở khóa (`AVAILABLE`) -> hoàn thành Bài học B (không hiện banner địa điểm rỗng, hoàn thành Sự kiện `EVENT_MASTERED 2/2`, mở khóa Hồ sơ `Thái úy Lý Thường Kiệt`).
- **Backend Tests (`dau-viet-backend`):** `.\mvnw.cmd test` -> **592/592 tests PASS** (`BUILD SUCCESS`).
- **Admin Web Tests (`dau-viet-admin`):** `npx vitest run` -> **52/52 test files PASS**; `npx tsc --noEmit` -> **0 lỗi** trên toàn bộ các file sửa đổi.
- **Mobile Learner Tests (`dau-viet-mobile`):** `flutter analyze` -> **0 issues** trên toàn bộ các file sửa đổi; `flutter test --no-pub test/dashboard/ test/learning/ test/learning_path/ test/campaign/ test/map/` -> **358/358 tests PASS**.
- **Git Hygiene:** `git diff --check` -> sạch (0 lỗi whitespace/conflict).

## 4. Hành động tiếp theo (Next Action)
- Chờ người dùng review và ủy quyền commit/push trên nhánh `feat/issue-45-e2e-flows-ux-audit`.
