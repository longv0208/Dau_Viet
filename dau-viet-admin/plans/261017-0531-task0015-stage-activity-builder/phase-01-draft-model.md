# Phase 01 — Draft model + codec + zod schemas

## Context links

- Contract report: `plans/reports/planner-261017-0531-task0015-draft-contract.md` §2, §3, §4
- Backend source: `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java`, `DraftValidator.java`, `validators/`
- Admin patterns: `dau-viet-admin/src/features/lessons/lesson-basic-form.tsx`, `src/lib/dto/lesson.ts`

## Overview

- Priority: P1 (foundation — everything else depends on it)
- Status: pending
- Effort: 3h
- Goal: typed `Draft`/`Stage`/`Activity` models in `src/features/lessons/builder/`; parse `draftJson` ↔ TS → serialize back preserving unknown fields; slug-style id generator; zod schemas per activity type matching backend validators.

## Key insights

- `draftJson` round-trips as a **string** inside `AdminLessonResponse` — `JSON.parse` on the way in, `JSON.stringify` on the way out.
- Backend rejects unknown top-level/stage/activity keys at SAVE. The builder must allow everything `DraftSchema` allows (`stages`, `completion`, `objectives`, `schemaVersion`, `validation`, `feedback`, `evidenceRefs`, `requiredEvidenceIds`) — but never silently drop them on edit.
- IDs are slugs not UUIDs: `[a-z0-9][a-z0-9-]{1,63}`.
- `config` shape varies by `ActivityType`; the typed editors own `config` shape per type. `validation`/`feedback` are loose JSON blocks — preserve via spread.

## Requirements

- `Draft` type: `{schemaVersion?: 1, stages: Stage[], completion?: Completion, objectives?: unknown[], [k:string]: unknown}` — spread-through rest-bag for unknown keys.
- `Stage` type: `{id, type: StageType, title?, required?, activities: Activity[], nextStageIds?, requiredEvidenceIds?, [k:string]: unknown}`.
- `Activity` type: `{id, type: ActivityType, required?, instruction?, config?, validation?, feedback?, evidenceRefs?, [k:string]: unknown}`.
- `parseDraft(json: string): Draft` — tolerant: `{}`/empty → `{stages:[]}`; malformed → throws typed error.
- `serializeDraft(d: Draft): string` — writes back all known + unknown keys; deterministic order not required.
- `genId(prefix: "stage"|"act", existing: string[]): string` — slug-style, `<prefix>-<rand6>`, collision-checked.
- Per-activity `config` zod schemas matching Java validators §4 of the contract report (SAVE level — strict on shape, lenient on existence).

## Architecture

```
draftJson: string ──parse──> Draft (TS) ──zod validate──> React state (RHF)
React state ──assemble──> Draft ──serialize──> string ──PUT──> backend
```

Round-trip rule: any key we don't recognize is kept verbatim on the typed object via `...rest` spread, then re-spread on serialize.

## Related code files

**Create:**
- `src/features/lessons/builder/draft-model.ts` — types + parse/serialize (~150 LOC)
- `src/features/lessons/builder/draft-schemas.ts` — zod schemas per type (~180 LOC)
- `src/features/lessons/builder/draft-id.ts` — `genId` (~30 LOC)
- `src/features/lessons/builder/draft-model.test.ts` — round-trip, unknown keys, ID pattern (~120 LOC)

**Modify:** none in this phase.

## Implementation steps

1. `draft-id.ts`:
   - `genSlugId(prefix, existing)` → `${prefix}-${randomBytes(3).hex}` (6 chars); check ID_PATTERN and uniqueness; throw after 5 collisions.
2. `draft-model.ts`:
   - Export `StageType`, `ActivityType` const arrays + union types.
   - Export `STAGE_ALLOWED_ACTIVITIES: Record<StageType, ActivityType[]>` mirroring `DraftSchema.STAGE_ALLOWED_ACTIVITIES` verbatim.
   - `parseDraft`, `serializeDraft`. On parse: `JSON.parse(json || "{}")` → if not object → throw; copy top-level rest into `extra` field.
   - Stage/activity mappers keep `...rest` per object.
3. `draft-schemas.ts`:
   - Zod schemas: `StageSchema`, `ActivitySchema` (discriminated union on `type`), `DraftSchema`.
   - Config schemas per type: `ReadConfig`, `ViewImageConfig`, `MultipleChoiceConfig` (options ≥2 unique ids + exactly one of correctOptionIds|multiCorrect), `EvidenceSelectConfig` (`visibleEvidenceIds` non-empty), `MatchingConfig` (`pairs` ≥2 + correctPairs subset), `DragOrderConfig` (`items` ≥2 + optional `expectedOrder` permutation), `CerConfig` (`rubric.criteria` non-empty + `requiredEvidenceIds` non-empty), `VerificationConfig` (loose), `HypothesisChoiceConfig` (`hypotheses` ≥2), `ExploreMapConfig` (`markers` ≥1), `ReasoningConnectConfig` (`nodes` ≥2 + `allowedRelations` ≥1), `ReflectionPromptConfig` (`prompt` ≤2000).
   - Do NOT enforce publish-only rules (evidence existence, terminal reachability, `NO_REQUIRED_ACTIVITY`); those are informational.
4. `draft-model.test.ts`:
   - Round-trip preserves unknown top-level key (e.g. `objectives`, future `foo`).
   - Unknown stage/activity key (e.g. `stage.notes`) survives.
   - Malformed JSON throws.
   - `genId` produces ID_PATTERN match and is unique.

## Todo list

- [ ] `draft-id.ts` with `genSlugId` + tests
- [ ] `draft-model.ts` with `parseDraft`/`serializeDraft` + spread-through
- [ ] `draft-schemas.ts` zod schemas for all 12 activity types
- [ ] Unit tests for round-trip + edge cases
- [ ] Run `pnpm vitest run draft-model` (or equivalent) → green

## Success criteria

- Round-trip `parse → serialize` produces identical JSON for a fixture draft (modulo key order).
- `STAGE_ALLOWED_ACTIVITIES` exported matches `DraftSchema` 1:1 (asserted in test).
- All zod schemas enforce backend SAVE rules; no publish-only rule enforced.

## Risk assessment

- Zod schema drift from Java validators → keep a comment block referencing `SimpleActivityValidators.java`/`MultipleChoiceValidator.java` lines.
- Spread-through rest-bag may accidentally shadow real fields — name it `extra` and strip on serialize.

## Security considerations

- Never log or render `validation` block / `correctOptionIds` etc. — they're server-only keys (DraftSchema.LEARNER_HIDDEN_KEYS). Editors display them only inside form inputs, never in learner-preview surfaces.

## Next steps

- Phase 02 consumes `Draft`/`Stage`/`Activity` types + `STAGE_ALLOWED_ACTIVITIES` + `genSlugId`.
