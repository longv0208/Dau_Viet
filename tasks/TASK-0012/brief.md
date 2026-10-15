# TASK-0012 — Learner Attempts, Progress, Resume & Idempotency

Build on TASK-0007 through TASK-0011. Reuse the existing Learning Engine,
ActivityHandlers, Attempt APIs, database tables, and published LessonVersion
contracts. Do not redesign completed modules.

## Objective

Complete the learner attempt lifecycle, persistent progress tracking, safe
resume, lesson completion, and idempotent submission handling. The backend
must reliably preserve learner progress across app restarts, network retries,
concurrent requests, and lesson republishing.

## Scope (from pasted brief)

1. Attempt lifecycle: start/resume/submit/complete; completed attempts reject
   further submissions; completion persisted exactly once.
2. Resume & persistent progress across restart/logout/network/republish;
   resolve the version-specific resume limitation from TASK-0011 without
   breaking version pinning; never auto-replace an in-progress attempt.
3. Persistent `Idempotency-Key` on `idempotency_records` (user+operation+key,
   request fingerprint, replay stored response, different payload -> 409,
   no double-write, same transaction, documented retention, no in-memory
   correctness).
4. Submission integrity: append-only activity_attempts, retry limits,
   required gating, optional semantics per TASK-0011, pinned snapshot only.
5. `POST /api/v1/attempts/{attemptId}/complete`: server re-evaluates, refuses
   incomplete with structured error, atomic COMPLETED + completed_at +
   lesson_results row (unique per attempt), safe under repeat/concurrency.
6. Progress & history APIs: in-progress attempts, completed history, result
   (`GET /attempts/{id}/result`), progress summaries, resume info; owner-only,
   paginated, no answer keys.
7. Transactional consistency; additive Flyway migration only if required.
8. Security: auth required, ownership on all reads/writes, malformed JWT
   subject -> controlled 401.
9. Comprehensive unit + Postgres Testcontainers ITs per brief §9.
10. Docs: API_SPEC, LEARNING_ENGINE_DESIGN, task evidence, Vietnamese final
    report.

## Out of scope

Flutter UI, Next.js admin, new ActivityTypes, EXP/rewards unless required by
the existing approved completion contract, shop/island/energy, unrelated
refactoring. No push/merge without permission.
