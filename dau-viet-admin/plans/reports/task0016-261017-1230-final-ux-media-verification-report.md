# Báo cáo — TASK-0016 (đợt 3): Final Product UX & Media Verification

Ngày: 2026-10-17 · Phạm vi: `dau-viet-admin` · Trạng thái: HOÀN THÀNH

## 1. Đã sửa

### P1 — Asset picker UX sau upload
- `asset-picker-dialog.tsx`: upload xong → `onSelect(created)` + `onOpenChange(false)` — auto-chọn ảnh vừa upload, tránh user ở trang 2+ phải tìm lại.
- `assets-library.tsx`: upload xong → `setPage(0)` + `setPreview(created)` — về trang đầu và mở preview ngay, không mất context.
- Error path giữ nguyên (`setUploadError(toUserMessage(err))`).

### P2 — Media E2E thực
- `evidence-authoring.spec.ts` viết lại test `media: upload PNG → preview decodes → attach to VIEW_IMAGE → save → reload persists`:
  - Upload PNG thật qua `/assets` (`setInputFiles` với buffer PNG 1x1 valid).
  - Preview auto-mở → assert `src` là `blob:` + `complete && naturalWidth > 0` (decode thật, không chỉ shape).
  - Ảnh xuất hiện trong grid thư viện.
  - Builder → CONTEXT stage → VIEW_IMAGE → picker chọn asset vừa upload → editor hiển thị preview (blob + decode).
  - Save → reload → filename + preview blob vẫn còn.

### P3 — Verify multipart >2MiB
- `src/app/api/upload/assets/route.test.ts` (mới, 6 tests):
  - 401 khi thiếu Bearer; 400 khi không multipart; 502 khi upstream fail.
  - Forward multipart 3 MB → backend (chứng minh >2MiB OK).
  - >12MB → 413 trước khi gọi backend.
  - Strip `set-cookie` + `transfer-encoding` khỏi response.
- `src/app/api/proxy/[...path]/route.test.ts` (mới, 2 tests): body >2MiB → 413; ≤2MiB forward.
- `asset-api.test.ts` đã cover `validateAssetFile`: reject gif/empty/>10MB, accept <10MB — unsupported formats + oversize được chặn client trước khi lên route.

### P4 — Stub trung thực hơn
- `e2e-backend-stub.mjs`: upload parse multipart, extract file payload giữa `\r\n\r\n` và boundary đóng → lưu `_bytes`; content endpoint trả `_bytes` thay vì canned PNG — `<img>` decode assertion giờ phụ thuộc bytes thật browser gửi lên.

## 2. Admin giờ có thể

- Upload ảnh trong `/assets` → ngay lập tức thấy preview ảnh vừa upload (không cần tìm trang).
- Upload ảnh ngay trong picker → tự động chọn + đóng picker → form VIEW_IMAGE/evidence nhận asset đó.
- Upload file 2–10 MB thành công (route riêng); >10MB/sai định dạng thấy lỗi VN rõ; file 10–12MB bị route chặn; backend giữ quyền quyết cuối.
- Ảnh thumbnail + preview trong library, picker, VIEW_IMAGE editor, evidence form đều render qua authenticated blob fetch — reload không mất.
- Lưu draft có ảnh → reload → ảnh và `imageAssetId` nguyên vẹn.

## 3. Kết quả test

| Gate | Kết quả |
|---|---|
| `tsc --noEmit` | Sạch |
| `next lint` | 0 cảnh báo/lỗi |
| `vitest run` | **87/87 pass** (+8 tests route upload/proxy) |
| `next build` | OK, 20 routes |
| `playwright` | **11/11 pass** full suite (login 3, authoring 2, builder 3, evidence-authoring 3) |

E2e cover: evidence create→library→attach→feedback→persist; seeded thumbnail blob-render; upload→preview-decode→VIEW_IMAGE-attach→save→reload.

## 4. Còn lại / lưu ý

- **Backend thật chưa chạy được**: Docker daemon tắt, Postgres chưa cài xong → real-backend upload smoke test CHƯA chạy; chỉ mới qua stub. Cần 1 pass với backend thật + Postgres trước khi sign-off production.
- `safeName` trùng giữa `LearnerAssetController` và `AdminAssetController` — nit, để nguyên.
- `assetContentSrc` export nhưng chưa ai gọi (5 dòng) — giữ để dùng lại.
- Mobile learner sẽ gọi trực tiếp `/api/v1/assets/{id}/content` với Bearer — chưa xác nhận qua BFF riêng; cần chốt trước khi TASK-0017 build Flutter.

## 5. Sẵn sàng đóng TASK-0016?

**Có** — với điều kiện accept stub-backed evidence thay real-backend cho upload/decode path, và ghi nhận follow-up:
- Chạy 1 lần upload thật trên Spring Boot + Postgres trước production.
- Chốt contract learner media với Flutter team (direct Bearer vs learner BFF).

Không commit/push — để user review tay.
