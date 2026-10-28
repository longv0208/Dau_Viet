# DẤU VIỆT — REST API Specification (MVP Draft)

> **Status:** Contract proposal — chưa baseline; target Spring Boot (Java 21) + Flutter/Next.js clients.  
> **Base path:** `/api/v1` · JSON UTF-8 · HTTPS ngoài local · IDs UUID trừ stable stage/activity IDs trong snapshot.

## 1. Chuẩn chung

- `Authorization: Bearer <access_token>` cho endpoint bảo vệ; Admin cần `CONTENT_ADMIN`.
- Response JSON; timestamps ISO 8601 UTC; pagination `page/size` ở query, xác định consistent paging policy khi implement.
- Response lỗi: HTTP status đúng ngữ nghĩa + `code`, `message`, `details`, `traceId`.
- `Idempotency-Key` là header bắt buộc cho mutate có hậu quả như submit/complete/publish khi contract chốt.
- Never return password hash, JWT signing secrets, unpublished lesson (learner), correct answers, hidden rubric hoặc `validation` nhạy cảm.
- Version công khai trong URL `/v1`; version lesson thuộc business data (`lessonVersionId`) và độc lập API version.

### Error envelope

```json
{
  "code": "ACTIVITY_NOT_AVAILABLE",
  "message": "Hoạt động hiện chưa thể thực hiện",
  "details": {"activityId": "act-04"},
  "traceId": "2b6b36d5"
}
```

| HTTP | Khi dùng |
|---|---|
| 400 | Validation input/syntax |
| 401 | Chưa xác thực / token không hợp lệ |
| 403 | Không được phép thao tác |
| 404 | Không tồn tại hoặc tài nguyên không được lộ |
| 409 | State conflict, idempotency key reuse khác payload, attempt đã completed |
| 422 | Answer hợp cú pháp nhưng vi phạm rule nghiệp vụ không thể tiếp nhận |
| 429 | Rate limited |
| 500 | Lỗi server ngoài dự kiến |

## 2. Learner API endpoints

| Method | Path | Mục đích |
|---|---|---|
| POST | `/auth/register` | Đăng ký — **đã implement** (TASK-0007) |
| POST | `/auth/login` | Trả access + refresh token — **đã implement** (TASK-0007) |
| POST | `/auth/refresh` | Rotate refresh token — **đã implement** (TASK-0007) |
| POST | `/auth/logout` | Revoke refresh session — **đã implement** (TASK-0007) |
| GET | `/users/me` | Profile hiện tại — **đã implement** (TASK-0007) |
| GET | `/me` | Profile / level / EXP — **chưa implement** (chỉ có `/users/me` profile); EXP/level chưa baseline |
| GET | `/events` | Danh sách event/lesson published — **đã implement** (TASK-0005) |
| GET | `/events/{eventId}` | Metadata event, available lessons — **đã implement** (TASK-0005) |
| GET | `/events/{eventId}/lessons` | Published lessons của một event PUBLISHED — **implemented TASK-0010**; yêu cầu authenticated |
| GET | `/lessons/{lessonId}` | Published lesson metadata (title, centralQuestion, currentVersionId, versionNo) — **implemented TASK-0010**; yêu cầu authenticated; unpublished → 404 `LESSON_NOT_PUBLISHED` |
| GET | `/lessons/{lessonId}/content` | Learner-safe content của current published version (hidden keys stripped) — **implemented TASK-0010**; yêu cầu authenticated |
| POST | `/lessons/{lessonId}/attempts` | Start/resume theo policy — **implemented TASK-0011** |
| GET | `/attempts/{attemptId}` | Attempt progress/cursor — **implemented TASK-0011** |
| GET | `/attempts/{attemptId}/current` | Current activity (learner-safe payload) — **implemented TASK-0011** |
| GET | `/attempts/{attemptId}/content` | Learner-safe content của **đúng pinned version** (resume sau republish giữ nguyên evidence/assets/config của version attempt đang chạy) — **implemented TASK-0011**; owner-only |
| POST | `/attempts/{attemptId}/activities/{activityId}/submissions` | Submit answer, nhận feedback + next state — **implemented TASK-0011**; `Idempotency-Key` persist từ **TASK-0012** |
| POST | `/attempts/{attemptId}/complete` | Server-authoritative completion: flip `COMPLETED` + ghi `lesson_results` atomically — **implemented TASK-0012** |
| GET | `/attempts/{attemptId}/result` | Persisted `lesson_results` (score, result_json, completed_at) — **implemented TASK-0012** |
| GET | `/me/attempts` | Attempt history/resume của chính learner (paged, `?status=&page=&size=`) — **implemented TASK-0012** |
| GET | `/me/collection` | Bộ sưu tập bằng chứng của learner hiện tại — **implemented TASK-0022**; `?type=&eventId=&page=&size=` (size ≤ 50, newest first); owner-only qua JWT |
| GET | `/me/collection/{evidenceId}` | Chi tiết một bằng chứng đã collect + snapshot immutable + nguồn trích dẫn — **implemented TASK-0022**; 404 nếu không thuộc learner |
| GET | `/me/collection/types` | Các `evidence_type` learner đã collect trên toàn collection (distinct, ASC) — **implemented TASK-0022**; nguồn filter chips phía client |
| GET | `/me/collection/dossiers` | List hồ sơ lịch sử (GAME-04 dossiers) — **implemented GAME-04**; `?type=&eventId=&unlocked=&page=&size=` (size ≤ 50, sort `title,id`); DRAFT ẩn, ARCHIVED chỉ hiện nếu đã unlock, locked PUBLISHED → `preview=true` |
| GET | `/me/collection/dossiers/{dossierId}` | Chi tiết dossier — **implemented GAME-04**; DRAFT hoặc ARCHIVED chưa unlock → 404 `DOSSIER_NOT_FOUND`; locked PUBLISHED → preview (không description/source/dossierVersion); unlocked → full |
| GET | `/me/events/{eventId}/progress` | Tiến độ hoàn thành event của learner — **implemented GAME-04**; 404 khi event không tồn tại, `NOT_CONFIGURED` khi chưa có published policy |
| GET | `/me/progress` | Resume surface: IN_PROGRESS attempts + completed count — **implemented TASK-0012** |
| GET | `/me/energy` | Thể lực của learner hiện tại (lazy recovery theo server clock) — **implemented GAME-02**; yêu cầu authenticated |
| GET | `/me/streak` | Chuỗi ngày học hiện tại (server `Asia/Ho_Chi_Minh`) — **implemented STREAK-01**; authenticated, đọc-only không lazy-create |
| GET | `/me/streak/calendar` | Các ngày đã học trong khoảng `?from=&to=` (ISO date, ≤92 ngày) — **implemented STREAK-01**; authenticated |
| GET | `/learning-path` | Lộ trình học tập Bản đồ Dấu Ấn 2.0 (`?code=HISTORY_MAIN`) — **implemented PATH-01**; public / authenticated |
| GET | `/admin/learning-path/audit` | Báo cáo kiểm toán chất lượng dữ liệu lộ trình học tập — **implemented PATH-01**; role CONTENT_ADMIN |

### Start/resume

```http
POST /api/v1/lessons/4e18d732-62d6-4c6f-b62d-9f746197322a/attempts
Authorization: Bearer <token>
Content-Type: application/json

{}
```

```json
{
  "attemptId": "7fb4141d-766d-4602-b811-2241b8e53ac0",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "status": "IN_PROGRESS",
  "resumed": false,
  "currentStageId": "stage-context",
  "currentActivityId": "act-intro"
}
```

### Current activity — output đã redact

```json
{
  "attemptId": "7fb4141d-766d-4602-b811-2241b8e53ac0",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "stage": {"id": "stage-evidence", "type": "EVIDENCE"},
  "activity": {
    "id": "act-mcq-01",
    "type": "MULTIPLE_CHOICE",
    "instruction": "Chọn phương án đúng",
    "config": {
      "question": "Trận Bạch Đằng năm 938 diễn ra trên sông nào?",
      "options": [
        {"id": "a", "text": "Sông Hồng"},
        {"id": "b", "text": "Sông Bạch Đằng"}
      ]
    }
  },
  "progress": {"completedRequiredActivities": 2, "totalRequiredActivities": 9}
}
```

### Submit activity

```http
POST /api/v1/attempts/7fb4141d-766d-4602-b811-2241b8e53ac0/activities/act-mcq-01/submissions
Authorization: Bearer <token>
Idempotency-Key: 11e36737-9f1e-469b-84d6-c232a76c5672
Content-Type: application/json

{"answer": {"selectedOptionIds": ["b"]}}
```

```json
{
  "status": "ACCEPTED",
  "evaluation": {"outcome": "COMPLETED", "completed": true, "output": {"correct": true}},
  "activityCompleted": true,
  "progress": {"completedRequired": 3, "totalRequired": 9},
  "next": {"stageId": "stage-reasoning", "activityId": "act-match-01",
           "activityType": "MATCHING", "learnerConfig": {}},
  "completion": {"complete": false, "reason": "ALL_REQUIRED_STAGES"},
  "energyDeducted": 0
}
```

`energyDeducted` (GAME-02, additive): số thể lực server vừa trừ cho lượt submit đó (graded `INCORRECT` → `incorrectPenalty`, mặc định 10; clamp về số dư còn lại). Replay `Idempotency-Key` trả nguyên giá trị đã lưu — không trừ lại.

`energy` (GAME-02 FIX 7, additive): snapshot `EnergyStateResponse` ngay sau submission (cùng shape `GET /me/energy`). Đã gồm lazy-recovery server tự áp trước khi chấm — client đọc `energy.current` để biết balance mới, **không** suy từ `energyDeducted` (server có thể đã tự hồi +5 trước khi xử lý). Replay trả snapshot đã lưu cùng response.

**Không** cho Flutter gửi `correct`, `earnedExp`, `isCompleted`, `nextStageId` với quyền quyết định. Backend tính các dữ liệu đó từ snapshot/rule và state server.

### GET /me/energy — implemented shape (GAME-02)

`GET /api/v1/me/energy` — authenticated; lazy-create `user_energy` nếu chưa có, áp lazy-recovery theo `Clock` server rồi trả trạng thái mới nhất.

```json
{
  "current": 70,
  "max": 100,
  "recoveryAmount": 5,
  "recoveryIntervalSeconds": 900,
  "nextRecoveryAt": "2026-10-25T01:00:00Z",
  "serverTime": "2026-10-25T00:50:00Z",
  "canSubmitGraded": true
}
```

- `nextRecoveryAt` = `null` khi `current = max` (không còn chu kỳ hồi chờ).
- `canSubmitGraded` = `current > 0` — client dùng để quyết hiển thị nút submit graded; energy 0 chỉ chặn graded submit, ungraded/read/complete vẫn đi qua.
- `current`, `nextRecoveryAt`, `serverTime` do server tính tuyệt đối — client không gửi balance, không tự tính chu kỳ hồi.
- Error `409 ENERGY_DEPLETED` (submit graded khi `current = 0`) mang `details {currentEnergy, nextRecoveryAt, serverTime}` để client hiển thị countdown mà không cần gọi thêm endpoint.
- **Rollout flag (FIX 3)**: `dauviet.energy.enabled` mặc định `false` qua `application.yml` (`DAUVIET_ENERGY_ENABLED` env-override) — penalty + gate no-op khi tắt, chỉ theo dõi trạng thái; `canSubmitGraded` trả `true`. Bật `true` khi GAME-03 Flutter đã xử lý `ENERGY_DEPLETED` + đồng hồ đếm; bật/tắt không reset `user_energy`/`energy_transactions`. Tests bật explicit qua `src/test/resources/application.yml`.

### GET /me/streak — implemented shape (STREAK-01)

`GET /api/v1/me/streak` — authenticated; trả trạng thái Chuỗi Ngày Học của learner. Đọc-only: **không** lazy-create row nào — user chưa học nhận bộ default `current=0`, `streakAlive=false`, `lastQualifiedDate=null` mà DB vẫn trống.

```json
{
  "currentStreak": 5,
  "longestStreak": 12,
  "completedToday": true,
  "streakAlive": true,
  "lastQualifiedDate": "2026-10-26",
  "today": "2026-10-26",
  "timezone": "Asia/Ho_Chi_Minh",
  "serverTime": "2026-10-26T15:30:00Z"
}
```

- `streakAlive` = `lastQualifiedDate == today || lastQualifiedDate == today - 1` — phân biệt "đã ghi hôm nay" (`completedToday`) vs "học hôm qua, còn cửa giữ chuỗi" vs "đã đứt". Đọc **không** tự reset `current_streak` — lần complete kế tiếp sẽ set đúng luật trong transaction ghi.
- `today`, `serverTime` tính theo `Asia/Ho_Chi_Minh` từ `Clock` server — client không gửi ngày, không tự quy đổi múi giờ.

### GET /me/streak/calendar — implemented shape (STREAK-01)

`GET /api/v1/me/streak/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD` — authenticated; danh sách ngày VN có ≥1 attempt COMPLETED trong khoảng, sort ASC. Span tối đa 92 ngày (quá thì server cắt `to = from + 92`). `from > to` → 400 `VALIDATION_ERROR`.

```json
{
  "from": "2026-10-01",
  "to": "2026-10-31",
  "timezone": "Asia/Ho_Chi_Minh",
  "days": ["2026-10-20", "2026-10-24", "2026-10-26"],
  "serverTime": "2026-10-26T15:30:00Z"
}
```

### POST /attempts/{id}/complete — additive field (STREAK-01)

`CompleteAttemptResponse` giờ mang thêm `streak` — **chỉ non-null khi server vừa công nhận một ngày học MỚI** (ledger `INSERT ON CONFLICT` thắng). Replay attempt / bài thứ hai cùng ngày / concurrent same-day thua race → `streak = null` — client dùng đây làm điều kiện duy nhất phát animation ngọn lửa (không gọi GET bổ sung, không phát lại).

