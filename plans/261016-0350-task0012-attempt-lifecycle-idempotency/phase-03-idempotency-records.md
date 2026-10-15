# Phase 03 — Persistent Idempotency-Key (`idempotency_records`)

## Context

- `idempotency_records` table already exists (V4): `UNIQUE(user_id, operation,
  idempotency_key)`, `request_hash VARCHAR(128)`, `response_json JSONB`,
  `http_status`, `created_at`, `expires_at`.
- Currently `submit()` accepts `Idempotency-Key` header and only logs it.
- Brief §3: "persistent `Idempotency-Key` handling using existing
  `idempotency_records` table; unique user_id+operation+idempotency_key; request
  fingerprint/hash; same key+same payload → replay stored response; same
  key+different payload → 409 conflict; concurrent same-key cannot double-write;
  committed in same transaction; document retention/expiration; NO in-memory
  cache. Scope key to learner+attempt+operation. Apply to submit AND complete."

## Design

### Entity + repo

`com.dauviet.learning.domain.IdempotencyRecord`:

```java
@Entity @Table(name="idempotency_records")
public class IdempotencyRecord {
    @Id UUID id;
    @Column(name="user_id", nullable=false, updatable=false) UUID userId;
    @Column(name="idempotency_key", nullable=false, updatable=false, length=160)
    String idempotencyKey;
    @Column(name="operation", nullable=false, updatable=false, length=100)
    String operation;
    @Column(name="request_hash", nullable=false, updatable=false, length=128)
    String requestHash;
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name="response_json", columnDefinition="jsonb") String responseJson;
    @Column(name="http_status") Integer httpStatus;
    @Column(name="created_at", nullable=false, updatable=false) Instant createdAt;
    @Column(name="expires_at") Instant expiresAt;
}
```

`IdempotencyRecordRepository`:

```java
Optional<IdempotencyRecord> findByUserIdAndOperationAndIdempotencyKey(
        UUID userId, String operation, String key);
```

(Unique index already prevents duplicates; lookup by full tuple.)

### Operation names

- `"SUBMIT_ACTIVITY"` — for `POST .../activities/{activityId}/submissions`
- `"COMPLETE_ATTEMPT"` — for `POST .../complete`

Scope = `(user_id, operation, idempotency_key)` per UNIQUE. Attempt/activity
context folds into `request_hash` (see below) — key reuse across attempts on
the same operation collides via hash → 409 (correct client behavior: mint a
new key per logical request).

### `IdempotencyService` (new, `com.dauviet.learning.application`)

```java
@Service
public class IdempotencyService {

    /**
     * Execute `action` under idempotency-key semantics inside the CALLER's
     * transaction. Returns either the freshly-computed response (and records
     * it) or the previously-stored one.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public <T> T execute(UUID userId, String operation, String key,
                         String requestHash,
                         Function<Object, T> action,
                         Function<T, String> responseSerializer,
                         Function<String, T> responseDeserializer,
                         int successStatus) {
        if (key == null || key.isBlank()) {
            return action.apply(null);   // no key → just run
        }
        var prior = repo.findByUserIdAndOperationAndIdempotencyKey(
                userId, operation, key);
        if (prior.isPresent()) {
            IdempotencyRecord r = prior.get();
            if (!r.getRequestHash().equals(requestHash)) {
                throw new IdempotencyConflictException(
                        "Idempotency-Key reused with different payload");
            }
            if (r.getResponseJson() == null) {
                // reserved but unfinished → previous tx rolled back
                throw new IdempotencyConflictException(
                        "Concurrent request with same Idempotency-Key");
            }
            return responseDeserializer.apply(r.getResponseJson());
        }
        T response = action.apply(null);
        String json = responseSerializer.apply(response);
        IdempotencyRecord rec = IdempotencyRecord.of(
                userId, operation, key, requestHash, json, successStatus,
                Instant.now(), Instant.now().plus(ttl));
        try {
            repo.saveAndFlush(rec);
        } catch (DataIntegrityViolationException dup) {
            // Concurrent same-key insert won the race — rollback via propagation
            // is wrong; instead re-read winner and treat as replay path.
            throw new IdempotencyConflictException(
                    "Concurrent request with same Idempotency-Key");
        }
        return response;
    }
}
```

Race handling — two concurrent same-key requests: unique index lets one insert
commit; loser's `saveAndFlush` throws `DataIntegrityViolationException`. We
translate to `409 IDEMPOTENCY_CONFLICT` ("concurrent request same key") — the
client retries with the same key after a backoff, then replays the stored
response. Alternative: serialize by `findForUpdate` on the attempt row first
(already done for submit; for complete also `findForUpdate`) — under attempt
lock, both enter sequentially; second sees stored response → replay. So in
practice the catch block is a rare defensive path. Keep it.

### `request_hash`

