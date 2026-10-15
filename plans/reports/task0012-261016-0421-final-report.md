# TASK-0012 — Báo cáo cuối: Learner Attempts, Progress, Resume & Idempotency

Ngày: 2026-10-16 · Commit: `35b9d0d` · Status: done

## 1. Chức năng đã triển khai

### 1.1 Resume theo lesson (không phải version)
- `POST /lessons/{id}/attempts`: tra `learner_attempts` IN_PROGRESS join `lesson_versions.lesson_id` trước — attempt v1 sống sót republish v2, `resumed=true`, pin version cũ, progress giữ nguyên. Không bao giờ tự thay attempt đang chạy.
- Không đổi schema (không cần V7): partial unique index `ux_attempt_active_user_version` chỉ theo `(user_id, lesson_version_id)` — race 2 start cùng lúc được xử lý bằng catch `DataIntegrityViolationException` + re-query trong transaction mới (TransactionTemplate), trả attempt thắng về cho loser thay vì 500.

### 1.2 Idempotency-Key persistent trên `idempotency_records`
- Scope `(user_id, operation, idempotency_key)`; `operation` = `SUBMIT_ACTIVITY`/`COMPLETE_ATTEMPT`.
- `request_hash` = SHA-256(`attemptId|activityId|canonical(answerJson)`) cho submit (canonical = sort field đệ quy — cùng payload khác thứ tự field → trùng hash), `attemptId` cho complete.
- `submit()`/`complete()` lock `learner_attempts` PESSIMISTIC_WRITE **trước** khi tra idempotency → duplicate concurrent serialize trên row lock, thấy committed response → không double-write.
- Claim row `saveAndFlush` + response (`response_json`, `http_status=200`) commit cùng transaction với `activity_attempts`/state — business error rollback luôn claim, key không bị burn.
- Cùng key + cùng fingerprint → `200` replay stored response (không re-evaluate, không append row). Cùng key + payload khác → `409 IDEMPOTENCY_CONFLICT`. Claim race cross-attempt → `409`. Key > 160 ký tự → `409` sớm.
- TTL `app.learning.idempotency-ttl` (default 24h); record hết hạn → xoá + reclaim. Không gửi key → execute thẳng, không ghi record. Không dùng in-memory cache cho correctness.

### 1.3 Completion server-authoritative
- `POST /attempts/{id}/complete`: lock → `COMPLETED` → trả stored verdict `alreadyCompleted=true` (idempotent repeat); không `IN_PROGRESS` → `409 ATTEMPT_NOT_IN_PROGRESS`; `completionEvaluator` `!complete` → `409 ATTEMPT_NOT_COMPLETE` + `details` (missing stages/reason); else `markCompleted` + `lesson_results` row (unique per attempt) cùng tx.
- `score` = `completedRequired*100/totalRequired` percent, HALF_UP 2 decimals (0 khi totalRequired=0 — đã document).
- Submit trên `COMPLETED` → `409 ATTEMPT_ALREADY_COMPLETED`; start sau complete → attempt mới pin version hiện tại.
- Client không tự declare completion được — server re-evaluate trên persisted state.

### 1.4 Progress & history APIs (owner-only)
- `GET /attempts/{id}/result` — `404 RESULT_NOT_FOUND` trước khi complete; `{attemptId, lessonVersionId, status, score, result, completedAt, startedAt}`.
- `GET /me/attempts?status=&page=&size=` — PageResponse `{content, page, size, totalElements, totalPages}`, `size≤50`, newest `lastActiveAt` trước; `AttemptSummaryResponse` mang cursor + progress cho resume.
- `GET /me/progress` — `{inProgress[] (bounded 50), completedCount}` cho màn resume mobile.
- `lessonId` resolve qua `lesson_versions`; snapshot corrupt → progress `0/0` thay vì 500.

### 1.5 Security
- `JwtSubjectExtractor` chung (common.security): malformed `sub` → `AuthenticationFailedException` → `401` trên mọi learner endpoint — không 500, không bypass ownership. `UserController` đã migrate.
- Ownership enforce trên mọi read/write (`loadOwned` / locked-row check).
- Không hidden answer keys trong response mới (`result_json` chỉ mang counts/reason/score; `HiddenKeyLeakIT` mở rộng sang `/result`, `/me/attempts`, `/me/progress`).

## 2. Kết quả verify thực tế

