# Phase 02 — Complete Lifecycle (atomic flip + lesson_results)

## Context

- TASK-0011 `complete()` is read-only — returns `LessonCompletion` verdict, no
  status flip, no `lesson_results` row.
- `LearnerAttempt.markCompleted()` already exists (status + completed_at +
  last_active_at). `lesson_results` table already UNIQUE on `learner_attempt_id`.
- Brief §1: "completed attempts reject further submissions; completion persisted
  exactly once via POST /api/v1/attempts/{attemptId}/complete (server re-evaluates,
  refuses incomplete with structured error, atomic status flip to COMPLETED +
  completed_at + lesson_results row, unique per attempt, idempotent under
  repeat/concurrent calls)."

## Design

### Endpoint

`POST /api/v1/attempts/{attemptId}/complete` — owner-only, `Idempotency-Key`
header accepted (Phase 03 wires it).

### Service flow (`LearnerAttemptService.complete`)

```
@Transactional
public LessonCompletionResult complete(UUID userId, UUID attemptId, String idemKey) {
    // Phase 03 wraps with idempotency check before this body and response
    // persistence after. Signature returns the DTO; idempotency layer handles
    // replay.
    LearnerAttempt a = attempts.findForUpdate(attemptId)   // lock (serialize)
        .orElseThrow(AttemptNotFoundException);
    if (!a.getUserId().equals(userId)) throw AttemptNotOwnedException;

    if (a.getStatus() == COMPLETED) {
        // Idempotent replay — return stored verdict; do NOT write again.
        LessonResult stored = results.findByLearnerAttemptId(attemptId)
            .orElseThrow(SNAPSHOT_CORRUPT);   // unreachable by invariant
        return toResponse(a, stored);
    }
    if (a.getStatus() != IN_PROGRESS) throw AttemptNotInProgressException;

    SnapshotModel model = snapshotOf(a.getLessonVersionId());
    AttemptState state = AttemptState.fromJson(parse(a.getStateJson()));
    LessonCompletion verdict = completionEvaluator.evaluate(model, state);

    if (!verdict.complete()) {
        throw new AttemptNotCompleteException(verdict);   // 409 ATTEMPT_NOT_COMPLETE
    }

    a.markCompleted();
    attempts.save(a);

    int total = progressOf(model, state).totalRequired();
    int done  = progressOf(model, state).completedRequired();
    double score = total == 0 ? 100.0 : Math.round(10000.0 * done / total) / 100.0;

    ObjectNode resultJson = mapper.createObjectNode();
    resultJson.set("completion", mapper.valueToTree(verdict));
    resultJson.putObject("progress")
        .put("completedRequired", done).put("totalRequired", total);

    results.save(LessonResult.of(a.getId(), score, resultJson.toString()));
    return toResponse(a, verdict, score);
}
```

### Response shape

Extend `LessonCompletion` semantics — keep the record but return a wrapper:

```java
public record CompleteAttemptResponse(
        UUID attemptId,
        String status,            // "COMPLETED"
        Instant completedAt,
        double score,             // 0..100 percent of required done
        LessonCompletion completion) {}
```

