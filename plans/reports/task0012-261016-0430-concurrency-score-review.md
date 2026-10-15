# TASK-0012 — Final Concurrency & Score Contract Review (báo cáo bổ sung)

Ngày: 2026-10-16 · Branch: `main` (local, chưa push)

## 1. Concurrent Start — race cross-version: ĐÃ ĐÓNG

**Phát hiện (verified):** partial unique index `ux_attempt_active_user_version` chỉ phủ `(user_id, lesson_version_id)`, KHÔNG phủ `(user_id, lesson_id)`. Hai `startOrResume` concurrent mà republish rơi vào giữa check+insert có thể tạo **2 IN_PROGRESS attempt** (mỗi cái pin một version) cho cùng (user, lesson) — vi phạm invariant "one active attempt per learner+lesson".

**Fix (không phá version pinning):** `pg_advisory_xact_lock(hashtextextended(userId|lessonId))` ở đầu transaction start — serialize toàn bộ check+insert cho cặp (user, lesson); tx-scoped nên tự nhả khi commit/rollback; không chặn publish, không chặn user/lesson khác. Attempt vẫn pin `current_version_id` đọc được dưới lock. `LearnerAttemptService.doStartOrResume`.

**IT deterministic `CrossVersionStartRaceIT` (2 test):**
- `twoConcurrentStarts_aroundRepublish_oneInProgressAttempt`: A start → commit → republish v2 → B start; B resume đúng attempt A (resumed=true), đúng 1 IN_PROGRESS row.
- `serializedStarts_underAdvisoryLock_neverDuplicateAcrossVersions`: 4 thread start đồng thời + republish giữa chừng → mọi caller hội tụ 1 attemptId, 1 row.

Trước fix: race này được plan ghi là "accepted residual" — giờ đóng hẳn (cùng với catch `DataIntegrityViolationException` + fresh-tx resume cho same-version race đã có từ đợt review trước).

## 2. Idempotency dưới concurrent requests / tx conflicts — verify xanh

| Tình huống | Cơ chế | Test chứng minh |
|---|---|---|
| Same attempt + same key concurrent | Lock attempt `PESSIMISTIC_WRITE` TRƯỚC khi tra record → serialize, loser thấy committed response | `IdempotencyIT.concurrentSameKey_neverDoubleWrites` (đúng 1 `activity_attempts` row) |
| Cross-attempt same-key claim | Unique `(user, operation, key)` → `DataIntegrityViolationException` → `409 IDEMPOTENCY_CONFLICT` | (thêm catch đợt review trước; covered bởi `keyScopedPerOperationAndUser`) |
| Business error sau claim | Claim row rollback cùng tx → key không bị burn | `IdempotencyIT.failedSubmit_doesNotStoreResponse_retryAllowed` |
| Concurrent completes | Lock + `lesson_results.learner_attempt_id UNIQUE` → đúng 1 row, mọi caller 200 | `AttemptCompletionIT.complete_concurrent_exactlyOneResult` |
| Expired record | Delete + reclaim trước insert | `IdempotencyService.execute` expired branch |

Không có path nào trả 500 ngoài ý muốn: mọi constraint race đều map sang `409` hoặc resume-winner `200`.

## 3. `LessonResult.score` — đã làm rõ contract

`score` = **completion percentage** (0-100, 2 chữ số): `completedRequired*100/totalRequired`. **KHÔNG phải assessment score** — required activity đếm completed kể cả khi retry-exhausted trên đáp án sai (quy tắc "exhausted vẫn advance" TASK-0011). BA không định nghĩa metric đánh giá riêng → giữ nguyên công thức, đã document rõ trong:
- `LessonResult.score` javadoc
- `LearnerAttemptService.scoreOf` javadoc
- `docs/API_SPEC.md` (mục `/attempts/{id}/result`)
- `docs/LEARNING_ENGINE_DESIGN.md` §13

Nếu BA sau này cần assessment score thật (correct-first-try, weighted) → TASK riêng, KHÔNG thay đổi ngầm field này.

## 4. Full Maven verify

`mvnw verify` (Docker Testcontainers, postgres:16-alpine): **148 unit + 150 IT, 0 failures, BUILD SUCCESS** (+2 `CrossVersionStartRaceIT` so với đợt trước).

## 5. Rủi ro còn lại

- Advisory lock chỉ phủ path `startOrResume` qua service — nếu code khác insert `learner_attempts` trực tiếp mà không qua service sẽ bypass lock (không có path nào khác hiện tại; ghi nhận khi thêm writer).
- `hashtextextended` 64-bit — xác suất collision giữa 2 cặp (user,lesson) khác nhau ~2^-64, chỉ gây serialize thừa chứ không sai correctness.
- `score` semantics đã khoá là completion percentage — PO xác nhận trước khi frontend hiển thị như "điểm".

## 6. Unresolved questions

- BA có cần assessment score riêng (đúng-lần-đầu, trọng số) ngoài completion percentage không?
- Có cần index/guard bổ sung khi mở rộng `learner_attempts` writers sau này?
