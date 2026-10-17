# Báo cáo cuối — TASK-0016: Thư viện Bằng chứng & Media + Cấu hình Hoạt động

Ngày: 2026-10-17 · Phạm vi: `dau-viet-admin` + `dau-viet-backend` · Trạng thái: HOÀN THÀNH

## Tóm tắt

Content Admin giờ có thể: tạo/sửa/tìm/lọc bằng chứng lịch sử có nguồn trích dẫn, tải ảnh lên thư viện media, gắn bằng chứng/ảnh vào hoạt động qua bộ chọn trực quan (không nhập UUID), viết phản hồi cho học viên, và dùng đầy đủ các trình soạn hoạt động còn thiếu. Toàn bộ lưu qua hợp đồng draft hiện có `PUT /admin/lessons/{id}/draft` — không thay đổi hợp đồng, không giả lập persistence phía client.

## Kết quả theo tiêu chí chấp nhận (AC)

| AC | Nội dung | Kết quả | Bằng chứng |
|---|---|---|---|
| AC-1 | CRUD bằng chứng + tìm/lọc + approve/archive + đánh dấu thiếu nguồn | ĐẠT | `/evidence` (list/new/[id]), `evidence-table`, `evidence-form` (zod + `expectedRowVersion`), badge "Chưa đủ nguồn" |
| AC-2 | Slice asset backend: upload multipart PNG/JPEG/WebP ≤10MB, sha256, ACTIVE, list/get/serve; lưu local dev | ĐẠT | `AdminAssetController`, `AssetService`, `AssetResponse`, `InvalidAssetUploadException`; `dauviet.assets.dir` trong application.yml |
| AC-3 | Trang `/assets` thay coming-soon: lưới thumbnail, upload, preview | ĐẠT | `assets-library`, `asset-card`, `asset-preview-dialog`, route `/assets` |
| AC-4 | Picker tái dùng; EVIDENCE_SELECT/CER chọn theo eventId của bài học; VIEW_IMAGE chọn ảnh trực quan + preview + caption | ĐẠT | `evidence-ref-picker` (lọc theo `lesson.eventId` truyền qua EditorProps), `asset-picker-dialog` dùng trong `view-image-editor` + `evidence-form` |
| AC-5 | FeedbackPanel nhãn tiếng Việt, key outcome, rỗng → xoá key | ĐẠT | `feedback-panel` tích hợp trong `ActivityCommonFields` (mọi editor); không phát minh trường hint/số lần thử |
| AC-6 | Editor mới HYPOTHESIS_CHOICE, VERIFICATION, REASONING_CONNECT; EXPLORE_MAP vẫn honest-unsupported; READ đa đoạn + evidenceRefs | ĐẠT | 3 editor mới trong EDITORS map; READ thêm `evidenceRefs` picker; EXPLORE_MAP giữ `UnsupportedEditor` |
| AC-7 | Round-trip draft: id + feedback + config tồn tại qua save+reload; khoá lạ được giữ; guard pending-save nguyên | ĐẠT | e2e `evidence-authoring.spec.ts` (save→reload→persist); test pending-save TASK-0015 vẫn xanh |
| AC-8 | Demo Bạch Đằng soạn được đầu-cuối | ĐẠT | fixture/stub seed Bạch Đằng (sự kiện, bằng chứng, asset); e2e soạn READ + gắn bằng chứng + feedback |
| AC-9 | Unit test picker/editor/feedback; e2e journey vs stub có kiểm soát | ĐẠT | 8 test mới (picker 5, feedback 3); spec e2e mới 1; MSW + stub mở rộng evidence/asset |
| AC-10 | Gate xanh: eslint, tsc, vitest, build, playwright; backend compile+test | ĐẠT (xem mục Gates) | Chi tiết dưới |

## Thay đổi chính