`SHA-256( operation | attemptId | activityId? | canonicalJson(answer) )`:

- submit: `sha256("SUBMIT_ACTIVITY|" + attemptId + "|" + activityId + "|" +
  canonical(answerJson))`
- complete: `sha256("COMPLETE_ATTEMPT|" + attemptId + "|")` — body is empty
- canonical JSON: sort object keys recursively, strip whitespace —
  `ObjectMapper` with `SORT_PROPERTIES_ALPHABETICALLY` or normalize via
  `JsonNode` `toString()` after `readTree` (Jackson already orders fields
  per-parse; for safety use `mapper.writeValueAsString(mapper.readTree(raw))`).

Hex-encoded → 64 chars, fits `VARCHAR(128)`.

### Stored `response_json`

Serialize the exact DTO the endpoint returns:

- submit → `SubmitActivityResponse` serialized
- complete → `CompleteAttemptResponse` serialized

`http_status` stores 200 (we never persist non-2xx — errors leave the row
uninserted because the exception rolls back the tx; the `chk_idempotency_response`
constraint allows NULL only transiently inside tx if we want a "reserved"
mode — skip, simpler: only write rows for successful actions).

### TTL

- `expires_at = created_at + app.learning.idempotency-ttl` (default `PT24H`).
- Add to `application.yml`: `app.learning.idempotency-ttl: PT24H`. Read via
  `@ConfigurationProperties` or `@Value`.
- No scheduled cleanup in this task — index `idx_idempotency_expiry` exists;
  retention note goes into LEARNING_ENGINE_DESIGN §14 + API_SPEC §4.

### Errors

- `409 IDEMPOTENCY_CONFLICT` — key reuse with different hash, or concurrent
  same-key race lost. `details = {reason:"payload_mismatch"|"concurrent"}`.
- No other new codes.

### Integration into `submit()`

```java
@Transactional
public SubmitActivityResponse submit(UUID userId, UUID attemptId,
                                     String activityId, JsonNode answer,
                                     String idempotencyKey) {
    String hash = hash("SUBMIT_ACTIVITY", attemptId, activityId, answer);
    return idempotency.execute(userId, "SUBMIT_ACTIVITY", idempotencyKey, hash,
        v -> doSubmit(userId, attemptId, activityId, answer),
        this::toJson, this::fromJson, 200);
}
```

`doSubmit` = current `submit()` body minus the idempotency log line.

Same for `complete()` → `doComplete`.

### Transactional composition

`IdempotencyService.execute` joins the caller's tx (`REQUIRED`); the
`activity_attempts` insert, `learner_attempts` update, and `idempotency_records`
insert commit or roll back **atomically**. Brief requirement met.

## Files

- New `domain/IdempotencyRecord.java`
- New `infrastructure/persistence/IdempotencyRecordRepository.java`
- New `application/IdempotencyService.java`
- New `domain/IdempotencyConflictException.java`
- Modify `LearnerAttemptService` — split submit/complete into idempotency wrapper + `do*` body
- Modify `ErrorCode` (add `IDEMPOTENCY_CONFLICT`)
- Modify `GlobalExceptionHandler` — map `IdempotencyConflictException` → 409
- Modify `application.yml` — add `app.learning.idempotency-ttl`

## Tests

- `IdempotencyIT.submit_sameKey_samePayload_replaysStored`: submit with key K,
  body A → 200. Resend K + A → 200, identical body, **no second**
  `activity_attempts` row.
- `IdempotencyIT.submit_sameKey_differentPayload_409`: same K, different answer
  → 409 `IDEMPOTENCY_CONFLICT`, `details.reason="payload_mismatch"`.
- `IdempotencyIT.submit_differentKey_records2Attempts`: K1 then K2 → 2
  `activity_attempts` rows (idempotency only dedupes same key).
- `IdempotencyIT.submit_concurrentSameKey_noDoubleWrite`: 2 threads same K+A →
  one wins 200, other 200 replay or 409; final `activity_attempts` rows for
  (attempt, activity) ≤ 1; `idempotency_records` count = 1.
- `IdempotencyIT.complete_sameKey_replays`: complete with K → 200; retry K →
  200, no second `lesson_results`.
- `IdempotencyIT.expiredRecord_treatedAsNew` — optional, manual: set
  `expires_at` in past via jdbc, send K → behavior documented (decide: still
  replay? treat-as-new? chosen: still replay, expiry is for cleanup not
  semantics — document).

## Acceptance criteria

- AC: "`Idempotency-Key` on submit persists `idempotency_records` row keyed
  `(user_id,'SUBMIT_ACTIVITY',key)` in the same tx; replay returns stored
  response without re-evaluating; different payload → 409 IDEMPOTENCY_CONFLICT."
- AC: "Same for `COMPLETE_ATTEMPT`."
- AC: "Concurrent same-key submit does not double-write; unique index is the
  backstop."