```json
"streak": {
  "dayRecorded": true,
  "currentStreak": 5,
  "longestStreak": 12,
  "studyDate": "2026-10-26"
}
```

### GET /events — implemented shape (TASK-0005)

`GET /api/v1/events?page=0&size=20&sort=startYear,asc` — public, chỉ trả event `PUBLISHED`.
`sort` chỉ chấp nhận `startYear` hoặc `title`; field khác → 400 `VALIDATION_ERROR`.

```json
{
  "content": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "slug": "bach-dang-938",
      "title": "Đại Chiến Bạch Đằng 938",
      "era": "Thời Ngô - Đinh - Tiền Lê (938 - 1009)",
      "period": "Mùa Đông 938 SCN",
      "startYear": 938,
      "summary": "…",
      "coverAssetKey": "events/bach-dang-938/hero.jpg",
      "tags": ["ngo-quyen", "thuy-chien"]
    }
  ],
  "page": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1
}
```

`GET /api/v1/events/{id}` trả thêm `description`, `location`, `publishedAt` (nullable cho tới khi có cột `published_at`); `{id}` phải là UUID, nếu không → 400 `MALFORMED_ID`; không tồn tại hoặc chưa publish → 404 `EVENT_NOT_FOUND`.

- Security hiện tại: permit-all cho `GET /api/v1/events/**` + actuator health/info + `POST /api/v1/auth/**`; `/api/v1/admin/**` cần `CONTENT_ADMIN`; còn lại cần JWT Bearer.
- Error envelope `{code, message, details, traceId}` đã active; mọi response mang header `X-Request-Id` (echo hoặc generate).

### Auth endpoints (implemented — TASK-0007)

`POST /api/v1/auth/register` — body `{email, password, displayName?, role?}`; `role` khác null → 400 `VALIDATION_ERROR` (không cho tự gán quyền); email chuẩn hoá `trim().toLowerCase`; trùng email → 409 `EMAIL_TAKEN`; thành công → 201 profile DTO (không chứa hash).

`POST /api/v1/auth/login` — `{email, password}` → 200 `{accessToken, tokenType:"Bearer", expiresIn, refreshToken, refreshExpiresIn}`. Sai mật khẩu / không tồn tại / LOCKED / DISABLED → 401 `INVALID_CREDENTIALS` (đồng nhất, không lộ tài khoản tồn tại).

`POST /api/v1/auth/refresh` — `{refreshToken}` → 200 cặp token mới (rotation: token cũ revoked, `previous_token_id` chain trong cùng `token_family_id`). Token đã revoked/replayed → 401 và **toàn bộ family bị thu hồi** (reuse detection). Hết hạn → 401.

`POST /api/v1/auth/logout` — `{refreshToken}` → 204, idempotent (retry vẫn 204, refresh sau logout → 401).

`GET /api/v1/users/me` — cần `Authorization: Bearer <access>`; trả `{id, email, displayName, role, status, emailVerifiedAt, createdAt}`; subject sai định dạng → 401.

`GET /api/v1/admin/ping` — placeholder gating: anonymous 401, LEARNER 403, CONTENT_ADMIN 200 `{status:"ok"}`.

Access token: JWT HS256 (sub = user UUID, claim `role`); access TTL mặc định 900s, refresh TTL 1209600s — cấu hình qua `app.security.*`. Secret từ `JWT_SECRET` env (≥32 bytes); fallback dev trong `application-local.yml`.

## 3. Admin / CMS API endpoints

