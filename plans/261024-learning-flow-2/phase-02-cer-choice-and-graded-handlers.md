# Phase 02 — CER_CHOICE Handler + Graded Modes (Engine)

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `learning/handler/AbstractActivityHandler.java` (result() strips hidden keys)
- `learning/handler/ScoredHandlers.java` (MultipleChoiceHandler = retry-budget precedent)
- `learning/handler/SelectionHandlers.java` (EvidenceSelectHandler)
- `learning/handler/ReasoningHandlers.java` (ReasoningConnectHandler)
- `learning/handler/ActivityHandlerRegistry.java`

## Overview
- Priority: P0
- Status: pending
- Depends on: phase 01
- Implement the server-side grading for `CER_CHOICE` and the opt-in graded
  branches for `EVIDENCE_SELECT` / `REASONING_CONNECT`. Legacy behavior is
  preserved behind `config.graded != true`.

## Key Insights
- `AbstractActivityHandler.result()` already deep-strips `LEARNER_HIDDEN_KEYS`
  from `output` — handlers can put correctness booleans + counts in output but
  must never echo the accepted key arrays.
- `ScoredHandlers.priorAttempts(ctx)` reads `priorOutputs[activityId]
  .attemptCount` — reuse that exact pattern for CER_CHOICE retry budget.
- `EvidenceSelectHandler` currently: dedup → validate ids against snapshot +
  `visibleEvidenceIds` → `done = size >= minRequired`. Graded mode must keep the
  same id validation, then compare against `acceptedEvidenceIds`.
- `ReasoningConnectHandler` currently validates each relation's `from`/`to` are
  declared `nodes[]` ids and `relation` ∈ `allowedRelations`. Graded mode adds
  comparison to `expectedRelations` (single key) or `acceptedRelationSets`
  (alternative valid graphs — "multiple valid interpretations").
- No `instanceof`/eventId checks — everything reads the pinned snapshot config.

## Requirements

### CerChoiceHandler (new `@Component`, in `learning/handler/CerChoiceHandler.java`)
- `supports()` → `ActivityType.CER_CHOICE`.
- Validate submission: `claimId` ∈ `claims[].id`, `reasoningId` ∈
  `reasoningOptions[].id`, every `evidenceIds[]` ∈ `evidenceOptions[].id` ∪
  snapshot `evidence[]` ids (allow prior-source ids not re-declared). Invalid
  ids → `IllegalArgumentException` (400 path, same as siblings).