Breaking-change note: response shape changes from `LessonCompletion` flat to a
wrapper containing `completion`. Acceptable per brief ("server re-evaluates,
refuses incomplete with structured error, atomic status flip") — old shape had
no persistence semantics. Mobile client update noted for `docs-manager`.

Alternative considered (keep flat shape + add fields on `LessonCompletion`):
rejected — `detail` is a `JsonNode` free-form already, adding top-level fields
to a shared contract muddies it.

### Errors

- `404 ATTEMPT_NOT_FOUND` — no such attempt
- `403 ATTEMPT_NOT_OWNER` — not owner
- `409 ATTEMPT_NOT_COMPLETE` — `verdict.complete()=false`; `details` echoes the
  `LessonCompletion.detail` object + `reason` (lets client show "still missing
  stages X, Y")
- `409 ATTEMPT_NOT_IN_PROGRESS` — attempt `ABANDONED` (defensive)
- Replay on already-COMPLETED: `200` + stored `CompleteAttemptResponse` (NOT
  `409 ATTEMPT_ALREADY_COMPLETED` — idempotent-by-state, brief requirement)
- Concurrent completes: serialized by `findForUpdate`; second sees COMPLETED →
  replay branch. `lesson_results.learner_attempt_id UNIQUE` is the backstop.
- `ATTEMPT_ALREADY_COMPLETED` code retained for **submit-on-completed**
  (Phase on submit already throws `ATTEMPT_NOT_IN_PROGRESS`; brief wants
  dedicated code — switch: `submit()` now throws `AttemptAlreadyCompletedException`
  when `status == COMPLETED`, `AttemptNotInProgressException` when `ABANDONED`).

### Submit-on-completed change

Current `submit()` throws `ATTEMPT_NOT_IN_PROGRESS` for any non-IN_PROGRESS
status. Update:

```java
if (a.getStatus() == LearnerAttemptStatus.COMPLETED)
    throw new AttemptAlreadyCompletedException("attempt already completed");
if (a.getStatus() != LearnerAttemptStatus.IN_PROGRESS)
    throw new AttemptNotInProgressException(...);
```

Both already mapped in `GlobalExceptionHandler` (409).

## New entity + repository

`com.dauviet.learning.domain.LessonResult`:

```java
@Entity @Table(name = "lesson_results")
public class LessonResult {
    @Id UUID id;
    @Column(name="learner_attempt_id", nullable=false, updatable=false, unique=true)
    UUID learnerAttemptId;
    @Column(name="score", nullable=false) BigDecimal score;
    @JdbcTypeCode(SqlTypes.JSON) @Column(name="result_json", columnDefinition="jsonb")
    String resultJson;
    @Column(name="completed_at", nullable=false) Instant completedAt;
    public static LessonResult of(UUID attemptId, double score, String json) {…}
}
```

`LessonResultRepository extends JpaRepository<LessonResult, UUID>`:

```java
Optional<LessonResult> findByLearnerAttemptId(UUID learnerAttemptId);
```

## Transactional boundary

`complete()` is `@Transactional`; pessimistic lock on `learner_attempts` +
`learner_attempts.status` flip + `lesson_results` insert commit together.
`lesson_results.learner_attempt_id UNIQUE` is the last-line guard.

## Reward/EXP

Out of scope per brief — `reward_transactions` table exists but no writes.
`result_json` placeholder leaves room; document in LEARNING_ENGINE_DESIGN §13.

## Files

- Modify `LearnerAttemptService` — extend `complete()`, tweak `submit()` status branching
- Modify `LearnerAttemptController` — endpoint accepts `Idempotency-Key`, returns new DTO
- New `domain/LessonResult.java`, `infrastructure/persistence/LessonResultRepository.java`
- New `api/dto/CompleteAttemptResponse.java`
- New `domain/AttemptNotCompleteException.java` (carries `LessonCompletion.detail`)
- Modify `ErrorCode` (add `ATTEMPT_NOT_COMPLETE`, `RESULT_NOT_FOUND`,
  `IDEMPOTENCY_CONFLICT`)
- Modify `GlobalExceptionHandler` — map `AttemptNotCompleteException` → 409 with details
- Modify `AbstractPostgresIT` — cleanup `lesson_results`, `idempotency_records`

## Tests

- `AttemptCompletionIT.incompleteSubmit_rejected409` — submit only r1, call
  complete → 409 `ATTEMPT_NOT_COMPLETE` with `details.completedRequired=1`.
- `AttemptCompletionIT.complete_flipsStatusAndWritesResult` — finish both
  required → complete → 200; DB has `learner_attempts.status=COMPLETED`,
  `completed_at` set, one `lesson_results` row with `score=100`,
  `result_json.completion.reason="ALL_REQUIRED_STAGES"`.
- `AttemptCompletionIT.complete_replayReturnsStored` — call complete twice →
  both 200, same response, still exactly 1 `lesson_results` row.
- `AttemptCompletionIT.concurrentComplete_exactlyOnce` — 2 threads complete
  simultaneously → both 200 or one 200 + one replayed 200; 1 row in
  `lesson_results`.
- `AttemptCompletionIT.submitAfterComplete_409` — submit post-completion →
  409 `ATTEMPT_ALREADY_COMPLETED`.

## Acceptance criteria

- AC: "POST /attempts/{id}/complete atomically flips status and writes
  lesson_results, exactly once, idempotent on replay."
- AC: "Incomplete attempt completion returns 409 ATTEMPT_NOT_COMPLETE with
  structured detail."
- AC: "Completed attempts reject further submissions with 409
  ATTEMPT_ALREADY_COMPLETED."
