# TASK-0014 — Báo cáo cuối: Admin Web Authoring (Sự kiện + Bài học)

Ngày: 2026-10-17 · Chủ sở hữu: claude · Rủi ro: high-risk · Trạng thái: hoàn thành triển khai, chờ phê duyệt

## Người tạo nội dung có thể làm gì

Một Content Admin đăng nhập có thể, hoàn toàn qua giao diện tiếng Việt và lưu trữ thật trên Spring Boot `/api/v1`:

- Duyệt danh sách sự kiện lịch sử (tiêu đề, thời kỳ, năm, trạng thái, tags), tìm kiếm theo tiêu đề, lọc theo trạng thái, phân trang.
- Tạo sự kiện mới qua form có slug tự gợi ý từ tiêu đề (bỏ dấu tiếng Việt → kebab-case), sửa sự kiện hiện có, nhận cảnh báo khi rời trang có thay đổi chưa lưu.
- Duyệt danh sách bài học (tiêu đề, sự kiện gắn kèm, trạng thái, đã/chưa xuất bản), lọc theo sự kiện + trạng thái + từ khoá.
- Tạo bài học qua wizard 4 bước: chọn sự kiện → chọn khung bài học (template thật từ `/admin/lesson-templates`) → nhập thông tin cơ bản (tiêu đề, câu hỏi trung tâm, danh sách mục tiêu động) → xác nhận và lưu bản nháp.
- Mở lại bản nháp, chỉnh sửa tiêu đề/câu hỏi/mục tiêu, lưu lại với khoá lạc quan `expectedRowVersion` (nhận thông báo rõ khi bị sửa đồng thời — 409).

## Màn hình đã hoàn thành

| Route | Nội dung |
|---|---|
| `/events` | Danh sách + tìm kiếm + lọc trạng thái + phân trang |
| `/events/new` | Form tạo sự kiện (slug tự gợi ý, tags động, validation) |
| `/events/[id]` | Form sửa sự kiện + optimistic-lock |
| `/lessons` | Danh sách + lọc sự kiện/trạng thái + tìm kiếm |
| `/lessons/new` | Wizard 4 bước (hỗ trợ `?event=<id>` chọn sẵn) |
| `/lessons/[id]` | Trình sửa thông tin cơ bản + thẻ sự kiện/khung + "Sắp triển khai" cho Stage Builder |

## Thao tác persist thật

- `POST /admin/events`, `PATCH /admin/events/{id}` (kèm `expectedRowVersion`).
- `POST /admin/lessons` (gửi `objectivesJson` dạng JSON array string, `draftJson:"{}"`), `PATCH /admin/lessons/{id}` (kèm `expectedRowVersion`).
- `GET /admin/events` (phân trang, `q`, `status`, `sort=updatedAt,desc`), `GET /admin/events/{id}`.
- `GET /admin/lessons` (phân trang, `q`, `status`, `eventId`), `GET /admin/lessons/{id}`, `GET /admin/lesson-templates` (List thuần, không phân trang — đúng contract).

Không có trường JSON thô nào lộ ra UI; `objectivesJson` được serialize/parse trong form; không có ô nhập UUID — mọi liên kết chọn qua card/select.

## Kịch bản demo Bạch Đằng

`tests/e2e/authoring.spec.ts` chạy đúng kịch bản: đăng nhập → `/lessons/new` → chọn "Trận Bạch Đằng 938" → chọn khung "Điều tra sự kiện" → nhập tiêu đề "Bí mật chiến thắng Bạch Đằng" + câu hỏi trung tâm + 1 mục tiêu → "Lưu bản nháp" → điều hướng tới `/lessons/<uuid>` → reload cứng → dữ liệu vẫn còn (stub giữ in-memory). Test thứ hai tạo sự kiện "Chiến thắng Điện Biên Phủ" qua form và kiểm slug tự gợi ý `chien-thang-dien-bien-phu`.

## Sửa sau review (P2)

- `/events/[id]` hiện có nút **"+ Tạo bài học cho sự kiện này"** dẫn tới `/lessons/new?event=<id>` (wizard tự chọn sẵn sự kiện) — khép kín luồng event → lesson.
- Wizard bước 2 hiển thị `EmptyState` "Chưa có khung bài học khả dụng" + hướng dẫn liên hệ quản trị hệ thống khi `/admin/lesson-templates` trả mảng rỗng.
- Wizard áp `useUnsavedChangesGuard(isDirty || step > 1)` — cùng cơ chế cảnh báo của các editor, chặn cả điều hướng nội bộ lẫn reload/đóng tab khi đã nhập liệu.

## Tính năng chưa hoàn thiện / ngoài phạm vi

- Stage Builder, trình sửa hoạt động, evidence, upload media, UI xuất bản/lưu trữ, preview, danh sách phiên bản — tất cả hiển thị "Sắp triển khai".
- `draftJson` hiện luôn gửi `"{}"`; Stage Builder (TASK-0015) sẽ sở hữu trường này.
- Đổi khung bài học (templateId) chỉ cho phép khi DRAFT theo backend — UI hiển thị tên khung read-only.
- Upload ảnh bìa chưa có: trường `coverAssetKey` nhập key thủ công kèm ghi chú.

## Kết quả test/build thực tế

| Gate | Lệnh | Kết quả |
|---|---|---|
| Unit/component | `npx vitest run` | 10 file, 36/36 pass |
| Typecheck | `npx tsc --noEmit` | sạch |
| Lint | `npm run lint` | 0 warning (sau khi xoá 2 import thừa) |
| Build | `npm run build` | pass, 17 routes |
| E2E | `npx playwright test` | 5/5 pass (3 login + 2 authoring, stub `node:http` :8081) |

Lưu ý trung thực: Playwright chạy trên stub `scripts/e2e-backend-stub.mjs` (in-memory, bắt chước đúng contract) — KHÔNG phải backend Spring Boot thật. Smoke test trên backend thật vẫn chưa chạy được trên máy này (Docker daemon tắt, không có Postgres khả dụng) — đây vẫn là khoảng trống evidence trước khi sign-off production, giữ nguyên từ TASK-0013.

## Sẵn sàng cho TASK-0015

- `draftJson` đã được truyền xuyên suốt create/load (hiện `"{}"`) — Stage Builder chỉ cần thay editor, không đụng contract.
- `AdminLessonDetail`/`objectivesJson`/`parseObjectives` đã có sẵn để mở rộng.
- Route shell `/lessons/[id]` có chỗ đặt card "Giai đoạn & hoạt động" sẵn sàng thay bằng Stage Builder thật.
- Pattern form (RHF + zod + `applyServerFieldErrors` + `unsaved-changes-guard` + `expectedRowVersion`) tái sử dụng trực tiếp cho activity/evidence editors.

## Vi phạm/hạn chế đã biết

- Không có CSRF token (chấp nhận được sau `SameSite=Lax`, hardening ở task sau).
- Lọc sự kiện ở `/lessons` tải tối đa 100 sự kiện (`size=100`) — đủ cho quy mô nội dung hiện tại; nếu vượt cần combobox tìm kiếm.
- AC-3: cột "template" và "updatedAt" chưa có ở `/lessons` vì `AdminLessonSummaryResponse` của backend không trả 2 field này — cần mở rộng summary DTO phía server hoặc điều chỉnh AC.
- `event-form.tsx` (~320 LOC) và `lesson-wizard.tsx` (~380 LOC) vượt soft-cap 200 LOC — tách step components ở refactor sau; hiện vẫn mạch lạc, dễ đọc.