| Method | Path | Mục đích |
|---|---|---|
| POST | `/admin/events` | Tạo event |
| GET | `/admin/events` | List events (page/size/sort, `status`, `q`) — **implemented TASK-0008** |
| GET | `/admin/events/{id}` | Event detail — **implemented TASK-0008** |
| PATCH | `/admin/events/{eventId}` | Sửa event metadata — **implemented TASK-0008** |
| POST | `/admin/events/{id}/publish` | DRAFT→PUBLISHED — **implemented TASK-0008** |
| POST | `/admin/events/{id}/archive` | →ARCHIVED (409 `EVENT_IN_USE` if non-archived lessons) — **implemented TASK-0008** |
| GET | `/admin/lesson-templates` | List enabled templates — **implemented TASK-0008** |
| GET | `/admin/lesson-templates/{id}` | Template detail + `preset_json` — **implemented TASK-0008** |
| POST | `/admin/lesson-templates` | Tạo template — **implemented** (xem `AdminLessonTemplateController`) |
| PATCH | `/admin/lesson-templates/{id}` | Sửa template — **implemented** |
| GET | `/admin/templates` | Alias kế hoạch cũ — **không có trong code**, dùng `/admin/lesson-templates` |
| POST | `/admin/lessons` | Tạo lesson/draft từ template — **implemented TASK-0008** |
| GET | `/admin/lessons` | List lessons (page/size/sort, `eventId`, `status`, `q`) — **implemented TASK-0008** |
| GET | `/admin/lessons/{lessonId}` | Lấy draft + metadata — **implemented TASK-0008** |
| PATCH | `/admin/lessons/{lessonId}` | Update title/centralQuestion/objectives/template — **implemented TASK-0008** |
| PUT | `/admin/lessons/{lessonId}/draft` | Lưu toàn bộ draft, optimistic version — **implemented TASK-0008** |
| POST | `/admin/lessons/{lessonId}/archive` | Archive, giữ version cũ — **implemented TASK-0008** |
| POST | `/admin/lessons/{lessonId}/validate` | Publish-readiness probe (200 + `{ready,errors,warnings,summary}`) — **implemented TASK-0009** |
| GET | `/admin/lessons/{lessonId}/draft/stages` | List stages trong draft (array-order) — **implemented TASK-0009** |
| POST | `/admin/lessons/{lessonId}/draft/stages` | Thêm stage (id tự sinh nếu bỏ trống) — **implemented TASK-0009** |
| GET | `/admin/lessons/{lessonId}/draft/stages/{stageId}` | Chi tiết một stage — **implemented TASK-0009** |
| PATCH | `/admin/lessons/{lessonId}/draft/stages/{stageId}` | Sửa title/required/nextStageIds/requiredEvidenceIds — **implemented TASK-0009** |
| PUT | `/admin/lessons/{lessonId}/draft/stages/order` | Reorder nguyên tử theo `orderedIds[]` — **implemented TASK-0009** |
| DELETE | `/admin/lessons/{lessonId}/draft/stages/{stageId}` | Xóa stage + prune nextStageIds/requiredStageIds — **implemented TASK-0009** |
| GET | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities` | List activities trong stage — **implemented TASK-0009** |
| POST | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities` | Thêm activity — **implemented TASK-0009** |
| GET | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}` | Chi tiết một activity — **implemented TASK-0009** |
| PATCH | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}` | Sửa activity — **implemented TASK-0009** |
| PUT | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/order` | Reorder activities — **implemented TASK-0009** |
| DELETE | `/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}` | Xóa activity — **implemented TASK-0009** |
| POST | `/admin/evidences` | Tạo evidence (eventId, source provenance) — **implemented TASK-0009** |
| GET | `/admin/evidences` | List evidences (page/size/sort, `eventId`, `status`, `q`) — **implemented TASK-0009** |
| GET | `/admin/evidences/{id}` | Evidence detail — **implemented TASK-0009** |
| PATCH | `/admin/evidences/{id}` | Sửa evidence metadata/asset — **implemented TASK-0009** |
| POST | `/admin/evidences/{id}/approve` | DRAFT→APPROVED — **implemented TASK-0009** |
| POST | `/admin/evidences/{id}/archive` | Archive (body tuỳ chọn `{expectedRowVersion}`; 409 `EVIDENCE_IN_USE` kèm `details.lessonIds` khi snapshot đang ref) — **implemented TASK-0009** |
| POST | `/admin/lessons/{lessonId}/preview` | Learner-safe projection của draft hiện tại; không ghi lesson_versions — **implemented TASK-0010** |
| POST | `/admin/lessons/{lessonId}/publish` | Transactional publish: PUBLISH-validate → snapshot bất biến → xoay current_version_id — **implemented TASK-0010** |
| GET | `/admin/lessons/{lessonId}/versions` | List version history (paged, newest-first) — **implemented TASK-0010** |
| GET | `/admin/lessons/{lessonId}/versions/{versionId}` | Chi tiết một version, full snapshot — **implemented TASK-0010** |
| GET | `/admin/lessons/{lessonId}/versions/current` | Version mà current_version_id đang trỏ — **implemented TASK-0010** |
| POST | `/admin/assets` | Upload asset (multipart `file` + metadata) — **implemented** (`AdminAssetController`); `dau-viet-admin` BFF `/api/upload/assets` forward tới đây |
| GET | `/admin/assets` | List assets (page/size) — **implemented** |
| GET | `/admin/assets/{id}` | Asset metadata — **implemented** |
| GET | `/admin/assets/{id}/content` | Stream nội dung file — **implemented** |
| GET | `/assets/{id}/content` | Stream asset cho learner (authenticated) — **implemented** (`LearnerAssetController`) |
| ~~POST~~ | ~~`/admin/assets/upload-intent`~~ | ~~Upload URL tạm thời~~ — **không implement**; upload đi trực tiếp qua `POST /admin/assets` |
| ~~POST~~ | ~~`/admin/assets/confirm`~~ | ~~Verify sau upload~~ — **không implement** (không có flow 2-bước) |
| GET | `/admin/animation-templates` | List animation templates (page/size, `rendererCode`, `enabled`, `q`) — **implemented** |
| GET | `/admin/animation-templates/{id}` | Template detail — **implemented** |
| GET | `/admin/animation-scenes` | List scenes (page/size/sort, `status`, `q`, `templateId`) — **implemented** |
| POST | `/admin/animation-scenes` | Tạo scene `{templateId,title,eventId?,draftJson?}` — **implemented** |
| GET | `/admin/animation-scenes/{id}` | Scene detail + `draftJson` (string) — **implemented** |
| PATCH | `/admin/animation-scenes/{id}` | Sửa `title`/`eventId`/`clearEvent`/`draftJson` + `expectedRowVersion` — **implemented** |
| POST | `/admin/animation-scenes/{id}/duplicate` | Nhân bản scene sang DRAFT mới — **implemented** |
| POST | `/admin/animation-scenes/{id}/validate` | Manifest probe → `{ready,errors:[{path,code,message}]}` luôn 200 — **implemented** |
| POST | `/admin/animation-scenes/{id}/publish` | Transactional publish → `{sceneId,versionId,versionNo}` — **implemented** |
| POST | `/admin/animation-scenes/{id}/archive` | →ARCHIVED (giữ version cũ, không republish) — **implemented** |
| GET | `/admin/animation-scenes/{id}/versions` | List `SceneVersionSummary[]` non-paginated — **implemented** |
| GET | `/admin/animation-scenes/{id}/versions/{versionId}` | Version detail + `snapshotJson` — **implemented** |
| POST | `/admin/animation-scenes/html-import` | `multipart/form-data` field `file` (`.html`, ≤15MB default) + query `title?`, `eventId?` → tạo scene `HTML_WEBVIEW` DRAFT; 422 `ANIMATION_HTML_INVALID` kèm `details.errors[]` khi file vi phạm — **implemented (V19)** |
| PUT | `/admin/animation-scenes/{id}/html-draft` | `multipart/form-data` `file` + `expectedRowVersion` → thay draft HTML của scene `HTML_WEBVIEW`; 409 stale row, 400 scene sai loại — **implemented (V19)** |
| GET | `/admin/animation-scenes/{id}/html-draft` | Trả `text/html` bytes draft (preview admin; scene `HTML_WEBVIEW` only, 404 khi chưa có draft) — **implemented (V19)** |
| GET | `/api/v1/animation-versions/{versionId}/html` | Learner fetch HTML đã publish: `text/html; charset=utf-8`, `X-Content-Type-Options: nosniff`, CSP `default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; media-src data:; font-src data:`, `Cache-Control: private, max-age=3600` — **implemented (V19)** |
| GET | `/admin/events/{eventId}/completion-policies` | List mọi policy version của event (DRAFT/PUBLISHED/ARCHIVED, mới nhất trước) — **implemented GAME-06** |
| GET | `/admin/events/{eventId}/completion-policies/{policyId}` | Chi tiết một policy version — **implemented GAME-06** |
| POST | `/admin/events/{eventId}/completion-policies` | Tạo DRAFT `{requiredLessonIds?, optionalLessonIds?, masteryThreshold?}` → 201, `policy_version = max+1` — **implemented GAME-06** |
| PUT | `/admin/events/{eventId}/completion-policies/{policyId}` | Sửa DRAFT **in-place** (policyId ổn định, user override thay copy-on-write) — 400 khi status ≠ DRAFT — **implemented GAME-06** |
| POST | `/admin/events/{eventId}/completion-policies/{policyId}/validate` | Dry-run; body rỗng = validate DRAFT hiện tại, body có dữ liệu = validate payload sắp lưu (không ghi DB) → `{valid, errors[{code,message,field}], warnings[], diff{from,to}}` — **implemented GAME-06** |
| POST | `/admin/events/{eventId}/completion-policies/{policyId}/publish` | Atomic publish (lock event → revalidate → archive PUBLISHED cũ → publish DRAFT); body `{expectedPolicyVersion?}` → 409 `OPTIMISTIC_LOCK_CONFLICT` stale, 422 khi validate fail — **implemented GAME-06** |
| GET | `/admin/dossiers` | List dossier (`type`, `status`, `q`, page/size ≤100, sort) → `PageResponse<AdminDossierSummaryResponse>` (kèm `eventCount`) — **implemented GAME-06** |
| POST | `/admin/dossiers` | Tạo dossier DRAFT (`canonicalCode` kebab-case set một lần, `dossierType`, `title`, `summary?`, `description?`, `source{title,author?,citation?,url?,reliability?}` — **không raw JSON**, `assetId?`) → 201; trùng canonicalCode → 409 — **implemented GAME-06** |
| GET | `/admin/dossiers/{id}` | Detail + `events[]` link + `versions[]` lịch sử + `pendingChanges` + `rowVersion` — **implemented GAME-06** |
| PUT | `/admin/dossiers/{id}` | Sửa nội dung (DRAFT sửa trực tiếp; PUBLISHED sửa → `pendingChanges` chờ publish version mới) + `expectedRowVersion` optimistic guard → 409 stale — **implemented GAME-06** |
| POST | `/admin/dossiers/{id}/publish` | Validate → `dossier_version = max+1` → PUBLISHED → snapshot `historical_dossier_versions` (V28) — **implemented GAME-06** |
| POST | `/admin/dossiers/{id}/archive` | →ARCHIVED; learner đã unlock vẫn đọc được (entitlement không thu hồi) — **implemented GAME-06** |
| GET | `/admin/events/{eventId}/dossiers` | List dossier đang link event (kèm `displayOrder`) — **implemented GAME-06** |
| PUT | `/admin/events/{eventId}/dossiers` | Replace-list `[{dossierId, displayOrder≥0, không trùng}]` — mọi dossier phải PUBLISHED → 422 `PolicyValidationException` — **implemented GAME-06** |
| POST | `/admin/items/{itemId}/rule/validate` | Dry-run rule (parse AST + validate + scope-check giống `PUT /rule`, không ghi DB) → `{valid, errors[], warnings[], normalizedCondition, scope, acceptsRule}` — **implemented GAME-06** |
| GET | `/admin/items/{itemId}/rule/history` | Mọi revision đã publish (active + inactive) kèm `grantCount` provenance — **implemented GAME-06** |
| POST | `/admin/rewards/reconcile-unlocks` | Đối soát grant item theo batch (`?batchSize=` default 200, max 1000, `0`=một lần) → `{itemsGranted, usersScanned, batches}` — đã có GAME-05, GAME-06 chỉ thêm UI |
| POST | `/admin/rewards/backfill` | Bổ sung reward thiếu cho attempt COMPLETED sớm nhất `(user,lesson)` → `{attemptsGranted}` — đã có GAME-05, GAME-06 chỉ thêm UI |

### Notes đã chốt — Animation Engine (TASK mới 2026-10-23)

- Manifest là dữ liệu whitelist (`AnimationManifestSchema`): `rendererCode ∈ {RIVER_TIDE,JOURNEY_MAP}`, `rendererVersion`, `schemaVersion`, `title`, `learningObjective`, `canvas`, `assets[]`, `objects[]`, `initialState`, `steps[]`, `interactions[]`, `narration`, `prediction`, `sourceReferences[]`, `disclaimer`, `river`, `map`. Key lạ → `UNKNOWN_FIELD`.
- **Manifest v2 (Cinematic 2.5D, TASK cinematic 2026-10-24)**: top-level optional keys `{camera, tracks, effects, audio, environment}`. Khi có bất kỳ key nào → `schemaVersion` phải ≥2 (validator `OUTDATED_SCHEMA`); v1 manifest (không có key nào) vẫn hợp lệ với `schemaVersion=1`.
  - `camera`: `{initial: {x,y,zoom,focusObjectId?,focusLocationId?}, steps: [{target: {...}, easing?}]}` — tâm 0..1, `zoom ∈ [0.5,3.0]`; `focusObjectId`/`focusLocationId` phải trỏ `objects[].id`/`map.locations[].id` (`UNKNOWN_REF`).
  - `tracks`: `[{objectId, property, keyframes: [{tMs, value, easing?}]}]` — `property ∈ {position,scale,rotation,opacity,visible}`; `objectId` phải tồn tại trong `objects[]`; `tMs` tăng nghiêm ngặt, không vượt `sum(steps.durationMs)`; `value` shape theo property (`position={x,y}` 0..1, `scale∈(0,2]`, `rotation∈[-360,360]`, `opacity∈[0,1]`, `visible=boolean`).
  - `effects`: `[{type, stepId?, durationMs?, params?}]` — `type ∈ {WATER_RIPPLE,MIST,GLOW,ROUTE_REVEAL,FADE_IN,FADE_OUT}`; `stepId` rỗng = ambient cả scene; `params` bounded JSON (depth ≤4); `GLOW.params.objectId` follow `objects[]`.
  - `audio`: `[{stepId, assetRef, cue, volume?, fadeMs?}]` — `cue ∈ {ENTER,EXIT,LOOP}`; `stepId` phải khớp `steps[].id` (`UNKNOWN_REF`); `assetRef` phải trỏ `assets[].id` role `AUDIO` (`UNKNOWN_REF`); `volume ∈ [0,1]`, `fadeMs ∈ [0,120000]`.
  - `environment`: `{waterLevel?, mist?, glow?}` — chỉ `RIVER_TIDE` (`RENDERER_MISMATCH` trên JOURNEY_MAP); seed `waterLevel` TRƯỚC `initialState` (priority thấp hơn); `mist/glow ∈ [0,1]` ambient overlay.
  - Assets role `AUDIO` được chấp nhận trong `assets[]`; upload MIME whitelist gồm `audio/mpeg|wav|x-wav|ogg` (AssetService `ALLOWED_MIME_EXT`).
- **Publish contract (§8)**: `POST /api/v1/admin/animation-scenes/{id}/publish` ghi `animation_scene_versions.schema_version = manifest.schemaVersion` thực của draft — v1 → 1, v2 → 2, thiếu field → 1. Trước fix này service ghi `CURRENT_SCHEMA_VERSION` (auto-promote v1 lên 2 sai).
- Per-renderer state keys: RIVER_TIDE = `waterLevel,boatProgress,boatCount,boatLane,decoyProgress,counterattackProgress,obstructed,showSequenceSummary,hasWaterControl,highlightStakes,stakeVisibility,stakeHighlight`; JOURNEY_MAP = `markerVisibility,markerHighlight,focusedLocationId,routeProgress,locationInfoId,tapToExplore,schematicDisclaimer`. State key lạ → `UNKNOWN_STATE_KEY`.
- Bounds: manifest ≤256KB, depth ≤24, ≤60 steps, ≤200 objects/stakes, ≤100 locations, ≤60 routes, ≤60 assets, text ≤2000, title ≤255, durationMs ≤120000, prediction ≤6 options.
- Scene draft (`draftJson`) KHÔNG bao giờ trả cho learner; learner nhận `activity.config.animationManifest = {manifest, sceneVersionId, versionNo, rendererCode, rendererVersion}` nhúng trong `lesson_versions.snapshot_json`.
- `animation_scene_versions` bất biến (trigger `prevent_animation_scene_version_mutation`); publish ghi `manifest_checksum = sha256(snapshotJsonText)` — checksum trên canonical `snapshot_json` text (manifest + asset metadata nhúng), khớp recipe V15 `encode(digest(snapshot_json::text,'sha256'),'hex')` — + embed asset refs vào `animation_scene_asset_refs`.
- `READ.config`: `animationSceneId` + `animationSceneVersionId` + `playbackMode ∈ {AUTO,STEPPED,INTERACTIVE}` — loại trừ lẫn nhau với legacy `animationKey` (`INVALID_TYPE` khi cả hai cùng tồn tại); `animationSceneId`/`animationSceneVersionId` phải là UUID (`INVALID_ID`), `animationSceneVersionId` phải tồn tại và thuộc cùng scene (`ANIMATION_SCENE_VERSION_MISMATCH`), `animationSceneId` phải trỏ scene `PUBLISHED` (`ANIMATION_SCENE_NOT_PUBLISHED`).
- `POST /{id}/validate` luôn 200 `{ready,errors:[{path,code,message}]}`; `POST /{id}/publish` validate rồi ghi version mới (pessimistic lock trên scene + `UNIQUE(scene_id,version_no)` backstop); `PATCH` cần `expectedRowVersion` khớp → 409 `OPTIMISTIC_LOCK_CONFLICT`.
- Scene ARCHIVED → publish/update bị chặn `INVALID_STATUS_TRANSITION`; version cũ vẫn đọc được qua `/{id}/versions/{versionId}`.
- **HTML_WEBVIEW (V19, kèm `docs/HTML_ANIMATION_GUIDE.md`)**: rendererCode thứ ba; `draft_json` chỉ mang `{schemaVersion:2, rendererCode:'HTML_WEBVIEW', title, disclaimer, sourceReferences[], html{filename,sizeBytes,sha256}}` — bytes trong `animation_scene_html`/`animation_scene_version_html`, KHÔNG trong JSONB. `HtmlDocumentValidator` chặn external refs (`script/link/img src http|./`, `fetch`, `XHR`, `import()`, `WebSocket`, `sendBeacon`, `window.open`, `meta refresh`, iframe ngoài) — 422 `ANIMATION_HTML_INVALID` `details.errors[]` (path/code/message + số dòng). Publish copy draft→version TX; learner endpoint serve bytes từ version table (immutable trigger).

### Notes đã chốt TASK-0008

- `PATCH`/`PUT` admin endpoints chấp nhận `expectedRowVersion` trong body → optimistic-lock 409 `OPTIMISTIC_LOCK_CONFLICT` khi stale.
- Slug event immutable sau khi `PUBLISHED` (409 `INVALID_STATUS_TRANSITION`).
- Archive event PUBLISHED còn lesson non-archived → 409 `EVENT_IN_USE`; không cascade.
- `PUT /{id}/draft` validate `draftJson` là JSON object, `objectivesJson` JSON array → 422 `DRAFT_SCHEMA_INVALID`.
- Template `enabled=false` → 422 `TEMPLATE_DISABLED`; id không tồn tại → 404 `TEMPLATE_NOT_FOUND`.
- Publish endpoint trả 409 `INVALID_STATUS_TRANSITION` với message TASK-0010 pending.

### Notes đã chốt TASK-0009 (Lesson Builder Core)

- `draft_json` v1: `{schemaVersion:1, stages:[{id,type,title,required,activities[],nextStageIds[],requiredEvidenceIds[]}], completion:{requireAllRequiredStages,requiredStageIds[],minScore}}`. Stage/activity order = vị trí trong mảng; id theo `^[a-z0-9][a-z0-9-]{1,63}$`.
- Mọi mutation stage/activity chạy pipeline load→mutate→**SAVE-validate**→persist; draft hỏng cấu trúc không bao giờ được ghi → 422 `DRAFT_SCHEMA_INVALID` kèm `details.errors[]` (path/code/message).
- SAVE-level: JSON well-formed, id hợp lệ & unique, enum stage/activity, không có key lạ, stage→activity allow-map, transition tồn tại, không có chu trình (`CIRCULAR_TRANSITION`). PUBLISH-level thêm: config bắt buộc đủ, evidence refs tồn tại trong event + status `DRAFT|APPROVED` (`EVIDENCE_NOT_FOUND`), asset refs `state=ACTIVE` (`ASSET_NOT_FOUND`), completion khả thi.
- Stage type cho phép activity theo `STAGE_ALLOWED_ACTIVITIES` (READ được mọi stage); vi phạm → `STAGE_ACTIVITY_MISMATCH`. Type lạ → `UNSUPPORTED_ACTIVITY_TYPE`.
- READ chấp nhận `config.animationKey` tuỳ chọn (ANIM-01): string identifier `^[a-z0-9]+(_[a-z0-9]+){0,7}$` tối đa 80 ký tự (`INVALID_TYPE`/`INVALID_ID`), resolve phía Flutter qua typed registry — backend không kiểm tra key có scene tương ứng; key sống nguyên qua draft→snapshot→learner projection (không nằm trong `LEARNER_HIDDEN_KEYS`).
- Answer keys (`correctOptionIds`, `correctPairs`, `expectedOrder`, `requiredEvidenceIds` trong config...) là server-only — `DraftSchema.LEARNER_HIDDEN_KEYS` liệt kê; snapshot/preview phải strip (TASK-0010).
- Xóa stage prune `nextStageIds` của stage khác + `completion.requiredStageIds`; `PUT .../order` yêu cầu `orderedIds` liệt kê đúng mọi id (400 khi thiếu/dư/trùng).
- Evidence không hard-delete: DRAFT→APPROVED→ARCHIVED; archive từ chối khi `lesson_versions.snapshot_json` còn chứa id (409 `EVIDENCE_IN_USE`, quét LIKE bảo thủ phía admin). `assetId` phải tồn tại trong `assets` (404 `ASSET_NOT_FOUND`), `reliability ∈ {HIGH,MEDIUM,LOW,UNASSESSED}`.
- `POST /{id}/validate` **luôn 200** `{ready,errors,warnings,summary}`: `ready=false` khi có error; warnings (lesson non-DRAFT, thiếu objectives) không chặn; template `schema_version != 1` → `TEMPLATE_SCHEMA_MISMATCH`. PUBLISH-level thêm `NO_TERMINAL_STAGE` (ít nhất một stage có `nextStageIds` rỗng **và reachable từ entry stage = `stages[0]`**; terminal node unreachable hoặc nằm trong component rời không được tính), `NO_REQUIRED_ACTIVITY` (ít nhất một required stage có required non-READ activity), chặn `requireAllRequiredStages=true` khi không có stage nào `required`, và bắt buộc `schemaVersion` đúng `CURRENT_VERSION` (thiếu → `MISSING_FIELD`, sai → `UNSUPPORTED_SCHEMA_VERSION`). Summary gồm `stageCount/activityCount/evidenceRefs/schemaVersion/errorCount/warningCount`. Không tạo `lesson_versions` — publish thật là TASK-0010.
- Sub-resource writes chỉ khi lesson `DRAFT`; ARCHIVED → 409 `INVALID_STATUS_TRANSITION`; `expectedRowVersion` ở body/query → 409 `OPTIMISTIC_LOCK_CONFLICT`. Reorder/delete trả `rowVersion` mới trong `DraftStagesResponse`/`DraftActivitiesResponse` để client chain mutation tiếp theo. `POST /admin/evidences/{id}/archive` nhận body tuỳ chọn `{expectedRowVersion}`; `EVIDENCE_IN_USE` trả `details.lessonIds`.

### Publish request/response

```http
POST /api/v1/admin/lessons/{lessonId}/publish
Authorization: Bearer <admin_token>
Content-Type: application/json

