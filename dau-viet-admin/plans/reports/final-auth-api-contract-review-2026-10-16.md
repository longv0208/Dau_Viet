# TASK-0013 — Báo cáo cuối: Final Authentication and API Contract Review

Ngày: 2026-10-16
Người thực hiện: Claude
Phạm vi: `dau-viet-admin` — không mở rộng Lesson Builder, không commit/push.

## Phạm vi công việc

Ba ưu tiên từ brief:

- **P1** — Refresh-token concurrency hardening (StrictMode, reload nhanh, đa tab, 401 đồng thời).
- **P2** — Sửa `lessons-table` dùng sai `rowVersion` làm `versionNo`.
- **P3** — Smoke test backend thật khi môi trường cho phép.

## P1 — Refresh concurrency (đã khắc phục)

### Nguyên nhân gốc

Backend (`RefreshTokenService.rotate`) thu hồi token ngay khi rotate; gửi lại
token đã thu hồi bị coi là theft → `revokeFamily` → logout cả chuỗi. Trước sửa:

- `refreshSession()` trong `use-auth.ts` tự fetch `/api/auth/refresh` trực tiếp,
  **không** dùng single-flight — StrictMode gọi effect 2 lần → 2 rotation với
  cùng cookie → request thứ hai replay token đã revoked → logout.
- `api-client.ts` có `refreshInFlight` riêng cho nhánh 401-retry, nhưng không
  chia sẻ với bootstrap → bootstrap + query 401 có thể rotate đồng thời.
- Không có cơ chế nào cho tab thứ hai — hai tab chia sẻ cookie nhưng mỗi tab
  tự rotate → race → một tab chắc chắn replay token cũ.

### Giải pháp (hai lớp, vẫn giữ HttpOnly cookie, không localStorage)

**Client — `src/features/auth/refresh-coordinator.ts` (mới)**

- Một `inFlight: Promise<boolean>` dùng chung cho `coordinatedRefresh()`; cả
  bootstrap lẫn nhánh 401 của `apiFetch` đều đi qua nó → mọi concurrent caller
  await cùng một rotation.
- `BroadcastChannel("dv-auth")`: khi một tab rotate xong nó broadcast
  `accessToken`; tab khác nhận và `authStore.setAccessToken` thay vì tự
  rotate lại cookie → tránh đa tab double-rotate.
- `use-auth.ts::refreshSession()` giờ chỉ delegate tới `coordinatedRefresh()`.
- `api-client.ts` bỏ `refreshInFlight` cục bộ, gọi `coordinatedRefresh()`.

**BFF — `src/app/api/auth/refresh/route.ts`**

- Module-level `Map<sha256(presentedToken), Promise<Rotation>>`. Hai request
  cùng cookie (StrictMode double-effect phía browser, hai tab cùng lúc, reload
  chồng nhau) await cùng một upstream rotate; mỗi request vẫn nhận `Set-Cookie`
  riêng với token mới.
- Key là hash SHA-256 — raw refresh token không bao giờ lưu lâu dài ở server
  memory, chỉ tồn tại trong scope request.
- Entry tự xoá trong `finally` → không rò rỉ memory, không cache xuyên rotate.

### Regression tests (`refresh-coordinator.test.ts`, 6/6 pass)

- N concurrent `coordinatedRefresh()` → đúng 1 upstream call.
- Rotation tiếp theo chạy bình thường sau khi cái trước settle (không kẹt lock).
- BFF 401 → trả `false`, store rỗng (không throw, không loop).
- Lỗi mạng → `false`, không unhandled rejection.
- BroadcastChannel cross-tab: tab nhận token broadcast cập nhật `authStore`.
- `apiFetch` đồng thời bị 401 → đúng 1 rotation, cả hai retry thành công.

## P2 — Lesson version display (đã khắc phục)

`AdminLessonSummaryResponse` chỉ trả `currentVersionId` + `rowVersion`
(optimistic-lock counter) — **không** có `versionNo`. `versionNo` thật nằm
trên `GET /admin/lessons/{id}/versions/current` (`LessonVersionSummary`).

