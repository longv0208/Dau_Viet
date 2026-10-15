---
title: "TASK-0012 — Attempt Lifecycle, Idempotency & Progress APIs"
description: "Finalize attempt lifecycle (complete flip + lesson_results), per-lesson resume, persistent Idempotency-Key, progress/history endpoints, owner+JWT hardening, tests, docs."
status: pending
priority: P1
effort: 10h
branch: main
tags: [backend, learning-engine, idempotency, attempt-lifecycle]
created: 2026-10-16
---

# TASK-0012 — Attempt Lifecycle, Idempotency & Progress APIs

Finalize the learner attempt runtime started in TASK-0011: real completion transition
(status flip + `lesson_results`), persistent `Idempotency-Key` via `idempotency_records`,
resume-by-lesson (not by-version), new progress/history/result endpoints, and the tests
+ docs to back them.

## Phases

| # | File | Scope | Effort |
|---|------|-------|--------|
| 01 | [phase-01-resume-by-lesson.md](phase-01-resume-by-lesson.md) | Resume across republish: query by (user, lesson) via join; one active attempt per user+lesson | 1.5h |
| 02 | [phase-02-complete-lifecycle.md](phase-02-complete-lifecycle.md) | `POST /attempts/{id}/complete` flips status + writes `lesson_results` atomically, idempotent | 2h |
| 03 | [phase-03-idempotency-records.md](phase-03-idempotency-records.md) | Persist `Idempotency-Key` in `idempotency_records` for submit + complete; request hash; 409 on payload mismatch; replay stored response | 2.5h |
| 04 | [phase-04-progress-history-apis.md](phase-04-progress-history-apis.md) | `GET /attempts/{id}/result`, `GET /me/attempts` (in-progress + history, paged), `GET /me/progress` summary | 2h |
| 05 | [phase-05-security-tests-docs.md](phase-05-security-tests-docs.md) | Malformed JWT subject → 401; ITs (idempotency, concurrency, completion, resume-after-republish, pagination, ownership, no key leak); unit tests; docs + task.json | 2h |

## Key decisions (details in phase files)

- **Resume-by-lesson:** JPQL join `learner_attempts` × `lesson_versions` on `lesson_id` — no schema change. In-progress on v1 survives republish of v2; start still pins to `current_version_id` when none active.
- **One-active-attempt-per-lesson:** enforce in service under the existing pessimistic lock path; no new DB index (cannot index a join). Document residual race as accepted MVP risk; two concurrent starts on different versions could both pass the check — mitigate by taking the new attempt insert inside the same `SELECT FOR UPDATE` on `users` row (cheap advisory: lock user row via `userRepository.findForUpdate`) OR accept + document. Chosen: **lock via `learner_attempts` row-level check + service serialization on user-scoped lock**; if too complex, document race + add follow-up.
- **Idempotency storage:** reuse `idempotency_records`; `request_hash = SHA-256(operation | attemptId | activityId? | canonical(answerJson))`. Same key + same hash → replay stored `response_json` + `http_status`. Same key + different hash → `409 IDEMPOTENCY_CONFLICT`. Insert inside same tx as mutation; `UNIQUE(user_id,operation,idempotency_key)` is the race backstop. `expires_at = now() + 24h` (documented, configurable via `app.learning.idempotency-ttl`, default 24h). No in-memory cache.
- **Operation scope:** `SUBMIT_ACTIVITY` and `COMPLETE_ATTEMPT` — scoped by `(user_id, operation, key)`; key itself namespaced per attempt on the client side. We do NOT include attemptId in the uniqueness tuple (table fixed), but `request_hash` covers it: same key reused across attempts with different attemptId → 409 conflict (correct — client must use a fresh key).
- **Completion response:** keep `POST /attempts/{id}/complete` returning `LessonCompletion` shape, extended: `{complete, reason, detail, attemptId, status, completedAt, score}` — `status`/`completedAt`/`score` populated only when the flip happened (first call) or replayed. Reject incomplete with `409 ATTEMPT_NOT_COMPLETE` + same `detail` payload. Repeat call on completed attempt → `200` + stored verdict (idempotent by state, not by key).
- **`lesson_results.score`:** `score = round(100.0 * completedRequired / totalRequired)` — percent of required activities completed; `result_json` stores `{completion:{complete,reason,detail}, progress:{completedRequired,totalRequired}}`. Documents formula for future grading.
- **New error codes:** `IDEMPOTENCY_CONFLICT` (409), `ATTEMPT_NOT_COMPLETE` (409), `RESULT_NOT_FOUND` (404).
- **Result endpoint:** `GET /api/v1/attempts/{attemptId}/result` → `200 {attemptId, lessonId, lessonVersionId, score, completedAt, result}` from `lesson_results`; `404 RESULT_NOT_FOUND` when attempt not completed; owner-only.
- **History/progress:** `GET /api/v1/me/attempts?status=IN_PROGRESS|COMPLETED&page=&size=` → `PageResponse<AttemptSummaryDto>` sorted `lastActiveAt desc`. `GET /api/v1/me/progress` → `{inProgress:[AttemptSummaryDto], completedCount, totals}` — mobile resume surface; no pagination (bounded small by unique index, cap at e.g. 50).
- **Malformed JWT subject:** extract `subjectToUuid` into a small `@Component JwtSubjectExtractor` (or shared static helper in `common.security`) used by `LearnerAttemptController` + `UserController` + admin controllers; throws `AuthenticationFailedException` → 401. Minimal refactor, DRY.
- **No schema migration (V7 not required):** all needed columns/tables exist in V4. `lesson_results` already UNIQUE(learner_attempt_id). Skip V7 — document decision.

