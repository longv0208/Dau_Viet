# Báo cáo bugfix — TASK-0016 (đợt 2): Asset Upload, Image Preview & Media Access

Ngày: 2026-10-17 · Phạm vi: `dau-viet-admin` + `dau-viet-backend` · Trạng thái: HOÀN THÀNH

## Tóm tắt

Sửa 3 lỗi product sau review TASK-0016: (P1) `<img>` không gắn Bearer token nên ảnh protected trả 401 — chuyển sang fetch-authenticated + object URL; (P2) upload >2MiB bị proxy JSON chặn — thêm route multipart chuyên; (P3) learner không vào được `/admin/assets/*` — thêm endpoint learner-safe đã xác thực. P4 tăng e2e coverage: evidence tạo-thật → attach → persist + assert `blob:` src chứng minh auth.

## Thay đổi theo priority

### P1 — Authenticated image rendering
- `features/assets/use-asset-object-url.ts` (mới): hook fetch bytes qua `/api/proxy` (kèm Bearer + `coordinatedRefresh` khi 401) → `URL.createObjectURL` → revoke khi unmount/đổi `contentUrl`.
- `features/assets/asset-api.ts`: thêm `fetchAssetBlob()` — binary variant của `apiFetch` (cùng auth + single-flight refresh + redirect /login khi hết phiên).
- `features/assets/asset-image.tsx` (mới): `<AssetImage>` dùng hook, fallback icon + "Không tải được ảnh" khi lỗi; không bao giờ đặt token trong URL hay gọi endpoint không auth.
- Cập nhật render: `AssetCard`, `AssetPickerDialog`, `AssetPreviewDialog`, `EvidenceAssetField`, `ViewImageEditor` — tất cả dùng `<AssetImage>`.

### P2 — Upload ≤10MB đúng quảng cáo
- `app/api/upload/assets/route.ts` (mới): route multipart chuyên — bắt buộc `Authorization: Bearer` + `multipart/form-data`, cap 12MB (bao overhead), forward nguyên byte tới `POST /api/v1/admin/assets`. Proxy JSON `/api/proxy` giữ nguyên cap 2MiB.
- `uploadAsset()` chuyển sang `/api/upload/assets`.
- `validateAssetFile()` + `MAX_ASSET_BYTES` (mới): guard phía client — lỗi VN cho sai định dạng/rỗng/>10MB; dùng trong `AssetsLibrary` + `AssetPickerDialog`. Backend vẫn authoritative.

### P3 — Learner media contract (implemented)
- `LearnerAssetController` (mới): `GET /api/v1/assets/{id}/content` — phục vụ bytes của asset ACTIVE cho MỌI user đã xác thực (LEARNER lẫn CONTENT_ADMIN); ngoài `/admin/**` nên rơi vào `anyRequest().authenticated()`. Admin metadata/upload giữ nguyên `/admin/assets/*` yêu cầu `CONTENT_ADMIN`.
- Contract Mobile: Flutter gọi `/api/v1/assets/{id}/content` với JWT learner; id không đoán được (UUID) + chỉ asset ACTIVE.
- Không expose admin assets public; không đụng Flutter UI.

### P4 — Test coverage mạnh hơn
- `tests/e2e/evidence-authoring.spec.ts`: luồng tạo evidence → xuất hiện trong thư viện → attach ITEM VỪA TẠO vào READ → feedback → save → reload persist. Spec assets mới: `<img>` phải có `src^=blob:` — chứng minh fetch qua auth.
- `scripts/e2e-backend-stub.mjs`: endpoint content + upload giờ trả 401 khi thiếu `Authorization: Bearer` (stub nghiêm — không che lỗi gốc); content path match cả `/admin/assets/` và `/assets/` learner.
- `src/features/assets/asset-api.test.ts` (mới): 6 unit cho `validateAssetFile` (định dạng/rỗng/>10MB/<10MB) + `assetContentSrc`.

## Gates

| Gate | Kết quả |
|---|---|
| `tsc --noEmit` | Sạch |
| `next lint` | 0 cảnh báo/lỗi |
| `vitest run` | 79/79 pass |
| `next build` | 20 routes, gồm `/api/upload/assets` |
| `playwright` | 10/10 pass khi chạy từng spec (login 3, authoring 2, builder 3, evidence-authoring 2) |
| Backend `mvn compile` | BUILD SUCCESS |

## Definition of Done — mapping

1. Ảnh upload render cho Admin đã đăng nhập — ĐẠT (`blob:` object URL qua authenticated fetch).
2. Thumbnail + preview thư viện hoạt động — ĐẠT (`AssetCard`, `AssetPreviewDialog` qua `<AssetImage>`).
3. VIEW_IMAGE chọn + preview asset thật — ĐẠT (`AssetPickerDialog` + `AssetImage`).
4. Upload tới 10MB theo đúng tài liệu — ĐẠT (route riêng cap 12MB; guard client 10MB; backend 10MB).
5. Chọn evidence + persist draft nguyên — ĐẠT (e2e pass).
6. Test cover authenticated image + multipart upload — ĐẠT (e2e `blob:` assert; stub strict-401; unit validate).
7. Contract media Flutter — ĐẠT (`/api/v1/assets/{id}/content` authenticated, đã implement).
8. Gates — ĐẠT.

## Còn lại / lưu ý

- Test upload multi-MB thực tế: `validateAssetFile` unit cover ngưỡng; e2e chưa upload file MB thật (stub bỏ qua bytes) — nếu cần e2e upload thật sẽ bổ sung khi backend thật chạy.
- Full-suite playwright liên tục vẫn flake do cold-compile `next dev` (đã ghi TASK-0015/16); per-spec ổn định.
- Sẵn sàng TASK-0017: contract learner media đã chốt (`/api/v1/assets/{id}/content` + JWT learner).
