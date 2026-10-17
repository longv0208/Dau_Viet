# Phase 01 — Backend projection & handlers

## Context Links

- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LearnerProjectionService.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/MultipleChoiceValidator.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/handler/ScoredHandlers.java`
- `dau-viet-backend/src/test/java/com/dauviet/lesson/application/LearnerProjectionServiceTest.java`
- `dau-viet-backend/src/test/java/com/dauviet/learning/handler/ScoredHandlersTest.java`

## Overview

- Priority: P1
- Status: pending
- Fix MC canonical contract, strip `multiCorrect` from learner payload, transform MATCHING projection into `leftItems`/`rightItems`, and reorder DRAG_ORDER `items` deterministically.

## Key Insights

- `LEARNER_HIDDEN_KEYS` already strips `correctPairs`, `correctOrder`, `expectedOrder` — adding `multiCorrect` is a one-line schema fix.
- `LearnerProjectionService.project()` iterates activities inside `stages[]`. A per-type transform hook must run BEFORE `stripContainer` so new keys (`leftItems`/`rightItems`) are not removed.
- `projectActivity()` (used by `LearnerAttemptService`) must apply the same transform — currently drops `validation`/`evidenceRefs` but leaves `config` untouched except hidden-key stripping.
- MATCHING transform must keep `config.pairs` + `correctPairs` intact in the snapshot (server still grades against them); only the projected learner copy drops `pairs` and emits `leftItems`/`rightItems`.
- DRAG_ORDER reorder must be deterministic, stable across calls, and differ from `expectedOrder` whenever `items.size() >= 2`. Pure function of activity id + item ids (e.g., sort by `hash(activityId + itemId)`). If the resulting order still equals expected, reverse once.

## Requirements

- MC: editor canonical shape = `correctOptionIds` (both modes) + `multiSelect` boolean. Handler must grade both `correctOptionIds` (preferred) and legacy `multiCorrect` (fallback) identically.
- `multiCorrect` added to `LEARNER_HIDDEN_KEYS`.
- `MultipleChoiceValidator` keeps XOR rule; unchanged.
- MATCHING projection: `config.pairs` removed from learner payload; emit `config.leftItems[]` and `config.rightItems[]` — each `{id,label}` — with deterministic, independent ordering (different sort keys) so left-row index never implies right-row index.
- DRAG_ORDER projection: `config.items` reordered deterministically; `expectedOrder`/`acceptedSequences` remain stripped; projected order must never equal `expectedOrder` for `len>=2`.
- All transforms pure (no RNG, no DB).

## Architecture

```
Snapshot/draft ──► LearnerProjectionService.project()
                       │
                       ├─ deepCopy (no mutation of input)
                       ├─ per-activity:
                       │    if type==MATCHING  → transformMatching(config)
                       │    if type==DRAG_ORDER → transformDragOrder(activityId, config)
                       │    remove validation/evidenceRefs
                       │    stripContainer(config/feedback/validation)
                       └─ top-level strip