## Open questions (for PO/user)

1. Multiple concurrent in-progress attempts across versions — policy: forbid (chosen: resume v1 across republish). Confirm.
2. `idempotency_records` retention: default 24h via config `app.learning.idempotency-ttl` — needs PO sign-off on value.
3. `score` formula = % of required activities completed; confirm vs BA spec (may later become rubric/weighted).
4. Post-completion repeat attempt: allowed (unique index permits). Confirm — affects `GET /me/attempts` listing.
5. `ABANDONED` enum exists but no transition — keep out of scope (YAGNI). Confirm.
6. Should `GET /me/progress` include abandoned attempts? Chosen: no. Confirm.

## Risk notes

- Idempotency replay must serialize response identically — store `response_json` as the exact DTO JSON + `http_status` (200/409); replay returns it verbatim.
- Concurrent complete + submit on same attempt: serialized by `findForUpdate`.
- Concurrent complete ×2: second sees `status=COMPLETED` → replay stored result (no double insert thanks to `lesson_results.learner_attempt_id UNIQUE`).
- Cross-version start race (two concurrent POST /attempts on v1+v2): service-level user lock or accept-and-document (chosen: `findForUpdate` on the attempt's user row for the duration of `startOrResume` — cheap, prevents both passes of the check). Revisit if flaky ITs.

## Files (summary — details per phase)

Modify: `LearnerAttemptService`, `LearnerAttemptController`, `LearnerAttemptRepository`,
`LearnerAttempt`, `GlobalExceptionHandler`, `ErrorCode`, `UserController` (shared extractor),
`AbstractPostgresIT` (idempotency_records + lesson_results cleanup).
New: `IdempotencyService`, `IdempotencyRecord` entity + repo, `LessonResult` entity + repo,
`AttemptSummaryDto`, `AttemptResultResponse`, `ProgressSummaryResponse`, `JwtSubjectExtractor`,
`IdempotencyConflictException`, `AttemptNotCompleteException`, `ResultNotFoundException`,
`MeAttemptController` (or extend `LearnerAttemptController` with `/me/**` routes).
Tests: `LearnerAttemptApiIT` extensions + `AttemptCompletionIT`, `IdempotencyIT`,
`AttemptHistoryIT`, `ResumeAcrossRepublishIT` + unit tests for evaluator/idempotency hash.
Docs: `docs/API_SPEC.md`, `docs/LEARNING_ENGINE_DESIGN.md` (new §14 decisions),
`tasks/TASK-0012/task.json` + `brief.md`.
