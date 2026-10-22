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
| GET | `/me/progress` | Resume surface: IN_PROGRESS attempts + completed count — **implemented TASK-0012** |

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
  "completion": {"complete": false, "reason": "ALL_REQUIRED_STAGES"}
}
```

**Không** cho Flutter gửi `correct`, `earnedExp`, `isCompleted`, `nextStageId` với quyền quyết định. Backend tính các dữ liệu đó từ snapshot/rule và state server.

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
- `GET /attempts/{id}/result` — owner-only; `404 RESULT_NOT_FOUND` trước khi completed. Response `{attemptId, lessonVersionId, status, score, result, completedAt, startedAt}` — `score` là **completion percentage** (0-100, 2 chữ số) = required activities đã completed / totalRequired, **không phải điểm đánh giá**: required activity tính completed kể cả khi hết retry trên đáp án sai (quy tắc exhausted-still-advances TASK-0011). `result` là result_json snapshot `{attemptId, lessonVersionId, reason, score, completedRequired, totalRequired, detail}`; không có hidden answer keys.
- `GET /me/attempts?status=&page=&size=` — PageResponse `{content, page, size, totalElements, totalPages}` của riêng learner (mọi attempts mọi status, `size` tối đa 50, newest `lastActiveAt` trước); mỗi row `AttemptSummaryResponse {attemptId, lessonId, lessonVersionId, status, currentStageId, currentActivityId, progress, startedAt, lastActiveAt, completedAt}`. `GET /me/progress` — `{inProgress: [AttemptSummaryResponse...], completedCount}` cho màn resume của mobile. Attempt của user khác không bao giờ lộ.
- Idempotency-Key (TASK-0012): persist trên `idempotency_records`, scope `(user_id, operation, key)` với operation `SUBMIT_ACTIVITY`/`COMPLETE_ATTEMPT`; `request_hash` = SHA-256(`attemptId|activityId|canonical(answer)`) cho submit, `attemptId` cho complete. Cùng key + cùng fingerprint → `200` replay stored response (không re-evaluate, không append row); cùng key + payload khác → `409 IDEMPOTENCY_CONFLICT` — client phải mint key mới cho mỗi action khác nhau (kể cả cùng attempt, activity khác). Concurrent cùng-key serialize trên attempt row lock → loser thấy committed response, không double-write. Claim row + response + activity_attempts commit cùng transaction; business error rollback cả claim nên key không bị burn. TTL mặc định 24h (`app.learning.idempotency-ttl`); record hết hạn bị xoá + reclaim. Không gửi key → execute thẳng, không ghi record.
- `completion` config (AND-combination): `requireAllRequiredStages` (mọi stage `required:true` xong hết required activities), `requiredStageIds` (subset chỉ định — đếm `required:true` bên trong stage đó, kể cả stage optional), `minScore` (% required activities đã xong trên tổng). Không có config → default `DEFAULT_ALL_REQUIRED`. **`stage.required=false`** → toàn bộ activities bên trong optional (không đếm `totalRequired`, không gate completion, cursor không vào); `activity.required=true` trong optional stage → publish `422 REQUIRED_IN_OPTIONAL_STAGE`. **Config rỗng/không-clause** (`completion:{}`, hoặc chỉ giá trị falsy/empty/null) cũng → `DEFAULT_ALL_REQUIRED` — không bao giờ complete sớm; publish-time reject `completion:{}` (`422 EMPTY_COMPLETION`). Reason enum: `ALL_REQUIRED_STAGES` | `REQUIRED_STAGE_IDS` | `MIN_SCORE` | `DEFAULT_ALL_REQUIRED` | `NOT_COMPLETE`.
- Evaluation outcomes per handler: `COMPLETED` | `INCORRECT` | `PARTIAL` | `SUPPORTED` | `CONTRADICTED`. MCQ `maxAttempts` (default 1) đạt giới hạn → `exhausted:true` và activity vẫn tính completed cho transition.
- Error codes mới: `ATTEMPT_NOT_FOUND`(404), `ATTEMPT_NOT_OWNER`(403), `ATTEMPT_NOT_IN_PROGRESS`(409), `ATTEMPT_ALREADY_COMPLETED`(409), `ACTIVITY_NOT_AVAILABLE`(409), `ACTIVITY_ALREADY_SUBMITTED`(409), `SNAPSHOT_INVALID_FOR_ACTIVITY`(422), `LESSON_VERSION_MISMATCH`(422). TASK-0012 thêm: `IDEMPOTENCY_CONFLICT`(409 — cùng key khác payload, hoặc key đang in-flight), `ATTEMPT_NOT_COMPLETE`(409 — complete khi chưa đủ requirements, `details` mang `LessonCompletion.detail`), `RESULT_NOT_FOUND`(404 — `/result` trước khi completed).

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
- `GET /api/v1/me/inventory` — array `InventoryItemDto` đã sở hữu, mới nhất trước: `{itemId, code, name, description, category, itemType, rarity, assetId, acquiredAt, acquisitionSource, sourceLessonId}`.
- `GET /api/v1/me/inventory/catalog` — union item `active` + item learner đã sở hữu (kể cả sau khi admin tắt), dedupe theo itemId, sort theo code; mỗi item thêm `owned`, `acquiredAt` (nếu owned), `requirement {type, lessonId?, lessonTitle?, threshold?, current}` (progress hiện tại của learner), `sourceNote` (từ `source_metadata.note` — disclaimer "không phải hiện vật thật"). Item inactive không sở hữu vẫn ẩn; ownership không bao giờ bị thu hồi.
- `GET /attempts/{id}/result` trả thêm `rewards` (danh sách bút toán của attempt — thường 2) và `itemsUnlocked` (items có `source_attempt_id` = attempt đó) — additive, không đổi field cũ.
- **Item unlock rules** (`item_unlock_rule`, một active rule mỗi item): `LESSON_COMPLETED` (lesson cụ thể — đánh giá trong `complete()`), `COLLECTION_COUNT` (N evidence khác nhau trong collection — đánh giá trong transaction submit được chấp nhận **và** trong `complete()`), `LESSON_COUNT` (N lesson khác nhau completed — đánh giá trong `complete()`). Grant qua `user_inventory` `ON CONFLICT (user_id, item_id) DO NOTHING` — không stack, không revoke khi rule đổi/deactivate.
- **Backfill**: `POST /api/v1/admin/rewards/backfill` (CONTENT_ADMIN) → `{attemptsGranted}`; chỉ attempt COMPLETED **sớm nhất** mỗi `(user, lesson)` chiếm slot (sắp `completed_at ASC`); mỗi **loại thưởng** được bổ sung độc lập — EXP có mà HISTORY_POINTS thiếu thì chỉ insert loại thiếu, không sửa bút toán cũ. Gọi lại n lần vẫn an toàn.
- **Reconcile unlocks**: `POST /api/v1/admin/rewards/reconcile-unlocks` (CONTENT_ADMIN) → `{itemsGranted}`; đánh giá mọi `item_unlock_rule` ACTIVE trên item ACTIVE theo tiến độ lịch sử (`learner_attempts COMPLETED` cho `LESSON_COMPLETED`/`LESSON_COUNT`, `user_evidence` DISTINCT cho `COLLECTION_COUNT`) và `INSERT … ON CONFLICT (user_id, item_id) DO NOTHING` với `acquisition_source = 'ADMIN_GRANT'`; `source_lesson_id = rule.lesson_id` và `source_attempt_id` = một attempt COMPLETED bất kỳ của learner cho `LESSON_COMPLETED`, `NULL` cho counted rules. Idempotent — không revoke, không grant EXP/History Points, không đụng attempt state; hành động tường minh của admin, KHÔNG chạy tự động lúc startup hay trong GET.
- **Admin items**: `GET /api/v1/admin/items` (list + rule hiện hành, page/size clamp ≤100), `GET /api/v1/admin/items/{itemId}`, `POST /api/v1/admin/items` → 201, `PUT /api/v1/admin/items/{itemId}` (**partial update** — field null trong request = "không đổi", `assetId`/`sourceMetadata` giữ nguyên khi sửa metadata; xoá có chủ đích qua `clearAsset:true` hoặc `sourceMetadata:{}`; `@Version row_version` optimistic lock), `PUT /api/v1/admin/items/{itemId}/rule` (`{ruleType, lessonId?, threshold?, active}` — shape theo `chk_unlock_rule_shape`; `LESSON_COMPLETED` yêu cầu lesson **PUBLISHED** — missing/draft/archived → 400; pessimistic lock trên item row + flush rule cũ trước insert để ux-item-one-active không bị vi phạm), `DELETE` = soft (`active=false`). Tất cả `CONTENT_ADMIN`.
- **RewardPolicy config** `dauviet.rewards.first-completion.exp` / `history-points` — validate `> 0` lúc startup (IllegalStateException khi sai; CHECK `amount>0` của DB không bao giờ bị đụng).
- Không thêm error code mới: item không tồn tại → `404` (ResourceNotFoundException chung); rule sai shape / `size` là tham số page (clamp về max, không 400); trùng `code` / lệch `expectedRowVersion` → `409` qua DataIntegrityViolation / optimistic-lock handler hiện có.
- Mobile: `LessonResultDto` thêm `rewards`/`itemsUnlocked` — màn kết quả chỉ **hiển thị** dữ liệu server trả (không POST hoàn thành lần hai). `InventoryScreen` dùng `GET /me/inventory/catalog` thật (owned/locked + progress `current/threshold`), providers session-scoped invalidate sau submit (COLLECTION_COUNT có thể grant mid-attempt) và complete.

### Verification results TASK-0023 (2026-10-22, focused bugfix pass)

| Module | Check | Command | Result |
|---|---|---|---|
| Backend | Unit + IT | `.\mvnw.cmd test -Dtest='*IT'` | **PASS** — 226/226 (RewardGrantIT 13/13, ItemUnlockIT 21/21), Flyway V12+V13 clean |
| Admin | Lint | `npm run lint` | **PASS** — 0 warnings |
| Admin | Typecheck | `npx tsc --noEmit` | **PASS** |
| Admin | Unit tests | `npm test` | **PASS** — 116/116 |
| Admin | Build | `npm run build` | **PASS** |
| Mobile | Format | `dart format --output=none --set-exit-if-changed lib test` | **PASS** |
| Mobile | Analyze | `flutter analyze` | **PASS** — 0 issues |
| Mobile | Unit + widget | `flutter test` | **PASS** — 164/164 |

## Admin client implementation note

`dau-viet-admin` (TASK-0013) consumes this contract through a same-origin BFF layer: the browser only talks to `/api/auth/*` and `/api/proxy/*` inside the Next.js app, which forwards to `/api/v1/*` on `BACKEND_URL`. The refresh token is held in an HttpOnly `dv_refresh` cookie; access tokens live in browser memory only. See `docs/admin-runbook.md` for the full flow.
