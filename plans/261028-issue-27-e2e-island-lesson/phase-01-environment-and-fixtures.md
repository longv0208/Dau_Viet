# Phase 01 — Chuẩn bị Môi trường, Dữ liệu Kiểm thử (Fixtures) & Cơ chế Dọn dẹp (Cleanup)

## 1. Cấu hình Môi trường Thực thi

| Thành phần | Cấu hình bắt buộc | Cách kiểm tra sẵn sàng |
|---|---|---|
| **PostgreSQL** | Container `dauviet-postgres` (`postgres:16`), cổng `5433:5432`, DB `dauviet`, user `dauviet` | `docker exec dauviet-postgres pg_isready -U dauviet -d dauviet` |
| **Backend Spring Boot** | `dau-viet-backend`, profile `local`, cổng `8080`, `JAVA_HOME=E:\Java\jdk-21` | `GET http://localhost:8080/actuator/health` -> `200 {"status":"UP"}` |
| **Flutter Mobile Web** | Build với `--dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://localhost:8080`, phục vụ tĩnh tại `http://localhost:4300` | `GET http://localhost:4300/index.html` -> `200` |
| **Trình duyệt E2E** | Playwright Chromium, viewport điện thoại chuẩn `390x844` (`isMobile: true`, `hasTouch: true`) và kiểm tra bổ sung ở viewport hẹp `360x800` | Tự động khởi chạy qua `playwright.config.mjs` |

## 2. Thiết kế Fixture Cô lập & Tái lập (`e2e/fixtures/test-harness.mjs`)

Nguyên tắc: **Không hard-code bất kỳ UUID dữ liệu thật nào** và **không chạm vào dữ liệu người dùng hiện hữu**. Mỗi test case (`beforeEach`) sinh một mã `runId` duy nhất (`<timestamp36>-<randomHex>`) và thực hiện:

1. **Tạo tài khoản Admin tạm thời & Learner kiểm thử riêng qua API thật**:
   - Gọi `POST /api/v1/auth/register` tạo `e2e.admin.<runId>@dauviet.test`, nâng quyền `CONTENT_ADMIN` cho đúng `adminUserId` vừa tạo, rồi gọi `POST /api/v1/auth/login`.
   - Gọi `POST /api/v1/auth/register` tạo `e2e.learner.<runId>@dauviet.test` và `POST /api/v1/auth/login`.
   - Lưu token trong bộ nhớ biến cục bộ của fixture; **tuyệt đối không `console.log` token hoặc mật khẩu**.
2. **Khám phá động Sự kiện & Mẫu bài học, Tạo và Publish Bài học v1**:
   - Gọi `GET /api/v1/events?page=0&size=20&sort=startYear,asc` lấy sự kiện nổi bật trên Trang chủ.
   - Gọi `GET /api/v1/admin/lesson-templates` lấy `templateId` đang kích hoạt đầu tiên.
   - Gọi `POST /api/v1/admin/lessons` tạo bài học mới `Bài học E2E Di Sản <runId>` với 2 stage bắt buộc:
     - **Stage 1 (`stage-context`, `CONTEXT`, `required: true`)**: Activity `act-read-context` (`READ`, `required: true`) kèm `feedback.COMPLETED` riêng từ server.
     - **Stage 2 (`stage-verify`, `VERIFICATION`, `required: true`)**: Activity `act-mc-verify` (`MULTIPLE_CHOICE`, `required: true`, `maxAttempts: 2`) gồm 2 lựa chọn văn bản lịch sử (không phải Đúng/Sai), kèm `feedback.INCORRECT` và `feedback.COMPLETED` riêng từ server.
   - Gọi `POST /api/v1/admin/lessons/{lessonId}/publish` để xuất bản snapshot bất biến `v1` (`lessonVersionV1Id`).
3. **Chuẩn bị hàm `publishLessonV2()` phục vụ kiểm thử ghim phiên bản (Version Pinning)**:
   - Khi bài học đang học dở ở giữa bài, test gọi `publishLessonV2()` để cập nhật draft sang nội dung `v2-updated` (`PUT /api/v1/admin/lessons/{lessonId}/draft`) và xuất bản `versionNo: 2` (`POST /api/v1/admin/lessons/{lessonId}/publish`).
4. **Chuẩn bị Kho vật phẩm & Trạng thái 3 loại Slot trên Đảo Di Sản**:
   - Truy vấn động 2 vật phẩm trang trí hợp lệ từ DB:
     ```sql
     SELECT id::text || '|' || code || '|' || name
     FROM item_catalog
     WHERE active = true AND placeable = true AND category = 'DECOR'
     ORDER BY code ASC
     LIMIT 2;
     ```
   - Cấp 2 vật phẩm này (`item1`, `item2`) vào bảng `user_inventory` của riêng `learnerUserId`.
   - Gọi `GET /api/v1/me/island` bằng token của learner để khởi tạo đảo Cấp 1 (4 slot mở khóa ở `TIER_1`, 8 slot khóa ở `TIER_2`/`TIER_3`).
   - Gọi `PUT /api/v1/me/island/placements/{occupiedSlot.slotId}` đặt sẵn `item1` vào ô mở khóa đầu tiên (`slot_1`), để lại:
     - `occupiedSlot` (`slot_1`): **Đang có vật phẩm `item1`**
     - `emptySlot` (`slot_2`): **Ô đất trống đã mở khóa**
     - `lockedSlot` (`slot_5`): **Ô bị khóa (yêu cầu Đảo Cấp 2)**
     - `item2`: **Nằm sẵn trong Kho vật phẩm của tài khoản, chưa đặt lên đảo**

## 3. Cơ chế Dọn dẹp An toàn Khóa ngoại (`cleanup()` & `verifyCleanup()`)

Trong `afterEach` (luôn chạy kể cả khi test fail), thực thi một transaction SQL xóa theo đúng thứ tự bảng con -> bảng cha chỉ cho `learnerUserId`, `adminUserId` và `lessonId`:
1. `user_island_placements` -> `user_islands` -> `user_inventory`
2. `wallet_transactions` -> `wallet_accounts` -> `energy_transactions` -> `user_energy`
3. `user_learning_streak_days` -> `user_learning_streaks` -> `user_dossier_unlocks` -> `user_event_progress` -> `user_location_unlocks` -> `user_path_period_state` -> `user_learning_path_enrollments`
4. `user_evidence` -> `reward_transactions` -> `lesson_results` -> `activity_attempts` -> `learner_attempts` -> `idempotency_records`
5. Chuyển `lessons.status = 'DRAFT', current_version_id = NULL` cho `lessonId`, tạm tắt trigger `trg_lesson_versions_immutable` trong phạm vi transaction để xóa `lesson_versions WHERE lesson_id = lessonId`, bật lại trigger ngay lập tức và xóa `lessons WHERE id = lessonId`.
6. Xóa `auth_refresh_tokens` và `users` của `learnerUserId`, `adminUserId`.
7. Gọi `verifyCleanup()` khẳng định tổng số dòng còn sót lại của test = `0`.