`mvnw verify` (Docker Testcontainers, postgres:16-alpine) — **148 unit + 148 IT, 0 failures, BUILD SUCCESS** (sau review fixes).

| Nhóm test | Số test | Nội dung chứng minh |
|---|---|---|
| `ResumeAndHistoryIT` | 4 | resume-sau-republish giữ attempt v1 pinned (vẫn grade theo v1 keys), không tạo attempt thứ 2; `/me/attempts` paged + owner-only; `/me/progress` resume surface; progress reload từ DB |
| `IdempotencyIT` | 6 | same-key replay không duplicate row; different-payload 409; scope per operation/user; concurrent same-key không double-write; no-key passthrough; failed submit không burn key |
| `AttemptCompletionIT` | 6 | premature 409 `ATTEMPT_NOT_COMPLETE`; success flip đúng 1 lần + `lesson_results` (score 100.00); repeat trả stored result; concurrent completes serialize 1 row; submit-on-completed 409 `ATTEMPT_ALREADY_COMPLETED`; `/result` owner+timing |
| `LearnerAttemptConcurrencyIT` | 2 | concurrent start → 1 row, mọi caller 200 cùng attemptId; concurrent submits serialize |
| `MalformedSubjectIT` + `JwtSubjectExtractorTest` | 2+4 | malformed `sub` → 401 (không 500) trên mọi endpoint |
| `IdempotencyServiceTest` | 5 | SHA-256 fingerprint ổn định; canonical sort field mọi độ sâu; hash scope theo attempt |
| `HiddenKeyLeakIT` | 1 | quét `LEARNER_HIDDEN_KEYS` trên toàn bộ learner surface kể cả `/result` + history |
| Regressions | — | toàn bộ TASK-0007..0011 suites xanh |

## 3. Code review

`code-reviewer` agent: **không blocker**, ship-ready sau khi xử lý 2 should-fix:
- Concurrent start race → catch + resume-winner (đã implement + IT).
- Cross-attempt same-key claim race → `409 IDEMPOTENCY_CONFLICT` (đã implement).
- Key > 160 → `409` sớm (đã implement).
- `myProgress` bounded 50 (đã implement).
- Hidden-key regression net mở rộng (đã implement).
- Javadoc `IdempotencyService` đã sửa.

Không áp dụng (ghi nhận, không phải defect): `score=0` khi `totalRequired=0` (đã document, hợp lý hơn 100 cho lesson không có việc gì); admin controllers chưa migrate `JwtSubjectExtractor` (đã đúng hành vi, YAGNI); N+1 snapshot parse trong history (chấp nhận ở quy mô MVP); DTO thiếu `lessonTitle`/`versionNo`/`score`/`totalAttempts` so với sketch phase-04 (AC-5/AC-6 vẫn đủ — xác nhận mobile trước khi khoá contract); keyed-replay `alreadyCompleted=false` vs no-key recompute `true` (asymmetry vô hại — API_SPEC đã ghi stored replay); `application.yml` chưa khai `app.learning.idempotency-ttl` (default 86400 cover, documented).

## 4. Vấn đề còn ảnh hưởng product

- Race giữa 2 start cùng lúc **không còn** trả 500 (đã fix) nhưng vẫn có thể tạo 2 attempt khi user start 2 lesson khác nhau đồng thời — đúng semantics (one-per-lesson, không phải one-per-user).
- `result_json` chưa có field reward/EXP — chờ TASK reward; `score` chỉ là % required (PO xác nhận nếu muốn weight/khác).
- TTL 24h là default — PO xác nhận nếu retention khác.

## 5. Sẵn sàng tích hợp frontend

- Contract ổn định: `AttemptStartResponse.resumed` + cursor fields cho resume flow; `CompleteAttemptResponse.alreadyCompleted` phân biệt flip mới vs replay; `AttemptSummaryResponse` đủ cho resume card không cần call phụ.
- Idempotency-Key: client mint key mới cho mỗi action khác nhau (kể cả cùng attempt, activity khác — fingerprint cover); retry an toàn với cùng key.
- 401/403/404/409 envelope `ApiError{code,message,details,traceId}` nhất quán.
- Chưa push (theo quy tắc); commit `35b9d0d` trên `main` local.

## 6. Câu hỏi mở cho PO

- `score` = % required completed — đúng ý định chấm điểm?
- Retention idempotency 24h — chấp nhận?
- `LessonResultResponse`/`AttemptSummaryResponse` cần thêm `lessonTitle`/`versionNo`/`score` cho UI không?
