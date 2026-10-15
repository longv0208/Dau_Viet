# Phase 02 — Implement All 12 ActivityHandlers

## Context Links

- `docs/LEARNING_ENGINE_DESIGN.md` §6 (handler catalog) — authoritative input/output per type
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/` — per-type draft validators list required config fields
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java` — `LEARNER_HIDDEN_KEYS`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java`
- Phase 01 contracts in `com.dauviet.learning.contract`

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 5h |

Replace the 12 stubs with real handlers. Every handler: validates input shape, applies the published rule using only the pinned snapshot, returns a structured `ActivityResult` whose `output`/`feedback` carries no `LEARNER_HIDDEN_KEYS`. Where BA leaves grading ambiguous, document a deterministic completion rule in the class javadoc AND in the "Evaluation Semantics" section below (these notes get copied into `LEARNING_ENGINE_DESIGN.md` §13 in phase 06).

## Grouping

Handlers live under `com.dauviet.learning.handler`. Keep each class <200 lines; group related handlers in one file only when trivial (<40 lines each) — pattern follows `SimpleActivityValidators`.

| Group | File | ActivityTypes | Outcome space |
|---|---|---|---|
| Acknowledgment | `AcknowledgmentHandlers.java` | `READ`, `VIEW_IMAGE`, `REFLECTION_PROMPT` | `COMPLETED` on valid submit |
| Map / discovery | `ExploreMapHandler.java` | `EXPLORE_MAP` | `COMPLETED` once `minMarkers` reached, else `IN_PROGRESS` |
| Selection | `SelectionHandlers.java` | `EVIDENCE_SELECT`, `HYPOTHESIS_CHOICE` | `COMPLETED` if selection passes constraints |
| Scored | `ScoredHandlers.java` | `MULTIPLE_CHOICE`, `MATCHING`, `DRAG_ORDER` | `COMPLETED` or `INCORRECT` with `attemptsAllowed` handling |
| Reasoning / verify | `ReasoningHandlers.java` | `REASONING_CONNECT`, `VERIFICATION`, `CER` | `COMPLETED` / `SUPPORTED` / `PARTIAL` / `CONTRADICTED` |

## Per-Handler Evaluation Semantics (authoritative for MVP)

> These are the documented-completion semantics where BA is ambiguous. Each rule is also documented in code javadoc. Adjustments here require updating `LEARNING_ENGINE_DESIGN.md` §13 in phase 06.

| Type | Input (from `answer` JsonNode) | Evaluation rule | Output to learner |
|---|---|---|---|
| `READ` | `{}` or `{acknowledged:true}` | Any well-formed submit completes. No correctness. | `{outcome:"COMPLETED"}` |
| `VIEW_IMAGE` | `{}` or `{acknowledged:true}` | Same as READ; `config.imageAssetId` must exist in `snapshot.assets` (else `SNAPSHOT_INVALID_FOR_ACTIVITY`). | `{outcome:"COMPLETED"}` |
| `REFLECTION_PROMPT` | `{text}` (string, ≤4000 chars) or `{optionId}` | Non-empty text OR a valid `config.options[].id` → `COMPLETED`. Empty text → `VALIDATION_ERROR`. | `{outcome:"COMPLETED"}` |
| `EXPLORE_MAP` | `{markerId}` | `markerId` ∈ `config.markers[].id`. Completion when `discoveredMarkerIds` (tracked in `AttemptState`) covers `config.minMarkers` (default = all markers). | `{outcome:"IN_PROGRESS"|"COMPLETED", discovered:[...]}` |
| `EVIDENCE_SELECT` | `{selectedEvidenceIds:[uuid,...]}` | Each id ∈ snapshot `evidence[]` AND ∈ `config.visibleEvidenceIds` (if present). Require `|selected| >= config.minRequired` (default 1). Server does **not** check against `config.requiredEvidenceIds` (that's the answer key — used only by VERIFICATION to grade). | `{outcome:"COMPLETED", selectedCount:N}` |
| `MULTIPLE_CHOICE` | `{selectedOptionIds:[id,...]}` | All ids ∈ `config.options[].id`. `correctOptionIds` (or `multiCorrect`) comparison: exact set equality → `COMPLETED` + `correct:true`; else `INCORRECT`. `attemptsAllowed` from `config.maxAttempts` (default 1) — when exceeded, return `INCORRECT` + `exhausted:true`. | `{outcome, correct:bool, selectedCount}` — never echo `correctOptionIds` |
| `MATCHING` | `{pairs:[{leftId,rightId},...]}` | All ids ∈ declared `config.pairs[].left/right[].id`. Correct when submitted pair set equals `config.correctPairs`. | `{outcome, correct:bool, matchedCount}` — never echo `correctPairs` |
| `DRAG_ORDER` | `{orderedIds:[id,...]}` | Set equality with `config.items[].id`; order equality with `config.expectedOrder` (or `config.correctOrder`) → `COMPLETED`+`correct:true`; else `INCORRECT`. `config.acceptedSequences` (optional array of arrays) extends the accepted set. | `{outcome, correct:bool}` — never echo `expectedOrder` |
| `REASONING_CONNECT` | `{relations:[{from,to,relation},...]}` | Each `from`/`to` ∈ `config.nodes[].id`; `relation` ∈ `config.allowedRelations`. No expected-edge set — MVP records only. | `{outcome:"COMPLETED", relationCount:N}` |
| `HYPOTHESIS_CHOICE` | `{hypothesisId, evidenceIds:[uuid,...]}` | `hypothesisId` ∈ `config.hypotheses[].id`; each `evidenceIds[]` ∈ snapshot `evidence[]`. Records hypothesis + supporting evidence into `AttemptState.outputs` for use by `VERIFICATION`. | `{outcome:"COMPLETED"}` |
| `VERIFICATION` | `{acknowledged:true}` OR `{revise:true}` | Computes support level from `AttemptState.outputs` (most recent `HYPOTHESIS_CHOICE` output) vs `config.requiredEvidenceIds` (server-only). `SUPPORTED` = hypothesis chosen + every required evidence id present in hypothesis evidence list; `PARTIAL` = hypothesis chosen but required evidence incomplete; `CONTRADICTED` = no hypothesis on record OR `config.expectedHypothesis` authored AND chosen hypothesis != expected. Outcome drives `NextStage` (`onPartial`/`onContradicted` stage ids from activity top-level fields). | `{outcome:"SUPPORTED"\|"PARTIAL"\|"CONTRADICTED", feedbackCode}` |
| `CER` | `{claim:string, evidenceIds:[uuid], reasoning:string}` | Non-empty `claim` + `reasoning` (each ≥20 chars); `evidenceIds` ⊆ snapshot `evidence[]` (warning only, not hard-fail — BA allows opinion); completes. Records `conclusion` output for `lesson_results` phase. | `{outcome:"COMPLETED"}` |

## Shared Helpers (`AbstractActivityHandler`)

- `requireArrayField(answer, field)` — throws `IllegalArgumentException` → `VALIDATION_ERROR`.
- `readIdList(answer, field)` — returns `List<String>` of uuids.
- `configOf(activity)` — `ObjectNode` or null; throws `SNAPSHOT_INVALID_FOR_ACTIVITY` when required fields absent.
- `evidenceIds(snapshot)` — `Set<String>` of valid evidence ids.
- `feedbackFor(activity, outcomeKey)` — `String` looked up under `activity.feedback[outcomeKey]`; safe to emit (authored feedback text).
- `toLearnerResult(outcome, completed, outputNode, feedbackCode)` — strips `LEARNER_HIDDEN_KEYS` from output via `LearnerProjectionService` before wrapping.

## Related Code Files

**Create**

- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/AcknowledgmentHandlers.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ExploreMapHandler.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/SelectionHandlers.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ScoredHandlers.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ReasoningHandlers.java`