### Backend (dau-viet-backend)
- `lesson/api/AdminAssetController.java` (mới): `POST /api/v1/admin/assets` (multipart `file` + `altText` → 201), `GET` list phân trang, `GET /{id}`, `GET /{id}/content` (FileSystemResource, `inline; filename=` đã sanitize).
- `lesson/application/AssetService.java` (mới): whitelist png/jpg/webp, trần 10MB, sha256 checksum, ghi `{id}.{ext}` dưới `dauviet.assets.dir` (mặc định `data/assets`), chống path traversal khi đọc.
- `lesson/api/dto/AssetResponse.java`, `lesson/domain/InvalidAssetUploadException.java` (mới).
- `AssetRepository`: thêm `findAllByStateIn(Collection, Pageable)`.
- `GlobalExceptionHandler`: map `InvalidAssetUploadException` → 400 VALIDATION_ERROR.
- `application.yml`: `dauviet.assets.dir` + `spring.servlet.multipart` 10MB/12MB.
- Lưu trữ local — đúng phạm vi "dev storage, đổi S3 sau giữ nguyên URL".

### Admin (dau-viet-admin)
- `lib/dto/evidence.ts`: `Evidence`, `EvidenceUpsertRequest/Patch`, `AdminAsset`.
- `features/evidence/*`: bảng + form + trang `/evidence`, `/evidence/new`, `/evidence/[id]` (tạo/sửa/phê duyệt/lưu trữ; badge thiếu nguồn).
- `features/assets/*`: `asset-api` (upload multipart, `assetContentSrc` map URL qua `/api/proxy`), `asset-picker-dialog`, `assets-library`, `asset-card`, `asset-preview-dialog`; route `/assets` thay coming-soon.
- `components/ui/dialog.tsx` (mới, Radix), `admin-shell` + `breadcrumbs` + `status-chip` cập nhật.
- Builder: `evidence-ref-picker` (chip + panel tìm/lọc theo sự kiện), `feedback-panel` (outcome-keyed), 3 editor mới, `read-editor` thêm `evidenceRefs`, `view-image-editor` chọn ảnh trực quan + preview; `eventId` của lesson truyền `builder-page → stage-editor → EditorProps`.
- MSW `handlers.ts` + `fixtures.ts`: evidences/assets CRUD thật theo hợp đồng.
- `scripts/e2e-backend-stub.mjs`: thêm store evidences/assets + endpoint serve PNG 1×1 thật — stub KHÔNG giả làm backend, tài liệu trong file nói rõ.

## Gates

| Gate | Kết quả |
|---|---|
| `tsc --noEmit` | Sạch |
| `next lint` | 0 cảnh báo/lỗi |
| `vitest run` | 70/70 (1 flake `lesson-wizard` timeout 5s khi chạy song song — pass 3/3 khi chạy riêng, có sẵn từ trước) |
| `next build` | Thành công, 19 route |
| `playwright` | 9/9 khi chạy từng spec; chạy full-suite liên tục bị flake do cold-compile `next dev` (cùng hiện tượng đã ghi ở TASK-0015) |
| Backend `mvn compile` | BUILD SUCCESS |
| Backend `mvn test` | 154/155 pass; `DauVietApplicationTests` lỗi môi trường — cần Docker cho Testcontainers Postgres, máy không có Docker (không liên quan thay đổi) |

## Giới hạn / điểm chưa làm (trung thực)

- **EXPLORE_MAP** vẫn `UnsupportedEditor`: hợp đồng marker chưa định nghĩa ở backend → không bịa.
- **Hint / số lần thử** không có trong schema backend → không phát minh field; feedback chỉ ghi các outcome-key mà `AbstractActivityHandler.feedbackFor` tra cứu.
- **Proxy BFF cap 2 MiB**: `/api/proxy` giới hạn body; file >2MiB sẽ 413 dù backend cho 10MB — hạn chế kiến trúc BFF hiện có, cần route upload riêng khi mở rộng (đã ghi trong plan).
- `DauVietApplicationTests` cần Docker để xanh hoàn toàn.
- Upload asset lưu đĩa local (`data/assets`) — phục vụ dev; production đổi backend sau, URL content giữ nguyên.

## Câu hỏi còn mở

- Có nên nâng proxy cap hoặc thêm route upload riêng cho media >2MiB không (quyết định kiến trúc BFF)?
- EXPLORE_MAP: khi nào backend chốt marker schema thì làm editor sau.
