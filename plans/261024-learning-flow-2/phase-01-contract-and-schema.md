# Phase 01 — Contract & Schema Foundation

## Context Links
- plan: `plans/261024-learning-flow-2/plan.md`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/ActivityType.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java`
- `dau-viet-admin/src/features/lessons/builder/draft-model.ts`
- `docs/LEARNING_ENGINE_DESIGN.md`

## Overview
- Priority: P0 (blocks every other phase — freezes the JSON contract)
- Status: pending
- Add `CER_CHOICE` to the type enum, allow it in `CONCLUSION` stage, and register
  the new server-only answer-key leaf names in `LEARNER_HIDDEN_KEYS`. Mirror the
  type in the admin `draft-model.ts`. No behavior change yet — handlers and
  validators land in phases 02–03.

## Key Insights
- `ActivityType` is a plain enum; adding a constant is additive and safe.
- `ActivityHandlerRegistry` fails startup if a type lacks a handler bean and
  `DraftValidator` rejects a missing validator only at usage — so `CER_CHOICE`
  MUST ship its handler + validator in the same PR (phases 02/03), not alone.
- `STAGE_ALLOWED_ACTIVITIES[CONCLUSION]` is currently `{CER, READ}` — keep
  `CER` (legacy snapshots depend on it) and ADD `CER_CHOICE`.
- `LEARNER_HIDDEN_KEYS` strips by leaf name recursively inside
  `config`/`validation`/`feedback`. New keys must use leaf names not already
  meaning something visible to learners (e.g. avoid reusing `evidenceIds`,
  which is a *submission* field, as a config key — use `acceptedEvidenceIds`).

## Requirements
- `ActivityType.CER_CHOICE` exists.
- `DraftSchema.STAGE_ALLOWED_ACTIVITIES[CONCLUSION]` = {CER, CER_CHOICE, READ}.
- `DraftSchema.LEARNER_HIDDEN_KEYS` gains exactly these leaf names:
  `acceptedClaims`, `acceptedEvidenceIds`, `acceptedReasoningIds`,
  `expectedRelations`, `acceptedRelationSets`, `acceptedOptions`.
- Admin `ACTIVITY_TYPES` += `"CER_CHOICE"`;
  `STAGE_ALLOWED_ACTIVITIES.CONCLUSION` = `["CER", "CER_CHOICE", "READ"]`.

## CER_CHOICE contract (decided — minimal rubric per YAGNI)

Config (server-side; hidden keys marked `*`):
```json
{
  "type": "CER_CHOICE",
  "required": true,
  "instruction": "Chọn kết luận có dẫn chứng đúng nhất.",
  "config": {
    "graded": true,
    "maxAttempts": 3,
    "claims": [ {"id":"claim-ambush","text":"Ngô Quyền phục kích thủy triều"}, ... ],
    "evidenceOptions": [ {"id":"<evidence-uuid>"}, ... ],
    "reasoningOptions": [ {"id":"rs-tide","text":"Thủy triều che giấu cọc"}, ... ],
    "priorEvidenceSource": "evidence-stage-activity-id",
    "acceptedClaims": ["claim-ambush"],
    "acceptedEvidenceIds": ["<evidence-uuid>"],
    "acceptedReasoningIds": ["rs-tide"],
    "minCorrect": 3
  },
  "feedback": { "COMPLETED": "...", "PARTIAL": "...", "INCORRECT": "..." }
}
```
- `claims`/`reasoningOptions` are `{id,text}` lists (like `hypotheses`).
- `evidenceOptions` reuse snapshot `evidence[]` (same as `visibleEvidenceIds`) —
  carry `{id}` only; labels resolve from the snapshot embed.
- `priorEvidenceSource` = activityId of an upstream EVIDENCE_SELECT whose
  `selectedEvidenceIds` output should be offered as pre-picked evidence
  (continuity; phase 04 details the lookup).
- Answer keys `acceptedClaims`/`acceptedEvidenceIds`/`acceptedReasoningIds`
  are stripped from the learner payload by `LEARNER_HIDDEN_KEYS`.
- `minCorrect` = number of the three parts (claim/evidence/reasoning) that must
  be correct for `completed:true`; default 3 = all. PARTIAL = some but < all.

Submission:
```json
{ "claimId": "claim-ambush",
  "evidenceIds": ["<evidence-uuid>"],
  "reasoningId": "rs-tide" }
```
Output (persisted, learner-safe): `{claimId, evidenceIds, reasoningId,
partsCorrect, correct, attemptCount}` — never the accepted keys.

## Architecture / Data flow
- Draft JSON → `DraftValidator` (SAVE/PUBLISH) → `SnapshotBuilder` verbatim
  copy into `snapshot_json.stages` → `LearnerProjectionService` strips hidden
  keys for learners → `CerChoiceHandler` grades at submit time.

## Related Code Files
Modify:
- `dau-viet-backend/.../lesson/draft/ActivityType.java`
- `dau-viet-backend/.../lesson/draft/DraftSchema.java`
- `dau-viet-admin/src/features/lessons/builder/draft-model.ts`
- `dau-viet-admin/src/features/lessons/builder/labels.ts` (add ACTIVITY_LABELS entry)

## Implementation Steps
1. `ActivityType.java`: add `CER_CHOICE` constant (before `REFLECTION_PROMPT`
   or at end — enum order is not load-bearing).
2. `DraftSchema.java`: add `CER_CHOICE` into the `CONCLUSION` set inside
   `STAGE_ALLOWED_ACTIVITIES`; extend `LEARNER_HIDDEN_KEYS` with the six new
   leaf names.
3. `draft-model.ts`: append `"CER_CHOICE"` to `ACTIVITY_TYPES`; update
   `STAGE_ALLOWED_ACTIVITIES.CONCLUSION`.
4. `labels.ts`: add `CER_CHOICE` label/icon (e.g. `ListChecks` —
   "Kết luận có dẫn chứng (chọn)").
5. Compile: `cd dau-viet-backend && set JAVA_HOME=E:\Java\jdk-21 && ./mvnw -q compile`.

## Todo
- [ ] ActivityType.CER_CHOICE
- [ ] DraftSchema allowlist + hidden keys
- [ ] draft-model.ts union + allowlist
- [ ] labels.ts entry
- [ ] backend compiles

## Success Criteria
- `ActivityType.CER_CHOICE` resolves; CONCLUSION accepts both CER and CER_CHOICE.
- `LEARNER_HIDDEN_KEYS` contains the six new names.
- Admin `draft-model.ts` type-checks (`npm run build` or `tsc --noEmit`).

## Risk Assessment
- Missing handler/validator for CER_CHOICE → startup failure
  (`missing ActivityHandler`). Mitigation: land phases 02+03 before any deploy;
  registry test already asserts coverage.
- Hidden-key name collision with a learner-visible field — mitigated by using
  `accepted*`/`expected*` prefixes, never bare submission field names.

## Security Considerations
- New answer keys are server-only from the moment they are declared; verified
  by a projection test in phase 03/07.