```

`projectActivity` reuses the same per-activity transform pipeline.

## Related Code Files

Modify:
- `LearnerProjectionService.java` — add per-type transform; apply in `project()` and `projectActivity()`.
- `DraftSchema.java` — add `"multiCorrect"` to `LEARNER_HIDDEN_KEYS`.
- `ScoredHandlers.java` — `MultipleChoiceHandler` fallback to `multiCorrect` when `correctOptionIds` absent.
- `LearnerProjectionServiceTest.java` — add MATCHING/DRAG_ORDER leak-proof tests.
- `ScoredHandlersTest.java` — add `multiCorrect` grading cases.

Create: none. Delete: none.

## Implementation Steps

1. `DraftSchema.java`: add `"multiCorrect"` to `LEARNER_HIDDEN_KEYS` set.
2. `LearnerProjectionService.java`:
   - Add private method `transformActivity(ObjectNode act)` that reads `act.type` and calls `transformMatchingConfig` / `transformDragOrderConfig` as needed.
   - `transformMatchingConfig(ObjectNode config)`: if `config.has("pairs")`, build `leftItems`/`rightItems` arrays (each `{id,label}`), sort each by a stable key derived from `activity.id` + item `id` (e.g., `Objects.hash(activityId, id)` or `String.compareTo` on `activityId + ":" + id`), then `config.remove("pairs")` and `config.set("leftItems", …)` / `config.set("rightItems", …)`.
   - `transformDragOrderConfig(String activityId, ObjectNode config)`: read `items` array; reorder by stable sort key `Objects.hash(activityId, itemId)`; if resulting `id` list equals `expectedOrder` (when present) and `size>=2`, reverse the list; `config.set("items", reordered)`.
   - Call `transformActivity` inside `project()` activity loop BEFORE `stripContainer(a)` and inside `projectActivity()` before `stripContainer(copy)`.
   - Keep transforms deterministic: use `String.CASE_INSENSITIVE_ORDER` on `activityId + "|" + id` or `Integer.compare(Objects.hash(...))`; document that hash collisions fall back to `id` compare.
3. `ScoredHandlers.java` `MultipleChoiceHandler.evaluate`:
   - After `Set<String> correct = stringIds(config.get("correctOptionIds"));` add fallback: if empty, `correct = stringIds(config.get("multiCorrect"));`.
   - Everything else unchanged (subset validation still uses `options`).
4. Unit tests — `LearnerProjectionServiceTest`:
   - `matching_stripsPairsAndEmitsIndependentColumns`: draft with 3 pairs → assert `config.pairs` absent, `leftItems`/`rightItems` present (3 each, ids match authored), and the projected left/right sequences are not reconstructible (assert `leftItems[i].id` does not trivially pair to `rightItems[i].id` by index).
   - `matching_inputSnapshotUnchanged`: verify input JsonNode still has `pairs`/`correctPairs` after `project()` returns.
   - `dragOrder_reordersItemsDeterministically`: 3 items + `expectedOrder` → assert projected `items` order is stable across two calls and `!= expectedOrder`.
   - `dragOrder_fallsBackToReverseWhenHashMatchesExpected`: edge case — if hash-sort equals expectedOrder, assert reversed order emitted (test with controlled ids or mock-free approach: pick ids where natural order equals expected, verify reversal logic kicks in; simpler: verify code path exists by testing that order is never equal for len>=2 across several random-ish ids).
   - `mc_multiCorrectStrippedFromConfig`: config with `multiCorrect` → absent in projection.
5. Unit tests — `ScoredHandlersTest`:
   - `mcq_multiCorrectLegacy_gradesCorrectly`: config with `multiCorrect` only, submission matching → COMPLETED.
   - `mcq_multiCorrectLegacy_wrongSet_incorrect`: submission subset → INCORRECT.
   - `matching`/`dragOrder` tests unchanged (snapshot still has answer keys).

## Todo List

- [ ] `DraftSchema` adds `multiCorrect` hidden key
- [ ] `LearnerProjectionService` MATCHING transform
- [ ] `LearnerProjectionService` DRAG_ORDER deterministic reorder
- [ ] `ScoredHandlers` MC `multiCorrect` fallback
- [ ] Unit tests green: `LearnerProjectionServiceTest`, `ScoredHandlersTest`

## Success Criteria

- `./mvnw test -Dtest=LearnerProjectionServiceTest,ScoredHandlersTest` passes.
- Projection output for MATCHING contains no `pairs`/`correctPairs` and no index-correlated left↔right mapping.
- DRAG_ORDER projected `items` order is deterministic and never equals `expectedOrder` for len>=2.
- MC handler grades both `correctOptionIds` and `multiCorrect`.

## Risk Assessment

- Hash-based ordering could theoretically collide; mitigate by stable secondary sort on `id`.
- Reorder must remain stable across JVM restarts — `Objects.hash` is deterministic for Strings, fine.
- Existing published snapshots with `multiCorrect` continue to grade correctly via fallback.

## Security Considerations

- Learner payload must never contain answer keys; new transforms must not introduce new leak channels (verify `leftItems`/`rightItems` do not expose pairing metadata).
- `multiCorrect` stripped at projection — not merely renamed.

## Next Steps

- Phase 02 uses updated projection on enriched preview document.
- Phase 03 renderers consume `leftItems`/`rightItems` and reordered `items`.