**Modify**

- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/AbstractActivityHandler.java` — add shared helpers listed above
- Phase 01 stub files — replace with real implementations

## Implementation Steps

1. Flesh out `AbstractActivityHandler` with helper methods.
2. Implement `AcknowledgmentHandlers` — simplest, proves the pattern end-to-end.
3. Implement `ScoredHandlers` (MCQ, MATCHING, DRAG_ORDER) — these exercise the hidden-key access path; verify output excludes answer keys via unit test.
4. Implement `SelectionHandlers` (EVIDENCE_SELECT, HYPOTHESIS_CHOICE) — HYPOTHESIS records `priorOutputs` for VERIFICATION.
5. Implement `ExploreMapHandler` — uses `AttemptState` mutation (`discoveredMarkerIds`); coordinate with `AttemptState` schema.
6. Implement `ReasoningHandlers` — VERIFICATION is the most complex; reads prior outputs + transitions via `outcome` + `onPartial/onContradicted` activity fields.

## Todo List

- [ ] `AbstractActivityHandler` helpers
- [ ] `AcknowledgmentHandlers` (READ, VIEW_IMAGE, REFLECTION_PROMPT)
- [ ] `ExploreMapHandler` (with `AttemptState` accumulation)
- [ ] `SelectionHandlers` (EVIDENCE_SELECT, HYPOTHESIS_CHOICE)
- [ ] `ScoredHandlers` (MULTIPLE_CHOICE, MATCHING, DRAG_ORDER)
- [ ] `ReasoningHandlers` (REASONING_CONNECT, VERIFICATION, CER)
- [ ] Per-handler unit tests: valid submit → expected outcome; invalid payload → `VALIDATION_ERROR`; output never contains any `LEARNER_HIDDEN_KEYS` leaf
- [ ] `EXPLORE_MAP` unit test: two submits accumulate discovered ids
- [ ] `VERIFICATION` unit test: SUPPORTED/PARTIAL/CONTRADICTED paths via stubbed `AttemptState.outputs`

## Success Criteria

- All 12 handlers return deterministic `ActivityResult` for valid inputs.
- Unit test `HandlerSafetyTest` iterates all handlers, submits a crafted answer, asserts emitted `output`/`feedback` JSON contains zero `LEARNER_HIDDEN_KEYS` leaf names.
- VERIFICATION produces `SUPPORTED` only when hypothesis chosen AND all `requiredEvidenceIds` are in the recorded hypothesis's `evidenceIds`.

## Risk Assessment

- **VERIFICATION ambiguity** — documented rule above is a judgment call; PO may want different grading. Flag for review.
- **`MULTIPLE_CHOICE` retry policy** — `config.maxAttempts` not previously validated; handler tolerates absence (default 1).
- **State mutation leakage** — `AttemptState.outputs` are server-internal; never returned wholesale — phase 04 must build learner DTOs explicitly.

## Security Considerations

- Hidden-key stripping is a helper, not a serializer-side filter — every handler calls `toLearnerResult` which strips `LEARNER_HIDDEN_KEYS` before constructing `ActivityResult.output`. Add a unit test that submits an answer containing the literal string `"correctOptionIds"` in a free-text field and asserts the input is preserved (sanitization must be by leaf-name match, not substring).

## Next Steps

- Phase 03: transition + completion resolvers consume `AttemptState` + `StageProgress`.