Trước sửa cell render `v#{rowVersion}` — bịa một số version từ counter khoá
lạc quan, sai contract. Sửa `lessons-table.tsx`: cột đổi thành "Xuất bản",
hiển thị trạng thái thật `Đã xuất bản` (kèm `title` tooltip chứa
`currentVersionId`) hoặc `Chưa xuất bản`. Không gọi thêm N+1 endpoint cho
một cột list — giữ KISS; trang chi tiết/versions sau này sẽ query `versionNo`
đúng contract.

## P3 — Real backend smoke test (KHÔNG chạy được trên máy này)

Cố gắng khởi động stack thật, tất cả đường đều bị chặn bởi môi trường:

- Docker daemon không chạy (`failed to connect to the docker API at
  npipe:////./pipe/dockerDesktopLinuxEngine`) → không start được
  `docker-compose` Postgres 16.
- Service `postgresql-x64-18`: không đủ quyền start + khi chạy `pg_ctl` thủ
  công báo `could not open directory ".../PostgreSQL/18/lib"` — installation
  thiếu file, không dùng được.
- Service `PostgreSQL_For_Odoo` trỏ `E:\SU24\ISM302\PostgreSQL` — đường dẫn
  không còn tồn tại (drive dọn dẹp trước đó).
- Không có Postgres nào lắng nghe `:5432`/`:5433`.

**Kết luận trung thực:** smoke test backend thật CHƯA chạy. Playwright e2e
hiện tại dùng `scripts/e2e-backend-stub.mjs` (node:http stub) — chứng minh
wiring browser→BFF→backend nhưng KHÔNG phải backend thật. Hạng mục còn lại
cho một máy có Docker/Postgres: CONTENT_ADMIN login, reload khôi phục session,
logout, LEARNER bị chặn 403, request thiếu auth bị 401, expired-token
recovery qua refresh, list events/lessons, refresh rotation không logout.

## Xác minh cuối (tất cả trên máy này)

| Gate | Kết quả |
|---|---|
| `npx tsc --noEmit` | sạch, không lỗi |
| `npx next lint` | 0 warning / 0 error |
| `npx vitest run` | 7 files / 24 tests pass |
| `npx next build` | thành công (15/15 static, middleware 34.7 kB) |
| `npx playwright test` | 3/3 pass (login→dashboard, reload-rotation, invalid-credentials) |
| Backend `./mvnw verify` | **không chạy** — code backend không đổi, Docker/Postgres không có |

## File đã thay đổi

- `src/features/auth/refresh-coordinator.ts` — mới, single-flight + BroadcastChannel.
- `src/features/auth/refresh-coordinator.test.ts` — mới, 6 regression tests.
- `src/features/auth/use-auth.ts` — `refreshSession` delegate coordinator.
- `src/lib/api-client.ts` — bỏ `refreshInFlight` riêng, dùng `coordinatedRefresh`.
- `src/app/api/auth/refresh/route.ts` — BFF dedup theo hash presented token.
- `src/features/lessons/lessons-table.tsx` — sửa cột version.
- `docs/admin-runbook.md` — cập nhật mục auth flow + known limitations.

`git diff --check` sạch (chỉ cảnh báo CRLF thông thường trên Windows).

## Rủi ro còn ảnh hưởng sản phẩm

- **Smoke backend thật chưa chạy**: stub chứng minh wiring nhưng không thay
  thế kiểm chứng trên Spring Boot thật (rotation, revokeFamily, role check).
  Cần chạy trên máy/CI có Docker hoặc Postgres trước khi coi là xong hoàn toàn.
- **CSRF**: chưa có token; `SameSite=Lax` đủ cho admin hiện tại nhưng cần
  hardening trước khi có mutation surface rộng hơn.
- **BroadcastChannel** chỉ trên cùng origin; profile browser riêng (Firefox
  container, Chrome profile khác) vẫn share cookie qua BFF dedup — không
  crash, nhưng không có cơ chế adopt token chéo profile (không cần thiết:
  server-side dedup đã chặn replay).
