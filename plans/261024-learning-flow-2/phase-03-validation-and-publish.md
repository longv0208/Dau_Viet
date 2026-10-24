# Phase 03 — Draft Validation & Publish Readiness

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `lesson/draft/DraftValidator.java` (registry + publish guardrails)
- `lesson/draft/validators/SimpleActivityValidators.java`
- `lesson/draft/validators/AbstractActivityValidator.java` (helpers)
- `lesson/application/PublishReadinessEvaluator.java`

## Overview
- Priority: P0
- Status: pending
- Depends on: phase 01
- Add the `CER_CHOICE` config validator and extend `EVIDENCE_SELECT` /
  `REASONING_CONNECT` validators so the answer keys are required **only at
  PUBLISH level and only when `graded:true`**. Save-level stays tolerant.

## Key Insights
- `ActivityConfigValidator` beans auto-register into `DraftValidator`'s
  `EnumMap` — a missing `supports()` or duplicate bean fails startup.
- `ValidationContext.isPublish()` gates evidence/asset existence checks —
  graded answer keys containing evidence ids must be checked with
  `checkEvidenceRefs` at PUBLISH.
- Evidence-id key fields used by graded modes must also be added to
  `SnapshotBuilder.EVIDENCE_REF_FIELDS` so referenced evidence is embedded in
  the snapshot (`acceptedEvidenceIds`, `visibleEvidenceIds` already covered).
- Publish guardrail `validatePublishGuardrails` requires ≥1 required non-READ
  activity — CER_CHOICE satisfies this automatically.

## Requirements

### New `CerChoiceValidator` (`validators/CerChoiceValidator.java`)
SAVE level:
- `config.claims` non-empty array ≥2, unique `id`s (`collectIds`).
- `config.reasoningOptions` non-empty array ≥2, unique `id`s.
- `config.evidenceOptions` optional array, unique `id`s.
- `config.minCorrect` optional int in [1..3].
- `config.maxAttempts` optional int ≥1.
- `config.priorEvidenceSource` optional string matching `ID_PATTERN`.
PUBLISH level (all above plus):
- `acceptedClaims` ⊆ claims ids; non-empty.
- `acceptedReasoningIds` ⊆ reasoningOptions ids; non-empty.
- `acceptedEvidenceIds` ⊆ evidenceOptions ids ∪ stage `evidenceRefs` ∪
  `priorEvidenceSource`'s activity visibleEvidenceIds — simplest correct rule:
  each id must be a usable evidence for the event (`checkEvidenceRefs`) AND
  declared in `evidenceOptions` ∪ the `visibleEvidenceIds` of the activity
  named by `priorEvidenceSource` (cross-activity check — implement inside
  `DraftValidator.validateActivities` post-pass where all activities are
  already collected, OR keep it simple: require ids to be usable evidence for
  the event and document that they must be selectable somewhere).
- `feedback` should define at least `COMPLETED` and `INCORRECT` (warn-level:
  add as FieldError code `MISSING_FEEDBACK` only at PUBLISH? — decide: make it
  an error to keep feedback coverage uniform).

### Extend `EvidenceSelectValidator`
- When `config.graded == true` (PUBLISH): require `acceptedEvidenceIds`
  non-empty, each id ∈ `visibleEvidenceIds` (subset check via
  `requireSubset`), and `checkEvidenceRefs` both arrays.
- `minRequired` still allowed but interpreted as legacy only; if graded,
  ignore/warn.

### Extend `ReasoningConnectValidator`
- When `config.graded == true` (PUBLISH): require `expectedRelations` non-empty
  OR `acceptedRelationSets` non-empty; each relation `{from,relation,to}` must
  reference declared `nodes` ids and `allowedRelations` names; at least one
  accepted set must be non-empty.

### `SnapshotBuilder.EVIDENCE_REF_FIELDS`
- Add `"acceptedEvidenceIds"` (and `"evidenceOptions"` is `{id}` objects —
  extend `addIds`/`collectEvidenceIds` to also read `config.evidenceOptions[].id`
  OR simply require authors to also list them in `visibleEvidenceIds`-style
  `evidenceRefs` — DECISION: add a small loop reading `evidenceOptions[].id`
  in `collectEvidenceIds`, cleanest).

### `DraftValidator`
- No structural change needed beyond the new validator bean; confirm
  `priorEvidenceSource` cross-reference check placement (post-activity pass).

## Related Code Files
Modify:
- `lesson/draft/validators/SimpleActivityValidators.java`
- `lesson/draft/SnapshotBuilder.java`
- possibly `lesson/draft/DraftValidator.java` (cross-activity check)
Create:
- `lesson/draft/validators/CerChoiceValidator.java`
Tests:
- `test/.../lesson/draft/DraftValidatorTest.java` (extend)
- new `CerChoiceValidatorTest.java`

## Implementation Steps
1. Create `CerChoiceValidator` mirroring `CerValidator` style (requireField /
   requireNonEmptyArray / collectIds / requireSubset / checkEvidenceRefs).
2. Extend the two existing validators with graded-mode publish rules.
3. `SnapshotBuilder`: add `acceptedEvidenceIds` to `EVIDENCE_REF_FIELDS`; add
   `evidenceOptions[].id` collection.
4. Tests: SAVE-tolerant vs PUBLISH-strict for each new rule; legacy drafts
   without `graded` unaffected (existing tests stay green).
5. `./mvnw -q compile && ./mvnw -q test -Dtest='*Validator*,DraftValidatorTest,SnapshotBuilderTest'`.

## Todo
- [ ] CerChoiceValidator
- [ ] graded branches in EvidenceSelectValidator + ReasoningConnectValidator
- [ ] SnapshotBuilder ref-field additions
- [ ] cross-activity priorEvidenceSource check (if kept)
- [ ] tests green

## Success Criteria
- Publishing a CER_CHOICE draft with missing `acceptedClaims` → 422
  `MISSING_FIELD` at `…config.acceptedClaims`.
- Publishing graded EVIDENCE_SELECT without `acceptedEvidenceIds` → 422.
- Legacy draft (no `graded`) publishes unchanged (existing tests green).
- Publish-readiness endpoint surfaces the new errors in `errors[]`.

## Risk Assessment
- Cross-activity `priorEvidenceSource` check complexity — if it adds >30 lines,
  drop to a warning and rely on runtime fallback (CER_CHOICE still works when
  the named activity is absent: prior evidence just doesn't pre-fill).
- Save-level noise: keep SAVE checks minimal so authors can save mid-draft.

## Security Considerations
- Validators never echo key contents into error messages — paths + ids only
  (already the file's convention).