{"expectedRowVersion": 12}
```

`expectedRowVersion` là tuỳ chọn (optimistic-lock guard trên row `lessons`); `Idempotency-Key` chưa implement — xem open questions.

```json
{
  "lessonId": "4e18d732-62d6-4c6f-b62d-9f746197322a",
  "lessonVersionId": "e9d113ac-1c82-4d33-8ba0-1807422a9d6a",
  "versionNo": 2,
  "status": "PUBLISHED",
  "publishedAt": "2026-10-16T00:00:00Z"
}
```

Publish chạy PUBLISH-level `DraftValidator` trong một transaction: `SELECT FOR UPDATE` trên `lessons` serialize concurrent publish, `version_no = max+1`, insert `lesson_versions` (trigger DB chặn UPDATE/DELETE), cập nhật `current_version_id` + `status=PUBLISHED`. Lỗi validation → `422 DRAFT_SCHEMA_INVALID` với `details.errors[]` không ghi gì; ARCHIVED → `409 INVALID_STATUS_TRANSITION`; stale `expectedRowVersion` → `409 OPTIMISTIC_LOCK_CONFLICT`. Republish trên lesson PUBLISHED được phép (version_no tăng, snapshot cũ giữ nguyên). Event cha phải `PUBLISHED` — nếu không publish bị chặn với `422` và `details.errors[]` chứa `EVENT_NOT_PUBLISHED` (AC-2).

### Notes đã chốt TASK-0010 (Publish + Learner-safe content)

- `snapshot_json` embed: `schemaVersion`, `lessonId`, `title`, `centralQuestion`, `objectives`, `templateCode`, `stages`/`completion` verbatim từ draft (server-only keys giữ lại cho evaluation phía server sau này), `evidence[]` denormalized (id/title/evidenceType/description/source{title,author,url,citation,publishedAt}/reliability/relevance/assetId), `assets[]` (id/storageKey/mimeType/sizeBytes/originalFilename/altText). Snapshot là single published truth — evidence/asset embed giữ `EVIDENCE_IN_USE` LIKE-scan hoạt động.
- Learner projection (`LearnerProjectionService`) strip đệ quy `LEARNER_HIDDEN_KEYS` ở mọi depth trong config/feedback/validation, xoá `validation` block và `evidenceRefs` của activity cùng `requiredEvidenceIds` của stage; không mutate snapshot gốc. Renderer-facing refs (`visibleEvidenceIds`, `visibleSourceIds`) vẫn giữ.
- Readiness (`/validate` + `/publish`) kiểm tra thêm: template `enabled=false` → error `TEMPLATE_DISABLED`; event cha chưa `PUBLISHED` → error `EVENT_NOT_PUBLISHED` (block publish theo AC-2); event không tồn tại → error `EVENT_NOT_FOUND`.
- `POST /admin/lessons/{id}/preview` trả cùng projection trên draft hiện tại (`lessonVersionId`/`versionNo` = null), không ghi bản ghi nào, lesson giữ nguyên trạng thái.
- Learner GETs yêu cầu authenticated (mọi role; AC-10): `/api/v1/events/*/lessons`, `/api/v1/lessons/*` (gồm `/content`) — anonymous → `401`. Event catalogue (`/api/v1/events`, `/api/v1/events/*`) vẫn `permitAll`. Lesson chưa publish → `404 LESSON_NOT_PUBLISHED`; event chưa publish → `404` theo `EVENT_NOT_FOUND` envelope.
- `snapshot_json` hỏng (không parse được) → `500 SNAPSHOT_CORRUPT`, không trả content rỗng.
- Admin version APIs trả full snapshot kể cả server-only keys (admin-only sau `/admin/**` guard).

### Notes đã chốt TASK-0011 (Learning Engine runtime)

- `POST /lessons/{id}/attempts` — start/resume: một IN_PROGRESS attempt của learner cho **lesson** (không phân biệt version) được resume `resumed=true` — kể cả khi đang pin version cũ sau republish; chỉ tạo attempt mới (pin `current_version_id` hiện tại) khi không còn attempt IN_PROGRESS. Lesson phải `PUBLISHED` với `current_version_id` cho start mới (không → `404 LESSON_NOT_PUBLISHED`). Attempt đang chạy không bao giờ bị thay thế tự động.
- Cursor (`currentStageId`/`currentActivityId`) do server tính từ `state_json` — trỏ required activity chưa xong đầu tiên theo thứ tự array; `null` khi không còn required activity.
- `GET /attempts/{id}` trả `{attemptId, lessonVersionId, status, currentStageId, currentActivityId, progress{completedRequired,totalRequired}, completion}`. `GET /attempts/{id}/current` trả stage/activity (activity đã qua `projectActivity` — strip `validation`, `evidenceRefs`, hidden keys) + progress.
- Submit nhận activity tại cursor, hoặc activity **optional trong current stage** (ghi attempt/output nhưng không đổi cursor, không tính progress/completion). Các trường hợp khác → `409 ACTIVITY_NOT_AVAILABLE`); owner-only (`403 ATTEMPT_NOT_OWNER`), attempt phải `IN_PROGRESS` (`409 ATTEMPT_NOT_IN_PROGRESS`), attempt không tồn tại `404 ATTEMPT_NOT_FOUND`, snapshot thiếu activity `409 ACTIVITY_NOT_AVAILABLE`, pinned version không đọc được `422 LESSON_VERSION_MISMATCH`/`SNAPSHOT_INVALID_FOR_ACTIVITY`/`UNSUPPORTED_ACTIVITY_TYPE`. Required activity submit mà chưa `completed` (MCQ chưa hết `maxAttempts`, VERIFICATION `PARTIAL`/`CONTRADICTED`, EVIDENCE_SELECT/EXPLORE_MAP thiếu ngưỡng) → cursor giữ nguyên để retry (hoặc REVISE hop khi authored); exhausted vẫn advance.
- Activity id phải unique toàn snapshot: publish `DUPLICATE_ID` → `422 DRAFT_SCHEMA_INVALID`; snapshot hỏng tay → `500 SNAPSHOT_CORRUPT`.
- Submit chạy trong transaction với `SELECT FOR UPDATE` trên `learner_attempts` (serialize concurrent submit); mỗi submit được chấp nhận append một `activity_attempts` row, `attempt_no = count+1` (unique per attempt+activity). Submit trên attempt `COMPLETED` → `409 ATTEMPT_ALREADY_COMPLETED`; `ABANDONED`/khác → `409 ATTEMPT_NOT_IN_PROGRESS`.
- `POST /attempts/{id}/complete` (TASK-0012): server re-evaluate completion config trên persisted state; `verdict.complete()=false` → `409 ATTEMPT_NOT_COMPLETE` kèm `details` (missing stages/reason), không flip gì. Thành công → atomic `status=COMPLETED` + `completed_at` + một row `lesson_results` (unique per attempt) trong cùng transaction. Lặp lại/concurrent → `200` với cùng stored verdict (`alreadyCompleted=true`), không duplicate row. Client không tự declare completion được.
- `GET /attempts/{id}/result` — owner-only; `404 RESULT_NOT_FOUND` trước khi completed. Response `{attemptId, lessonVersionId, status, score, result, completedAt, startedAt}` — `score` là **completion percentage** (0-100, 2 chữ số) = required activities đã completed / totalRequired, **không phải điểm đánh giá**: required activity tính completed kể cả khi hết retry trên đáp án sai (quy tắc exhausted-still-advances TASK-0011). `result` là result_json snapshot `{attemptId, lessonVersionId, reason, score, knowledgeScore, completedRequired, totalRequired, detail}` — `knowledgeScore` (0-100) là điểm đánh giá riêng từ TASK-0020 (xem notes); không có hidden answer keys.
- `GET /me/attempts?status=&page=&size=` — PageResponse `{content, page, size, totalElements, totalPages}` của riêng learner (mọi attempts mọi status, `size` tối đa 50, newest `lastActiveAt` trước); mỗi row `AttemptSummaryResponse {attemptId, lessonId, lessonVersionId, status, currentStageId, currentActivityId, progress, startedAt, lastActiveAt, completedAt}`. `GET /me/progress` — `{inProgress: [AttemptSummaryResponse...], completedCount}` cho màn resume của mobile. Attempt của user khác không bao giờ lộ.
- Idempotency-Key (TASK-0012): persist trên `idempotency_records`, scope `(user_id, operation, key)` với operation `SUBMIT_ACTIVITY`/`COMPLETE_ATTEMPT`; `request_hash` = SHA-256(`attemptId|activityId|canonical(answer)`) cho submit, `attemptId` cho complete. Cùng key + cùng fingerprint → `200` replay stored response (không re-evaluate, không append row); cùng key + payload khác → `409 IDEMPOTENCY_CONFLICT` — client phải mint key mới cho mỗi action khác nhau (kể cả cùng attempt, activity khác). Concurrent cùng-key serialize trên attempt row lock → loser thấy committed response, không double-write. Claim row + response + activity_attempts commit cùng transaction; business error rollback cả claim nên key không bị burn. TTL mặc định 24h (`app.learning.idempotency-ttl`); record hết hạn bị xoá + reclaim. Không gửi key → execute thẳng, không ghi record.
- `completion` config (AND-combination): `requireAllRequiredStages` (mọi stage `required:true` xong hết required activities), `requiredStageIds` (subset chỉ định — đếm `required:true` bên trong stage đó, kể cả stage optional), `minScore` (% required activities đã xong trên tổng). Không có config → default `DEFAULT_ALL_REQUIRED`. **`stage.required=false`** → toàn bộ activities bên trong optional (không đếm `totalRequired`, không gate completion, cursor không vào); `activity.required=true` trong optional stage → publish `422 REQUIRED_IN_OPTIONAL_STAGE`. **Config rỗng/không-clause** (`completion:{}`, hoặc chỉ giá trị falsy/empty/null) cũng → `DEFAULT_ALL_REQUIRED` — không bao giờ complete sớm; publish-time reject `completion:{}` (`422 EMPTY_COMPLETION`). Reason enum: `ALL_REQUIRED_STAGES` | `REQUIRED_STAGE_IDS` | `MIN_SCORE` | `DEFAULT_ALL_REQUIRED` | `NOT_COMPLETE`.
- Evaluation outcomes per handler: `COMPLETED` | `INCORRECT` | `PARTIAL` | `SUPPORTED` | `CONTRADICTED`. MCQ `maxAttempts` (default 1) đạt giới hạn → `exhausted:true` và activity vẫn tính completed cho transition.
- Error codes mới: `ATTEMPT_NOT_FOUND`(404), `ATTEMPT_NOT_OWNER`(403), `ATTEMPT_NOT_IN_PROGRESS`(409), `ATTEMPT_ALREADY_COMPLETED`(409), `ACTIVITY_NOT_AVAILABLE`(409), `ACTIVITY_ALREADY_SUBMITTED`(409), `SNAPSHOT_INVALID_FOR_ACTIVITY`(422), `LESSON_VERSION_MISMATCH`(422). TASK-0012 thêm: `IDEMPOTENCY_CONFLICT`(409 — cùng key khác payload, hoặc key đang in-flight), `ATTEMPT_NOT_COMPLETE`(409 — complete khi chưa đủ requirements, `details` mang `LessonCompletion.detail`), `RESULT_NOT_FOUND`(404 — `/result` trước khi completed). GAME-02 thêm: `ENERGY_DEPLETED`(409 — submit graded khi `current_energy = 0`, `details` mang `{currentEnergy, nextRecoveryAt, serverTime}`; chỉ phát khi `dauviet.energy.enabled=true` và chỉ trên graded submit).

### Notes đã chốt TASK-0020 (Learning Flow 2.0)

- **`CER_CHOICE`** (stage `CONCLUSION`): submit `{claimId, reasoningId, evidenceIds[]}` — `claimId`/`reasoningId` phải thuộc `config.claims[]`/`config.reasoningOptions[]` (sai → lỗi validation, không phải INCORRECT); `evidenceIds` ⊆ `config.evidenceOptions[]` ∪ snapshot evidence ∪ `priorOutputs[config.priorEvidenceSource].selectedEvidenceIds`. Chấm vs **`acceptedCombos[]`** (`{claimId, evidenceIds[], reasoningId}`): đúng khi cả 3 phần khớp chính xác một combo (evidence set-equality); `score = partsCorrect/3` — partial không promote thành correct. `maxAttempts` (default 3) hết → `exhausted:true`, completed-cho-progress nhưng `correct=false` (không soft-lock). Legacy flat keys `acceptedClaims`/`acceptedEvidenceIds`/`acceptedReasoningIds` → cartesian combos (snapshot cũ giữ nguyên semantics); `minCorrect` đã retire — publish reject `INVALID_CONFIG`.
- **Graded opt-in `config.graded:true`**: `EVIDENCE_SELECT` dùng `acceptedEvidenceIds` (publish đòi ⊆ `visibleEvidenceIds`); `REASONING_CONNECT` dùng `expectedRelations` ∪ `acceptedRelationSets[]` (mỗi relation `{from,to,relation}` tham chiếu `nodes[].id`/`allowedRelations`). Runtime: exact-set match với **bất kỳ** accepted set nào → `COMPLETED`; ngược lại partial với **`score = max F1 = max over every accepted set of 2·hits/(|submitted|+|accepted|)`** — F1 tính độc lập từng set rồi lấy tối đa (không chọn set theo hit count, tránh khớp nhiều trên set lớn mà F1 thấp hơn), bounded [0,1], extras/missing kéo score < 1.0, duplicate không inflate; `maxAttempts` hết → `exhausted` vẫn completed. Submit output chỉ chứa counts/`correct`/`score`/`attemptCount` — không echo answer keys.
- **Resubmit completion mark hai chiều**: `doSubmit` ghi `recordOutput` rồi `markCompleted` khi `result.completed()=true`, **`removeCompleted` khi `=false`** — resubmit graded incomplete (correct → wrong/partial trước khi hết `maxAttempts`) phải gỡ dấu completed cũ, giữ phân biệt incorrect-but-exhausted (`completed=true` — vẫn advance) vs incomplete (`completed=false` — giữ retry). `completedActivityIds` luôn phản ánh evaluation gần nhất, không để stale mark chỉ về output đã bị ghi đè.
- **`config.priorOutputs`**: projection inject outputs đã ghi của attempt (strip `LEARNER_HIDDEN_KEYS` lần nữa — defense-in-depth) vào activity payload — downstream renderer đọc lựa chọn trước đó không cần hỏi lại.
- **VERIFICATION evidence (§P0)**: `config.evidenceSource` trỏ EVIDENCE_SELECT upstream — `VerificationHandler` lấy `priorOutputs[source].selectedEvidenceIds` làm tập chấm `requiredEvidenceIds`, **không đọc evidence ids từ answer payload**; source thiếu/malformed → `PARTIAL`. Snapshot cũ không khai báo → fallback `hypothesis.evidenceIds`. Client chỉ gửi `{action:"verify"}`.
- **Source-ref publish validation**: `evidenceSource`/`priorEvidenceSource` phải (a) tồn tại (`UNKNOWN_ACTIVITY_ID`, publish-only), (b) là `EVIDENCE_SELECT` (`INVALID_CONFIG`), (c) đứng trước consumer trong thứ tự thực thi — cùng stage thì source khai báo **trước** consumer trong `activities[]`, khác stage thì consumer reach được source qua **forward `nextStageIds`**. Revision hops (`onPartial`/`onContradicted`) không được coi là bảo chứng availability — hop là navigation quay lại, không chứng minh output đã tồn tại trước khi consumer chạy (`UNREACHABLE_SOURCE`). Admin dropdown đồng nhất với backend.
- **Transitive dependent invalidation**: re-submit một activity xóa output+completed của mọi activity downstream theo dependency graph (explicit refs `evidenceSource`/`priorEvidenceSource` + lan truyền theo thứ tự flow qua pseudo-boundary `stage:{id}`, BFS visited-guarded) — revise một output xóa sạch mọi consumer trực tiếp và gián tiếp; bảo toàn chính activity vừa submit. **Revision hops (`onPartial`/`onContradicted`) không phải data-dependency edge** — hop là navigation, không phải consumer; đưa hop vào tạo cycle (ví dụ `hc → do → vf1 → hc` trong Bạch Đằng) khiến resubmit downstream void chính hypothesis/verification nó phụ thuộc. **`attemptCounts` ledger** (round-3): invalidation xóa output nhưng **không** refund lượt thử — retry budget sống trong `state_json.attemptCounts{activityId:n}` tách khỏi output, nên VERIFICATION bounded không bị reset budget bởi upstream re-submit (nếu không: es resubmit → invalidate vf1 → vf1 lại `attemptCount=1` → lặp vô hạn).
- **Remediation / no-soft-lock (round-3)**: `config.remedialAttempts` trên `EVIDENCE_SELECT` — ngân sách retry bổ sung chỉ mở khi scored `maxAttempts` đã cạn (`exhausted:true`) và cursor đứng lại ở activity; lượt mang marker `remedial:true`, chấm vẫn exact-match/F1 — không free credit; lượt cuối luôn `completed-for-progress` (bounded → dứt). `config.maxAttempts` trên `VERIFICATION` (default 0 = unbounded, legacy) — cạn budget ở verdict non-SUPPORTED → `completed-for-progress` + `exhausted:true` mà verdict **không** promote thành SUPPORTED. Resolver: rule (-1) remedial-stay đứng trước rule (0); rule (b) revise-hop **bị chặn khi `exhausted:true`** — bounded VERIFICATION cạn budget mà vẫn hop về source cạn budget là đúng shape soft-lock thứ hai.
- **Hard cap vượt ngân sách (round-4, policy B)**: `EVIDENCE_SELECT` graded — `attemptNo > maxAttempts + remedialAttempts` (đếm qua `attemptCounts` ledger, không refund khi invalidation) thì submit **vẫn được chấp nhận** (không 409-soft-lock trên cursor) nhưng không được nâng correctness: output giữ `correct`/`score` **và** `selectedEvidenceIds`/`selectedCount` của lần ghi nhận cuối (ghi đè selection bằng đáp án đúng sẽ cho downstream `evidenceSource` thấy tập bằng chứng "đúng" mà verdict đã chốt không hề đạt → SUPPORTED leak), thêm `budgetExhausted:true` + `exhausted:true`, outcome `INCORRECT`, `completed=true`, feedbackCode `EXHAUSTED`. Không tạo score/reward mới; knowledgeScore không đổi.
- **Bounded-int validation (round-4)**: publish-time `EVIDENCE_SELECT` — `maxAttempts` integer [1,10], `remedialAttempts` integer [0,5]; `VERIFICATION` — `maxAttempts` integer [1,20] (vắng mặt = unbounded legacy). Non-integer → `INVALID_TYPE`, ngoài khoảng → `INVALID_VALUE`; field vắng mặt dùng default cũ → backward compatible. Admin: evidence-select-editor có input `maxAttempts` + `remedialAttempts` (hint policy), verification-editor có input `maxAttempts` (để trống = không giới hạn), feedback-panel có field `EXHAUSTED` cho cả hai loại.
- **Reviewed-terminal feedback (round-4)**: khi VERIFICATION kết thúc `exhausted:true` ở `PARTIAL`/`CONTRADICTED`, attempt hoàn thành bình thường (progress 100%) nhưng Flutter `_feedbackFor` hiển thị warning "Bạn đã hoàn thành lượt học, nhưng chưa kiểm chứng thành công." — `feedback.EXHAUSTED` authored (nếu admin viết) thắng qua `feedbackText(feedbackCode)`; không có nút verify vô hạn, không free-text.
- **`UNGUARANTEED_SOURCE` (publish, `422`)**: consumer `required:true` (VERIFICATION `evidenceSource`, CER_CHOICE `priorEvidenceSource`) mà source EVIDENCE_SELECT nằm trong stage `required:false`, hoặc chính activity source `required:false` → reject — required consumer không được phụ thuộc nguồn có thể bị skip theo flow thực thi (chỉ đếm reachability là không đủ). Chạy sau `UNREACHABLE_SOURCE`; optional consumer không áp. Admin `evidenceSelectActivities(draft, excludeId, consumer)` đồng nhất: khi `consumer.required` thì dropdown lọc ra sources trong optional stage, source non-required, và source cùng-stage khai báo sau consumer.
- **Dual score**: `result_json` thêm `knowledgeScore` (0-100) — trung bình per-activity **chỉ trên graded activities**: contract-graded (`MULTIPLE_CHOICE`, `MATCHING`, `DRAG_ORDER`, `CER_CHOICE` — emit `correct`) **hoặc** `config.graded:true` (graded `EVIDENCE_SELECT`, `REASONING_CONNECT`): `output.score` (0..1) > `output.correct` (1/0); ungraded/completion-only không đếm (READ/VIEW_IMAGE/EXPLORE_MAP/HYPOTHESIS_CHOICE/REFLECTION_PROMPT, legacy CER, count-only EVIDENCE_SELECT, syntax-only REASONING_CONNECT, và `VERIFICATION` — emit `verification` verdict không phải learner correctness); 0 graded → `knowledgeScore=0`. `score` giữ nguyên nghĩa completion %. REFLECTION stage (`required:false`) không tính totals/completion/knowledge.
- **Publish contract**: `CER_CHOICE` đòi `claims[]`/`reasoningOptions[]` ≥2 phần tử, ≥1 `acceptedCombos` với refs ⊆ options tương ứng (`evidenceIds` ⊆ evidence của event), `feedback.COMPLETED`+`feedback.INCORRECT` (thiếu → `422` `MISSING_FIELD`/`INVALID_CONFIG`/`EVIDENCE_NOT_FOUND`); flat keys chỉ được chấp nhận khi không có `acceptedCombos`. `priorEvidenceSource`/`evidenceSource` textual + `ID_PATTERN` (`INVALID_ID`) + source-ref validation nói trên. `DraftSchema.ACTIVITY_KEYS` giờ chấp nhận `onPartial`/`onContradicted` (sửa contract gap: resolver đọc được nhưng validator từng reject `UNKNOWN_FIELD`).
- **Hidden keys**: `acceptedClaims`, `acceptedEvidenceIds`, `acceptedReasoningIds`, `acceptedCombos`, `expectedRelations`, `acceptedRelationSets`, `acceptedOptions` đã nằm trong `LEARNER_HIDDEN_KEYS` — strip ở snapshot/preview/projection và `priorOutputs` inject.
- Test fixtures: `dau-viet-backend/src/test/resources/lessons/bach-dang-938-v2.draft.json` (8-stage flow tham chiếu) + `hai-ba-trung-40.draft.json` (chứng minh engine reuse, không event-specific branch).

## 4. Security và cạnh tranh trạng thái

1. Authorize user ownership mọi attempt/result, role Admin trên CMS endpoints.
2. Không để user thay đổi `lessonVersionId` của attempt.
3. Signature/expiry/revocation cho access/refresh; hash refresh token nếu persist.
4. Rate limit login/submit; validate payload size và upload file type/size.
5. Idempotency key theo `user + operation + key`; lưu request hash/result; cùng key + payload khác → 409.
6. Concurrent requests submit cùng activity phải được serialize hoặc dùng optimistic lock; không được nhảy state 2 lần.
7. Không expose thông tin mật bằng `GET current`; validate/feedback luôn tính server side.

## 5. Truy vết requirement

| API nhóm | BA requirement |
|---|---|
| Events/Lessons | LRN-01, ADM-01…03 |
| Start/Resume/Current | LRN-02…04, LRN-13, ENG-01…03, ENG-07 |
| Submissions | LRN-05…10, ENG-05…09 |
| Complete/Result | LRN-11…14, ENG-09 |
| Admin validate/preview/publish | ADM-08…13, ENG-10 |

## 6. Các điểm cần BA/PO duyệt

- Allow multiple attempts? Repeated reward? Retry limits và hint penalties?
- Với lesson archived, learner cũ còn resume đến khi nào?
- Có hỗ trợ offline answer queue không? MVP đề xuất online-first, retry-safe.
- Có cần phân trang/cursor cho event catalog lớn từ MVP không?
- Ai được publish: một Content Admin hay cần reviewer?
- API `PUT draft` lưu full document hay patch theo stage? Đề xuất MVP full document + `expectedDraftRevision`.

## 7. Nguồn

- `Dau_Viet_BA_MVP_Learning_Framework.docx`: functional requirements LRN/ADM/ENG và use cases.
- `Functional_Requirements_Dau_Viet_MVP.docx`: FR-01…46 và luồng chức năng.
- Các endpoint có ghi `implemented TASK-xxxx` là đã có trong code tại commit `0744ae8`; các endpoint không ghi trạng thái (ví dụ `/me`, `/me/collection`, `/admin/assets/*`) là **đề xuất/dự kiến, chưa implement**. HTTP errors và payloads là **đề xuất kỹ thuật** cho đến khi được kiểm thử E2E.

### Notes đã chốt TASK-0021 (Bản đồ lịch sử & mở khoá địa điểm — FR-35..38)

- `GET /api/v1/map/locations` — learner authenticated (mọi role; anonymous → `401`). Trả array top-level các `MapLocationDto` **PUBLISHED** của event **PUBLISHED**, sắp theo `displayOrder,title`. Mỗi item `{id, eventId, eventTitle, title, description, latitude, longitude, unlockState, requiredLesson?{lessonId,title,accessible}}` — chỉ field an toàn, không lộ cấu hình admin. `eventTitle` cho phép detail hiển thị event cha không cần request phụ (FR-38).
- `GET /api/v1/map/locations/{id}` — cùng shape; `404` khi không tồn tại/chưa PUBLISHED/event chưa PUBLISHED.
- `requiredLesson.accessible` = `false` khi bài học liên kết không còn learner-accessible (status khác PUBLISHED hoặc `current_version_id` null — vd. bị archive sau khi địa điểm publish). Client **không hiển thị CTA bài học** khi `false`; trạng thái `UNLOCKED` đã đạt được **không bao giờ** bị thu hồi.
- `unlockState` do **server tính theo `sub` JWT** — client không gửi userId/cờ completed: `AVAILABLE` = không link bài học; `UNLOCKED` = learner có ≥1 attempt `COMPLETED` trên **bất kỳ version nào** của `unlockLessonId` (republish không reset); `LOCKED` = ngược lại. Một truy vấn IN-list cho toàn trang (không N+1).
- Admin nested dưới event: `GET|POST /api/v1/admin/events/{eventId}/map-locations`, `PATCH .../{locationId}?expectedRowVersion=`, `POST .../{locationId}/status?status=DRAFT|PUBLISHED|ARCHIVED&expectedRowVersion=` — `CONTENT_ADMIN`, `@Version` optimistic lock (409 khi lệch version). **`expectedRowVersion` bắt buộc** trên cả PATCH và status transitions — thiếu → `400 VALIDATION_ERROR` "Thiếu expectedRowVersion".
- Publish gate: `status=PUBLISHED` yêu cầu `unlockLessonId` null hoặc trỏ tới lesson **PUBLISHED có `current_version_id`** — draft/archived lesson → `400 VALIDATION_ERROR` ("Bài học mở khoá phải được xuất bản trước khi địa điểm được xuất bản cho học viên").
- Validate: `title` bắt buộc ≤255; `latitude ∈ [-90,90]`, `longitude ∈ [-180,180]` → `400`; `unlockLessonId` phải thuộc **cùng event** — kiểm tra service (`400`, thông báo tiếng Việt) **và** composite FK `(event_id, unlock_lesson_id) → lessons(event_id,id)` ở DB.
- Mobile: route `/map` (auth-gated); `mapLocationsProvider` watch `authSessionProvider` nên đổi user/logout/restore tự refetch — không lộ unlock state giữa các tài khoản; lesson completion (`POST /attempts/{id}/complete` thành công) invalidate map state ngay cả khi `/map` đã unmount. Bản đồ là **lược hoạ** (schematic) — không georeferenced base map; markers project từ toạ độ thật, pan/zoom qua InteractiveViewer.
- Giới hạn FR-38: people/evidence per-location hiện **không có quan hệ rõ ràng an toàn** trong schema (evidences link tới event, không tới map_locations) — detail chỉ hiển thị `eventTitle` + mô tả; mở rộng quan hệ evidence/person để sau (TASK-0022 phạm vi).

### Verification results TASK-0021 (2026-10-22)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Unit + IT | `.\mvnw.cmd test` | **PASS** — 184/184 (MapLocationIT: 14/14), Flyway V8 clean PostgreSQL 16 |
| Admin | Lint | `npm run lint` | **PASS** — 0 warnings |
| Admin | Typecheck | `npx tsc --noEmit` | **PASS** |
| Admin | Unit tests | `npm test` | **PASS** — 109/109 |
| Admin | Build | `npm run build` | **PASS** — 22 routes |
| Admin | Playwright e2e | `npm run test:e2e` | **BLOCKED** — port 3100 nằm trong dải reserved của Windows (3080-3179). Chạy được trên CI (Linux) hoặc sau khi đổi port. |
| Mobile | Format | `dart format` | **PASS** |
| Mobile | Analyze | `flutter analyze` | **PASS** — 0 issues |
| Mobile | Unit + widget tests | `flutter test` | **PASS** — 149/149 |
| Mobile | Debug APK | `flutter build apk --debug` | **PASS** — `app-debug.apk` built |

### Notes đã chốt TASK-0023 (Rewards, Inventory & Item Unlock — FR-39..44)

- **Grant realtime**: `POST /attempts/{id}/complete` thành công (first completion của logical lesson, tính theo `lesson_id` — republish không đếm lại) ghi 2 `reward_transactions` trong cùng transaction: `EXP` +100 và `HISTORY_POINTS` +50 (mặc định, config `dauviet.rewards.exp-first-completion` / `dauviet.rewards.history-points-first-completion`). `cause_key` = `LESSON_FIRST_COMPLETE:{userId}:{lessonId}:{rewardType}` — unique + `INSERT ON CONFLICT DO NOTHING` → retry/replay/concurrent/second-attempt/republish không duplicate. Không cấp thưởng từ cờ client; `score` ≠ mastery.
- `GET /api/v1/me/rewards/summary` — `{exp, historyPoints, lessonsCompleted, itemsOwned}` của riêng learner (JWT); `lessonsCompleted` = số **bài khác nhau** đã hoàn thành (distinct lesson_id, không phải số attempt).
- `GET /api/v1/me/rewards/transactions?page=&size=` — PageResponse, `size` tối đa 50 (`PAGE_SIZE_EXCEEDED` → 400); mỗi row `{id, rewardType, amount, reason, lessonId, createdAt}`.
- `GET /api/v1/me/inventory` — array `InventoryItemDto` đã sở hữu, mới nhất trước: `{itemId, code, name, description, category, itemType, rarity, assetId, acquiredAt, acquisitionSource, sourceLessonId, unlockRuleId, unlockRuleVersion, sourceEventId}` (GAME-05: provenance additive — rule đã cấp + version, event nguồn).
- `GET /api/v1/me/inventory/catalog` — union item `active` + item learner đã sở hữu (kể cả sau khi admin tắt), dedupe theo itemId, sort theo code; mỗi item thêm `owned`, `acquiredAt` (nếu owned), `requirement` là **tree** (GAME-05): node `{operator? (ALL|ANY), type?, eventId?, lessonId?, lessonTitle?, evidenceIds?, threshold?, current?, required?, satisfied, status ∈ SATISFIED|PENDING|UNSUPPORTED|UNCONFIGURED, description, conditions?[]}` — leaf mang `type` + `current/required`, operator mang `conditions[]` con (đều leaf, không nesting sâu hơn 1 lớp). `description` server-authored tiếng Việt; `status=UNSUPPORTED` cho điều kiện chưa đánh giá được (LEVEL_AT_LEAST chờ GAME-07 — không bao giờ satisfied); `status=UNCONFIGURED` (FIX-1) khi rule đang `needs-mapping` — root node không children, `satisfied=false`, `description="Điều kiện mở khóa đang được cập nhật"` — KHÔNG fake `satisfied` của rule legacy, không progress bar, grant path và read path dùng chung một quyết định (`ItemUnlockRule.isNeedsMapping`); biến mất ngay khi admin publish rule v2 hợp lệ. `sourceNote` (từ `source_metadata.note`). Item inactive không sở hữu vẫn ẩn; ownership không bao giờ bị thu hồi.
- `GET /attempts/{id}/result` trả thêm `rewards` (danh sách bút toán của attempt — thường 2) và `itemsUnlocked` (items có `source_attempt_id` = attempt đó **và** `acquisition_source <> 'ADMIN_GRANT'`). FINAL FIX-1: grant qua event-milestone **trong cùng transaction complete** ghi `source_attempt_id`/`source_lesson_id` = attempt vừa hoàn thành → badge `EVENT_COMPLETED` hiển thị ngay trên result screen (trước đây provenance null nên mất). Grant từ reconcile (`recordIfEarned` 2-tham-số, `acquisition_source='ADMIN_GRANT'`) giữ null — không gán attempt giả, không hiển thị ở đây. Additive, không đổi field cũ.
- **Item unlock rules** (`item_unlock_rule`, một active rule mỗi item). GAME-05 Rule Engine V2: rule giờ là AST trong `condition_json` (`rule_version=2`), grammar `leaf | {all:[leaf,…]} | {any:[leaf,…]}` — operator chỉ bọc leaf (depth ≤ 2), leaf types `LESSON_COMPLETED | COLLECTION_COUNT | LESSON_COUNT | EVENT_COMPLETED | EVENT_MASTERED | LESSON_MASTERED | EVENT_EVIDENCE_COUNT | SPECIFIC_EVIDENCE_SET | TOTAL_EVENTS_COMPLETED | TOTAL_EVENTS_MASTERED` (+`LEVEL_AT_LEAST` parse được nhưng chưa đánh giá — UNSUPPORTED, chờ GAME-07). Ngữ nghĩa: `EVENT_EVIDENCE_COUNT`/`SPECIFIC_EVIDENCE_SET` scope theo `eventId` (COUNT DISTINCT evidence_id THUỘC event — count global của event khác không được mở); `EVENT_COMPLETED`/`EVENT_MASTERED`/`TOTAL_EVENTS_*` đọc ledger `user_event_progress` (GAME-04), không recompute; `LESSON_MASTERED` = best `knowledgeScore` ≥ `threshold`; `COLLECTION_COUNT` giữ ngữ nghĩa global V1 (không âm thầm đổi rule đã publish). Rule v1 (3 loại cột phẳng) vẫn đánh giá qua `condition_json` tương đương (V24 normalize, `rule_version=1`).
  - Grant realtime: trong cùng transaction submit-collect / `complete()` / event-milestone; `acquisition_source='RULE_UNLOCK'`; per-user advisory lock `pg_advisory_xact_lock(hashtextextended('item-unlock|'||userId))` serialize submit/complete song song — lock order attempt → event milestone → item. `doComplete` ghi event milestone **trước** khi đánh giá item (ordering fix GAME-05) nên rule `EVENT_COMPLETED` grant được ngay trong completion tạo milestone.
  - `cause_key` = `item-rule|{ruleId}|{userId}` + `UNIQUE (user_id, item_id)` + partial unique `ux_user_inventory_cause_key` — idempotent; vật phẩm đã cấp không bao giờ revoke (rule append-only, rule mới chỉ áp dụng grant MỚI).
  - `rule_metadata.audit='needs-mapping'` (7 item event-themed của seed V12 bị flag — V1 đếm global cho item event-specific) → chặn grant MỚI tới khi admin publish rule v2 event-scoped minh định (không đoán eventId); `HUY_HIEU_DIEN_BIEN_PHU` được flag `valid-global`. Ownership đã cấp giữ nguyên. Catalog hiển thị `status=UNCONFIGURED` (không fake satisfied) thay vì progress giả.
  - **Item-level scope (FINAL FIX-2)**: `ItemRuleScopeResolver` suy `ItemScope ∈ UNRESOLVED|EVENT_SCOPED|GLOBAL` từ toàn bộ lịch sử rule của item — `EVENT_SCOPED` nếu từng có rule v2 chứa leaf gắn `eventId` (`EVENT_COMPLETED`/`EVENT_MASTERED`/`EVENT_EVIDENCE_COUNT`/`SPECIFIC_EVIDENCE_SET`/`TOTAL_EVENTS_*` có `eventId`; `LESSON_*` không tính event-scoped), `UNRESOLVED` nếu từng bị flag `needs-mapping` mà chưa có rule event-scoped, còn lại `GLOBAL`. Không hard-code mã item/tên sự kiện trong evaluator. `UNRESOLVED`/`EVENT_SCOPED` → admin publish rule global (COLLECTION_COUNT/LESSON_COUNT thuần…) → `400 VALIDATION_ERROR`; grant path chặn `UNRESOLVED` kể cả khi flag audit đã mất trên active rule; catalog → `UNCONFIGURED`. Item `GLOBAL` nhận rule global bình thường.
  - **`rule_version` = SCHEMA payload / `revision` = thứ tự publish PER ITEM (V27, FINAL FIX-3)**: `rule_version` chỉ mô tả schema (1 = V1 flat, 2 = V2 AST — CHECK cũ giữ nguyên, V1 API vẫn ghi 1); cột `revision` (NOT NULL, DEFAULT 1, backfill = `rule_version` cũ) là số thứ tự monotonic per-item — mọi publish (V1 lẫn V2) ghi `max(revision của item)+1`, không bao giờ giảm/lặp trong cùng item (trước đây setRule V1 ép `rule_version=1` → revision trùng/giảm sau nhiều publish V2). `AdminItemResponse.Rule.ruleVersion` trả `revision` (thứ tự publish); `user_inventory.unlock_rule_version` trace đúng revision đã cấp (`unlock_rule_id` là khoá chính). `rule_type='RULE_V2'` là discriminator hệ thống — client gửi `ruleType` khác `'RULE_V2'` kèm `condition` → 400 (mâu thuẫn), không chuỗi lạ nào tới DB (FIX-5).
- **Backfill**: `POST /api/v1/admin/rewards/backfill` (CONTENT_ADMIN) → `{attemptsGranted}`; chỉ attempt COMPLETED **sớm nhất** mỗi `(user, lesson)` chiếm slot (sắp `completed_at ASC`); mỗi **loại thưởng** được bổ sung độc lập — EXP có mà HISTORY_POINTS thiếu thì chỉ insert loại thiếu, không sửa bút toán cũ. Gọi lại n lần vẫn an toàn.
- **Reconcile unlocks**: `POST /api/v1/admin/rewards/reconcile-unlocks` (CONTENT_ADMIN) — GAME-05 FIX-7: mặc định chạy **theo batch** (`?batchSize=`, default 200, max 1000; `batchSize=0` giữ đường một-lần cho dataset nhỏ) — keyset pagination `user_id > cursor` trên tập user ứng viên (union `user_evidence` ∪ `learner_attempts COMPLETED` ∪ `user_event_progress`), mỗi trang một transaction ngắn (`REQUIRES_NEW`), không load toàn bộ candidate ids vào một tx dài; trả `{itemsGranted, usersScanned, batches}`. Đánh giá bằng **đúng evaluator realtime** (AST, không nhánh rule_type) — single source cho realtime và backfill. `acquisition_source='ADMIN_GRANT'` (giữ semantics V1 — `itemsUnlocked` của result screen loại ADMIN_GRANT); provenance: rule `LESSON_COMPLETED` ghi `source_lesson_id` + attempt COMPLETED sớm nhất (ORDER BY completed_at), leaf đếm/event → null; `source_event_id` = event đầu tiên trong AST. Idempotent — ON CONFLICT (user,item) + cause_key → re-run sau fail an toàn, không dup; không revoke, không grant EXP/History Points, không đụng attempt state.
- **Event reconcile → item unlock (FIX-3, provenance FINAL FIX-1)**: `EventMilestoneRecorder.recordIfEarned` gọi `ItemUnlockService.evaluateAfterEventMilestone` ngay khi một milestone `EVENT_COMPLETED`/`EVENT_MASTERED` được ghi MỚI — hai overload: 4-tham-số `(userId, eventId, lessonId, attemptId)` do `doComplete` gọi (grant ghi provenance = attempt đang hoàn thành → `itemsUnlocked` result screen thấy được), 2-tham-số `(userId, eventId)` cho reconcile-on-read (`GET /me/events/{id}/progress`) và lazy reconcile (`/me/collection/dossiers*`) — provenance null, không gán attempt giả. Chỉ chạy khi milestone **mới** (không đánh giá thừa mỗi lần đọc); không vòng lặp (item eval không gọi lại recorder); lock order event-milestone → item giữ nguyên.
- **Admin items**: `GET /api/v1/admin/items` (list + rule hiện hành, page/size clamp ≤100), `GET /api/v1/admin/items/{itemId}`, `POST /api/v1/admin/items` → 201, `PUT /api/v1/admin/items/{itemId}` (**partial update** — field null trong request = "không đổi", `assetId`/`sourceMetadata` giữ nguyên khi sửa metadata; xoá có chủ đích qua `clearAsset:true` hoặc `sourceMetadata:{}`; `@Version row_version` optimistic lock), `PUT /api/v1/admin/items/{itemId}/rule` — hai dạng additive (GAME-05): v1 `{ruleType, lessonId?, threshold?, active}` (3 loại cũ, `LESSON_COMPLETED` yêu cầu lesson PUBLISHED → 400); v2 `{condition: {leaf|{all:[…]}|{any:[…]}}, ruleType?}` — `condition` parse + validate nghiêm qua `ItemConditionParser`/`ItemConditionValidator` (tham chiếu event/lesson phải tồn tại + PUBLISHED, `EVENT_COMPLETED`/`EVENT_MASTERED` đòi event có policy PUBLISHED — NOT_CONFIGURED → 400, `SPECIFIC_EVIDENCE_SET` đòi evidence thuộc event khai báo + APPROVED + không trùng + **collect được thực sự** — được một activity `EVIDENCE_SELECT` tham chiếu trong snapshot PUBLISHED hiện tại (`visibleEvidenceIds`/`acceptedEvidenceIds`/`requiredEvidenceIds`/`evidenceOptions[{id}]`), không chỉ nằm trong `snapshot.evidence[]` metadata; fallback đã có `user_evidence` row từ version cũ (FINAL FIX-4, siết từ FIX-6), `LEVEL_AT_LEAST` → 400 "not evaluable yet", nested operator/sai grammar/extraneous field → 400 `ItemRuleException`, không bao giờ 500); `ruleType` chỉ được trống hoặc `'RULE_V2'` khi kèm `condition` — chuỗi lạ/v1-type → 400 (FIX-5); `ruleVersion` trả về `revision` per-item monotonic (`max(revision)+1` cho mọi publish V1/V2 — V27/FINAL FIX-3); **item-scope guard (FINAL FIX-2)**: item `UNRESOLVED`/`EVENT_SCOPED` chỉ chấp nhận rule chứa leaf event-scoped — rule global → 400; item `GLOBAL` nhận cả hai dạng. Pessimistic lock trên item row + deactivate rule cũ trước insert (ux-item-one-active); `DELETE` = soft (`active=false`). Tất cả `CONTENT_ADMIN`.
- **RewardPolicy config** `dauviet.rewards.first-completion.exp` / `history-points` — validate `> 0` lúc startup (IllegalStateException khi sai; CHECK `amount>0` của DB không bao giờ bị đụng).
- Không thêm error code mới: item không tồn tại → `404` (ResourceNotFoundException chung); rule sai shape / `size` là tham số page (clamp về max, không 400); trùng `code` / lệch `expectedRowVersion` → `409` qua DataIntegrityViolation / optimistic-lock handler hiện có.
- Mobile: `LessonResultDto` thêm `rewards`/`itemsUnlocked` — màn kết quả chỉ **hiển thị** dữ liệu server trả (không POST hoàn thành lần hai). `InventoryScreen` dùng `GET /me/inventory/catalog` thật (owned/locked + progress `current/threshold`), providers session-scoped invalidate sau submit (COLLECTION_COUNT có thể grant mid-attempt) và complete.

### Verification results TASK-0023 (2026-10-22, focused bugfix pass)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Unit + IT | `.\mvnw.cmd test -Dtest='*IT'` | **PASS** — 227/227 (RewardGrantIT 13/13, ItemUnlockIT 22/22), Flyway V12+V13 clean |
| Admin | Lint | `npm run lint` | **PASS** — 0 warnings |
| Admin | Typecheck | `npx tsc --noEmit` | **PASS** |
| Admin | Unit tests | `npm test` | **PASS** — 116/116 |
| Admin | Build | `npm run build` | **PASS** |
| Mobile | Format | `dart format --output=none --set-exit-if-changed lib test` | **PASS** |
| Mobile | Analyze | `flutter analyze` | **PASS** — 0 issues |
| Mobile | Unit + widget | `flutter test` | **PASS** — 164/164 |

### Notes đã chốt GAME-04 (Event Completion & Historical Dossier — 2026-10-25)

- **`GET /api/v1/me/events/{eventId}/progress`** — authenticated, owner-scoped qua JWT `sub`. `404` khi event không tồn tại (uniform, không lộ). `NOT_CONFIGURED` khi event chưa có policy `PUBLISHED` (mọi field số/milestone trả rỗng/false, `policyVersion`/`masteryThreshold` null). Khi có policy: reconcile-on-read ghi `EVENT_COMPLETED`/`EVENT_MASTERED` nếu đã đạt từ completed attempts cũ (idempotent). `status` precedence `EVENT_MASTERED > EVENT_COMPLETED > IN_PROGRESS`.
  ```json
  {
    "eventId": "uuid",
    "status": "EVENT_COMPLETED",
    "policyVersion": 1,
    "requiredLessonsTotal": 1,
    "requiredLessonsCompleted": 1,
    "eventCompleted": true,
    "eventMastered": false,
    "masteryThreshold": 70,
    "requiredLessons": [
      {"lessonId": "uuid", "title": "...", "completed": true,
       "masteryStatus": "BELOW_THRESHOLD", "bestKnowledgeScore": 55}
    ],
    "unlockedDossiersCount": 3,
    "earnedPolicyVersion": 1
  }
  ```
  `masteryStatus` ∈ `NOT_COMPLETED | NOT_ASSESSED | BELOW_THRESHOLD | MASTERED`; `bestKnowledgeScore` null khi `NOT_ASSESSED`/`NOT_COMPLETED` (không lộ điểm bài không đo được). `unlockedDossiersCount` = số dossier learner đã unlock có link tới event (count join `event_dossiers` — dossier dùng chung nhiều event vẫn đếm đủ ở từng event). `earnedPolicyVersion` = `policy_version` đã cấp `EVENT_COMPLETED` cho learner (null khi chưa đạt); khi `< policyVersion` hiện tại nghĩa là learner completed bản policy cũ — client hiển thị "đã hoàn thành phiên bản trước, còn bài mới" thay vì bắt học lại.
- **`GET /api/v1/me/collection/dossiers`** — authenticated. Query: `type ∈ PERSON|LOCATION|ARTIFACT|CONTEXT`, `eventId`, `unlocked` (true=chỉ đã mở, false=chỉ preview/locked), `page`, `size` (cap 50), sort cố định `title,id`. Trả `PageResponse<DossierSummaryResponse>` `{content, page, size, totalElements, totalPages}`; mỗi item `{dossierId, canonicalCode, dossierType, title, summary, assetId, eventIds[], unlocked, grantedAt, unlockEventId, dossierVersion, preview}` — `dossierVersion` = version entitlement-pinned learner đang sở hữu (null khi locked); `preview=true` nghĩa là chỉ metadata title-level được trả (locked PUBLISHED). List/detail trước khi đọc đều chạy lazy reconcile các event có dossier learner thấy được — learner hoàn thành lesson trước GAME-04 không cần ghé progress endpoint vẫn được grant đúng lần đọc đầu tiên. Visibility: `DRAFT` không bao giờ xuất hiện; `ARCHIVED` chỉ hiện nếu learner đã unlock trước đó; locked `PUBLISHED` → `preview=true`.
- **`GET /api/v1/me/collection/dossiers/{dossierId}`** — `DossierDetailResponse` thêm `description`, `source{title,author,citation,url,reliability}`, `dossierVersion` chỉ khi `unlocked=true` (version **pinned** theo entitlement), `catalogVersion` = version catalog hiện tại của dossier. `DRAFT` → `404 DOSSIER_NOT_FOUND`; `ARCHIVED` chưa unlock → `404 DOSSIER_NOT_FOUND` (không mở mới archive); `ARCHIVED` đã unlock → vẫn truy cập được (entitlement không thu hồi); locked `PUBLISHED` → `preview=true` (không `description`/`source`/`dossierVersion`).
- **`POST /api/v1/attempts/{attemptId}/complete`** — response thêm field additive `newlyUnlockedDossiers: UUID[]` (GAME-04). Rỗng khi replay cùng `Idempotency-Key`, `alreadyCompleted=true`, event `NOT_CONFIGURED`, hoặc milestone đã grant trước đó — client dùng cho cue "vừa mở khóa" một lần, không nhầm với toàn bộ dossier đã sở hữu. Milestone + dossier unlock ghi trong **cùng transaction** với flip `COMPLETED` và reward/item grants; lỗi dossier rollback cả completion.
- Route `/me/collection/dossiers/**` không đụng `/me/collection/{evidenceId}` — literal `/dossiers` thắng path variable trong cùng base path.

### Notes đã chốt GAME-05 (Item Unlock Rule Engine V2 — 2026-10-25)

- **`condition` AST grammar** (contract §2.5): `leaf | {all:[leaf,…]} | {any:[leaf,…]}` — `all`/`any` chỉ bọc leaf, không nesting (depth ≤ 2, tối đa 20 children/operator). Parse bởi `ItemConditionParser`, validate tham chiếu + ràng buộc nghiệp vụ bởi `ItemConditionValidator` (event/lesson PUBLISHED, policy configured cho `EVENT_*`, evidence `APPROVED` thuộc `eventId` khai báo + **collectible** (FIX-6: nằm trong `snapshot.evidence[]` của một lesson PUBLISHED hiện tại hoặc đã từng được collect — rule yêu cầu evidence không-ai-collect-được → 400), threshold > 0, không trùng leaf). **Strict shape (FIX-2)**: leaf chỉ chấp nhận trường thuộc shape của type (`COLLECTION_COUNT`/`LESSON_COUNT`/`TOTAL_EVENTS_*` chỉ `threshold` — `eventId`/`lessonId`/`evidenceIds`/`level` → 400; `EVENT_COMPLETED`/`EVENT_MASTERED` chỉ `eventId`; `SPECIFIC_EVIDENCE_SET` chỉ `eventId`+`evidenceIds`; `LESSON_COMPLETED` chỉ `lessonId`; `LESSON_MASTERED` chỉ `lessonId`+`threshold`; `EVENT_EVIDENCE_COUNT` chỉ `eventId`+`threshold`; `LEVEL_AT_LEAST` chỉ `level`); operator node chỉ đúng một key `all` XOR `any` (`{"all":…,"any":…}`, `{"all":…,"type":…}` hay field lạ → 400); không silent-ignore trường thừa/typo. Mọi lỗi → `ItemRuleException` → `400 VALIDATION_ERROR` (GlobalExceptionHandler), không bao giờ 500.
- **Leaf semantics**: `COLLECTION_COUNT` = COUNT(DISTINCT evidence_id) **global** (giữ V1 — rule event-scoped phải dùng `EVENT_EVIDENCE_COUNT`); `EVENT_EVIDENCE_COUNT` = COUNT(DISTINCT evidence_id) `WHERE user_evidence.event_id = eventId` (QA-16: count global 7 không mở item Bạch Đằng ngưỡng 3); `SPECIFIC_EVIDENCE_SET` = tất cả `evidenceIds` ⊆ tập đã collect + thuộc `eventId` + không trùng; `EVENT_COMPLETED`/`EVENT_MASTERED` đọc `user_event_progress` (không recompute); `TOTAL_EVENTS_*` = COUNT(DISTINCT event_id) theo milestone; `LESSON_MASTERED` = best `result_json.knowledgeScore` ≥ threshold; `LEVEL_AT_LEAST` → status `UNSUPPORTED`, không bao giờ satisfied.
- **Evaluation context** `ItemRuleEvaluationContext` — lazy per-request cache (globalEvidenceCount, completedLessonCount/Ids, collectedEvidenceIds, eventEvidenceCounts map, milestoneCache, bestScoreCache, totalEvents*) tránh N+1 khi catalog nhiều item; không cache xuyên request (evaluator trong tx submit/complete phải thấy ghi vừa flush).
- **`ItemRuleEvaluator`** trả `Evaluation(satisfied, root ConditionStatus)` — cây `node ∈ LEAF|ALL|ANY`, `status ∈ SATISFIED|PENDING|UNSUPPORTED`, `current`/`required`, `description` tiếng Việt server-authored; catalog map thẳng sang `Requirement` tree (đã mô tả ở bullet catalog). Không một progress bar tổng hợp — client render từng dòng điều kiện.
- **`InventoryItemResponse` provenance** (additive): `unlockRuleId`, `unlockRuleVersion`, `sourceEventId` — truy vết grant về rule/event cụ thể; `acquisition_source` mới `RULE_UNLOCK` (realtime v2) + `RECONCILE_GRANT` (reserved), giữ `ADMIN_GRANT` cho backfill V1-compat.
- **`AdminItemResponse.Rule`** thêm `ruleVersion`, `conditionJson`, `ruleMetadata` — admin đọc lại đúng AST đã publish. `ruleVersion` = `revision` (thứ tự publish per-item, V27) chứ không phải schema version.
- **GAME-05 FINAL FIX (2026-10-25)** — 4 fix trước GAME-06: (1) grant provenance qua event milestone (`recordIfEarned` 4-tham-số → `source_attempt_id` đúng → `itemsUnlocked` result screen hiển thị badge `EVENT_COMPLETED` trong cùng tx complete; reconcile giữ null, không attempt giả); (2) item-scope guard (`ItemRuleScopeResolver` suy `UNRESOLVED|EVENT_SCOPED|GLOBAL` từ lịch sử rule — chặn publish/grant rule global lên item event-specific, không hard-code mã item); (3) V27 tách `rule_version` (schema) khỏi `revision` (thứ tự publish monotonic per-item — V1 lẫn V2 đều max+1, không giảm/lặp); (4) collectible siết lại — evidence phải được activity `EVIDENCE_SELECT` tham chiếu trong snapshot PUBLISHED hiện tại (không chỉ trong `evidence[]`), fallback `user_evidence` đã collect. Migration mới: `V27__item_rule_revision_schema.sql`; không sửa V24/V25/V26.
- **Flutter**: `ItemRequirementDto` là tree model (`operator`, `eventId`, `lessonId`, `lessonTitle`, `evidenceIds`, `threshold`, `current`, `required`, `satisfied`, `status`, `description`, `conditions`); `isOperator`/`isUnsupported`/`isUnconfigured`/`operatorHeading()`/`describe()`/`progressFraction`; inventory screen render `_RequirementTree` — `UNCONFIGURED` → dòng chữ nghiêng trung lập "Điều kiện mở khóa đang được cập nhật" (icon `tune`, không progress bar, không children); heading `Hoàn thành tất cả/một trong các điều kiện sau` + indented leaf rows (check_circle/radio/block icon theo status), progress bar chỉ dưới leaf đếm PENDING, UNSUPPORTED muted — không single aggregate bar.

### Verification results GAME-05 (2026-10-25)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Unit + IT | `.\mvnw.cmd -B -ntp verify` | **PASS** — 316/316 (ItemRuleEngineIT 11/11, ItemUnlockIT 22/22, ItemConditionParserTest 8/8, ItemRuleEvaluatorTest 13/13), Flyway V24+V25 clean |
| Mobile | Format | `dart format --set-exit-if-changed lib/` | **PASS** — 0 changed |
| Mobile | Analyze | `flutter analyze` | **PASS** — 0 issues |
| Mobile | Unit + widget | `flutter test` | **PASS** — 430/430 |

### Notes đã chốt GAME-06 (Admin Gamification CMS — 2026-10-25)

- **Tất cả route `/api/v1/admin/**` đã gate `CONTENT_ADMIN` bởi `SecurityConfig`** — controller không cần `@PreAuthorize` riêng; anonymous → 401, LEARNER → 403 (IT cover).
- **Module A — Completion policy admin**: `policy_version = max+1` khi tạo DRAFT; `PUT /{policyId}` sửa **in-place trên row DRAFT** (user override thay copy-on-write — setter chỉ được gọi sau guard `status == DRAFT` ở service, PUBLISHED immutable theo contract). Publish atomic: `findForUpdate` trên `historical_events` → `collectIssues` revalidate (required ≥1, lesson tham chiếu phải PUBLISHED/thuộc event, `masteryThreshold` 0–100) → archive PUBLISHED cũ **`saveAndFlush` trước** khi insert PUBLISHED mới (partial unique `ux_event_policy_published` — nếu defer flush, unique index va → 500) → `publishedAt`. `expectedPolicyVersion` lệch → service throw `org.springframework.dao.OptimisticLockingFailureException` → **409 `OPTIMISTIC_LOCK_CONFLICT`** (GlobalExceptionHandler giờ bắt superclass `OptimisticLockingFailureException`, không chỉ `ObjectOptimisticLockingFailureException`).
- **Module B — Dossier admin + V28 `historical_dossier_versions`**: `canonicalCode` set một lần khi tạo (kebab-case `^[a-z0-9][a-z0-9-]{1,119}$`, unique → 409). `AdminDossierUpdateRequest` nhận `source` dạng structured `DossierSourceInput` (`title` bắt buộc khi có block source; `reliability ∈ HIGH|MEDIUM|LOW|UNASSESSED`) — **admin không bao giờ gửi raw JSON**; service map sang `{"source":{...}}` trong `source_json`. `validateForPublish` chỉ kiểm `source.title`/`reliability` khi `sourceJson != null` → dossier không source publish được. PUBLISHED vẫn cho `PUT` sửa nội dung → `pendingChanges=true` (nội dung learner đã unlock giữ nguyên ở snapshot pinned); publish mới → `dossier_version = max+1` + insert `historical_dossier_versions` (`status ∈ PUBLISHED|ARCHIVED` theo `chk_dv_status`). `row_version` (V28) optimistic guard `expectedRowVersion` → 409. `PUT /admin/events/{eventId}/dossiers` = **replace-list nguyên tử**: xoá link cũ + insert list mới; mọi `dossierId` phải tồn tại + PUBLISHED (DRAFT/ARCHIVED/không tồn tại → 422), `displayOrder ≥ 0` và không trùng dossierId trong request. Lazy reconcile của learner tự pick up link mới — không fan-out grant khi admin sửa link.
- **Module C — Item rule validate/history + reconcile UI**: `POST /admin/items/{itemId}/rule/validate` chạy đúng pipeline `ItemConditionParser` + `ItemConditionValidator` + `ItemRuleScopeResolver` như `PUT /rule` nhưng không ghi DB — response `acceptsRule` phản ánh scope guard (item `UNRESOLVED`/`EVENT_SCOPED` từ chối rule global → `valid=false`). `GET /admin/items/{itemId}/rule/history` đọc `item_unlock_rule` append-only — mỗi revision kèm `grantCount` (count `user_inventory.unlock_rule_id`) làm audit trail. `POST /admin/rewards/reconcile-unlocks` + `/backfill` đã tồn tại từ GAME-05 — GAME-06 chỉ thêm UI panel confirm trước khi chạy, hiển thị counter thật từ response.
- **Admin UI**: tab `gamification` trong Event Workspace (PolicyEditor chọn required/optional lesson bằng checkbox + threshold + validate/publish; DossierLinkTable reorder + link picker), trang `/dossiers` (list + filter type/status + editor source form), Rule Builder V2 trong `/items/[id]` (AST builder không raw JSON, scope banner, history table) + `ReconcilePanel`. Mọi call qua `apiFetch` + React Query.

### Verification results GAME-06 (2026-10-25)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Unit + IT | `.\mvnw.cmd -B -ntp verify` | **PASS** — 363 IT + 486 unit (AdminCompletionPolicyIT, AdminDossierIT, AdminItemRuleIT + toàn bộ suite cũ), Flyway V28 clean |
| Admin | Typecheck | `npm run typecheck` | **PASS** |
| Admin | Unit tests | `npx vitest run` | **PASS** — 288/288 (+13 test mới: policy-editor, dossier-link-table, dossiers-table, reconcile-panel, scope-banner) |

## Admin client implementation note

`dau-viet-admin` (TASK-0013) consumes this contract through a same-origin BFF layer: the browser only talks to `/api/auth/*` and `/api/proxy/*` inside the Next.js app, which forwards to `/api/v1/*` on `BACKEND_URL`. The refresh token is held in an HttpOnly `dv_refresh` cookie; access tokens live in browser memory only. See `docs/admin-runbook.md` for the full flow.


### Notes đã chốt Luồng Học Lịch Sử & Địa Điểm Di Tích 2.0 (V39–V43, Issues #2–#26)

#### 1. Learning Path 2.0 Hierarchy & Per-Period Progression
- **`GET /api/v1/learning-path`** & **`GET /api/v1/me/learning-path`**:
  - Mỗi phần tử trong `chapters[]` trả thêm `parentId` (`UUID | null`) và `nodeType` (`ERA | PERIOD | PHASE`).
  - `events[]` trả thêm `endYear` (`Integer | null`) và `datePrecision` (`EXACT | CIRCA | CENTURY | PERIOD`).
  - `GET /api/v1/me/learning-path` tự động nâng cấp `enrolledVersion` của learner lên phiên bản `PUBLISHED` mới nhất của `HISTORY_MAIN` và trả thêm:
    - `periodProgress[]`: `[{chapterId, code, title, completedEvents, requiredEvents, completedLessons, requiredLessons, percent}]`
    - `currentByPeriod`: map `periodCode -> {chapterId, eventNodeId, lessonId}`
    - `lastPeriodCode`: mã thời kỳ người học tương tác gần nhất (hoặc thời kỳ đầu tiên chưa hoàn thành)
    - `current`: con trỏ `{chapterId, eventNodeId, lessonId}` của `lastPeriodCode`.
- **`POST /api/v1/me/learning-path/periods/{periodCode}/touch`**:
  - Authenticated learner; cập nhật `user_path_period_state.last_touched_at` cho `periodCode` thuộc `HISTORY_MAIN` hiện hành → trả `200 {periodCode, chapterId, touchedAt}`. Nếu `periodCode` không tồn tại hoặc không phải `PERIOD` → `404 NOT_FOUND`.
- **Admin Path Hierarchy (`CONTENT_ADMIN`)**:
  - `POST /api/v1/admin/learning-path/versions/{id}/chapters` & `PATCH .../chapters/{chapterId}` nhận thêm `parentId` (`UUID | null`) và `nodeType` (`ERA | PERIOD | PHASE`, mặc định `PERIOD`).
  - Vi phạm quy tắc phân cấp (`ERA` có parent, `PERIOD` trỏ vào non-ERA, `PHASE` không trỏ vào `PERIOD`, gắn event vào `ERA`, chu trình, hoặc xóa node còn con) → `422 PATH_NODE_INVALID_PARENT`.

#### 2. Heritage Locations V2 & Unlock Engine
- **`GET /api/v1/map/locations`** (query optional `?periodCode=&eventId=&kind=&unlocked=`):
  - Trả danh sách địa điểm `PUBLISHED` (loại bỏ `HIDDEN_UNTIL_UNLOCKED` khi `unlocked=false`).
  - Mỗi phần tử giữ nguyên các trường v1 (`id, eventId, eventTitle, title, description, latitude, longitude, unlockState, requiredLesson`) và bổ sung:
    - `slug`, `shortSummary`, `kind`, `coordinatePrecision`, `visibility`, `unlockMode` (`NONE | ANY | ALL`), `unlocked` (`boolean`), `coverAssetId`, `eventIds[]`, `unlockLessons[]` (`{lessonId, title, completed, accessible}`).
- **`GET /api/v1/map/locations/{id}`**:
  - Trả chi tiết địa điểm kèm `events[]` (`{eventId, title, yearLabel, role}`) và `media[]` (`{id, mediaType, title, caption, assetId, assetUrl, externalUrl, visibility, sortOrder}`).
  - **Bảo mật nội dung**: khi `unlocked=false`, server tự động lọc bỏ toàn bộ phần tử `media[]` có `visibility == 'UNLOCKED_ONLY'`.
- **`POST /api/v1/attempts/{attemptId}/complete`**:
  - `CompleteAttemptResponse` bổ sung trường additive `newlyUnlockedLocations`:
    ```json
    "newlyUnlockedLocations": [
      {
        "locationId": "uuid",
        "slug": "bai-coc-bach-dang",
        "title": "Bãi cọc Bạch Đằng (Yên Giang)",
        "kind": "HERITAGE_SITE",
        "coverAssetId": "uuid"
      }
    ]
    ```
  - Đánh giá mở khóa địa điểm trong cùng transaction `doComplete` qua `LessonCompletionHook`.
- **Admin Heritage Locations (`CONTENT_ADMIN`)**:
  - `GET /api/v1/admin/map-locations?q=&kind=&status=&eventId=&page=&size=`
  - `POST /api/v1/admin/map-locations`
  - `GET /api/v1/admin/map-locations/{id}`
  - `PATCH /api/v1/admin/map-locations/{id}?expectedRowVersion=`
  - `POST /api/v1/admin/map-locations/{id}/status?status=DRAFT|PUBLISHED|ARCHIVED&expectedRowVersion=`
  - `PUT /api/v1/admin/map-locations/{id}/events` (`[{eventId, role, sortOrder}]`)
  - `PUT /api/v1/admin/map-locations/{id}/unlock-lessons` (`{unlockRuleMode: "NONE"|"ANY"|"ALL", lessonIds: [UUID]}`)
  - `PUT /api/v1/admin/map-locations/{id}/media` (`[{mediaType, title, caption, assetId, externalUrl, visibility, sortOrder}]`)
  - Các endpoint legacy `/api/v1/admin/events/{eventId}/map-locations` được giữ nguyên để tương thích ngược.
  - **Chính sách Deprecation (`ADR-009`)**: Cột DB `map_locations.event_id` và `map_locations.unlock_lesson_id` cùng trường DTO v1 `requiredLesson` được giữ tương thích ngược trong giai đoạn chuyển tiếp; các client mới bắt buộc dùng `eventIds[]`, `events[]`, `unlockMode` và `unlockLessons[]`. Hai cột DB cũ sẽ được gỡ ở Milestone M4 Cleanup theo lộ trình Expand-and-Contract trong `docs/DATABASE_DESIGN.md`.

### Verification results Luồng Học Theo Thời Kỳ & Bản Đồ Di Sản 2.0 (Issue #26 — 2026-10-28)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Path + Heritage E2E ITs | `sh ./mvnw test -Dtest=LearningFlowHeritageEndToEndIT,LearningPathHierarchyAndPeriodIT,LearningPathApiIT,HeritageLocationV2IT` | **PASS** — 12/12 (trên PostgreSQL 16 Testcontainers, Flyway V1–V48 clean) |
| Mobile | Learning Path + Dashboard + Campaign E2E | `flutter test --no-pub test/learning_path/ test/dashboard/ test/campaign/ test/campaign_detail_test.dart` | **PASS** — 35/35 |