- Grade per part:
  - claim correct iff `claimId` ∈ `acceptedClaims`.
  - evidence correct iff submitted set ⊇ `acceptedEvidenceIds` AND
    every submitted id ∈ `evidenceOptions` ∪ prior-source ids (superset-ok so
    extra valid evidence isn't punished; tune via `minEvidence` if added).
  - reasoning correct iff `reasoningId` ∈ `acceptedReasoningIds`.
- `partsCorrect` = count of correct parts (0–3); `correct` =
  `partsCorrect >= minCorrect` (default 3).
- Retry: `maxAttempts` (default 3); `attemptNo = priorAttempts+1`;
  `exhausted = !correct && attemptNo >= maxAttempts`;
  `completed = correct || exhausted` (mirrors MCQ).
- Outcome: `COMPLETED` if correct, `PARTIAL` if `partsCorrect>0` and attempts
  remain, `INCORRECT` otherwise (PARTIAL maps to `onPartial` revise hop in the
  resolver — see phase 04).
- Output: `{claimId, evidenceIds, reasoningId, partsCorrect, correct,
  attemptCount, exhausted?}` — feedbackCode from `feedback[outcome]` or
  `EXHAUSTED`.

### Graded EVIDENCE_SELECT branch (`EvidenceSelectHandler.evaluate`)
- If `config.graded == true` and `acceptedEvidenceIds` non-empty:
  - compute `accepted` set, `selected` set;
  - `correctHits = selected ∩ accepted`, `falseHits = selected − accepted`;
  - `score = correctHits / accepted.size()` (ratio 0..1);
  - `correct = selected.equals(accepted)` (full marks only on exact match);
  - `completed = correct || exhausted` (reuse `maxAttempts`, default 1 →
    flag for BA: maybe default 2 for graded evidence);
  - outcome: `COMPLETED` if correct, `PARTIAL` if `correctHits>0`,
    `INCORRECT` otherwise.
  - output adds `{correct, score, correctCount, falseCount, attemptCount}`
    alongside existing `selectedEvidenceIds`/`selectedCount`.
- Else: unchanged legacy path (count ≥ `minRequired`).

### Graded REASONING_CONNECT branch (`ReasoningConnectHandler.evaluate`)
- Keep existing shape validation (declared node ids + allowed relation names).
- If `config.graded == true`:
  - Build submitted relation set `from|relation|to` triples.
  - `expectedRelations` (canonical key) is an array of `{from,relation,to}`;
    `acceptedRelationSets` is an array of arrays of the same — any exact-match
    set wins (multiple valid interpretations).
  - `correct = submitted.equals(any accepted set)`; partial credit =
    `|submitted ∩ best accepted| / |best accepted|`.
  - Per-connection feedback: emit `matchedRelations` count + `incorrectCount`
    in output (never the expected set); optional per-tuple `relationFeedback`
    map in `feedback` keyed by outcome.
  - `completed = correct || exhausted`; outcome COMPLETED/PARTIAL/INCORRECT.
- Else unchanged.

## Related Code Files
Modify:
- `learning/handler/SelectionHandlers.java`
- `learning/handler/ReasoningHandlers.java`
Create:
- `learning/handler/CerChoiceHandler.java`
Tests:
- `test/.../learning/handler/CerChoiceHandlerTest.java` (new)
- extend `SelectionHandlersTest.java`, `ReasoningHandlersTest.java`

## Implementation Steps
1. Create `CerChoiceHandler` (own file — the container classes are per-family;
   a new file keeps <200 lines and avoids bloating `ReasoningHandlers`).
2. Add `priorAttempts` helper reuse — it's `private static` in
   `ScoredHandlers`; move it to `AbstractActivityHandler` as `protected
   static int priorAttempts(AttemptContext)` so all handlers share it (DRY).
3. `EvidenceSelectHandler`: extract current body into `evaluateLegacy(...)`,
   add `evaluateGraded(...)`; dispatch on `config.path("graded").asBoolean(false)`
   && `acceptedEvidenceIds` non-empty.
4. `ReasoningConnectHandler`: same dispatch pattern; add set-comparison logic.
5. Wire: nothing — `@Component` + `ActivityHandlerRegistry` auto-registers by
   `supports()`.
6. `./mvnw -q compile` then `./mvnw -q test -Dtest='*Handler*'`.

## Todo
- [ ] move priorAttempts to AbstractActivityHandler
- [ ] CerChoiceHandler + tests
- [ ] graded EvidenceSelectHandler branch + tests
- [ ] graded ReasoningConnectHandler branch + tests
- [ ] registry green (no missing-bean startup error)

## Success Criteria
- Unit tests: CER_CHOICE correct→COMPLETED+completed; wrong→PARTIAL/INCORRECT;
  exhausted after maxAttempts; invalid ids → 400-mapped exception; output never
  contains `acceptedClaims`/`acceptedEvidenceIds`/`acceptedReasoningIds`.
- Graded EVIDENCE_SELECT: exact match → COMPLETED+score 1.0; subset → PARTIAL
  +score; legacy (no flag) → identical to current count-only tests (existing
  `SelectionHandlersTest` stays green unchanged).
- Graded REASONING_CONNECT: exact expected match → COMPLETED; alternative
  `acceptedRelationSets` member → COMPLETED; partial → PARTIAL; legacy tests
  green.

## Risk Assessment
- Registry startup failure if a handler is missed → covered by
  `ActivityHandlerRegistryTest` + context smoke test.
- Hidden-key leak via output → `result()` strips; assert in test with a
  spying ObjectMapper round-trip.
- Graded flag misread on legacy snapshots → flag read is
  `path("graded").asBoolean(false)`; missing key = false = legacy.

## Security Considerations
- Answer keys never leave the server: output carries only counts/booleans.
- Client-sent `correct`/`score` fields ignored — server computes from keys.
