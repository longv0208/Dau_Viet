# Phase 02 — DraftValidator redesign

## Context links
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/DraftValidator.java` (existing — replace, do not enhance)
- `docs/LEARNING_ENGINE_DESIGN.md` §9 (publish guardrails)
- `phase-01-draft-schema-contract.md` for the canonical shape

## Overview
- Priority: P1
- Status: pending
- Replace today's two-method `requireJsonObject/Array` with a structured validator producing `List<FieldError>`. Two levels: `SAVE` (lenient, partial drafts OK) and `PUBLISH` (strict).

## Requirements
- Error model: `record FieldError(String path, String code, String message)` where `path` uses JSONPath-ish notation `stages[2].activities[1].id`.
- `SAVE` level: well-formed JSON, `schemaVersion == CURRENT` (if present), every stage/activity has valid `id` shape, IDs unique within collection, `type` parses to enum, no unknown top-level fields.
- `PUBLISH` level: all SAVE checks + required fields present, `config` passes type-aware validation, all `evidenceRefs`/`requiredEvidenceIds` resolve to `evidences.id` for the lesson's `event_id`, `nextStageIds` targets exist, no cycles in stage graph, `completion` conditions satisfiable, at least one required stage with a non-READ activity.
- Per-type `config` validation: registry `Map<ActivityType, ActivityConfigValidator>`.

## Architecture

```java
public enum ValidationLevel { SAVE, PUBLISH }

public record FieldError(String path, String code, String message) {}

public interface ActivityConfigValidator {
    ActivityType supports();
    void validate(ActivityDef activity, String path, ValidationContext ctx, List<FieldError> errors);
}

@Service
public class DraftValidator {
    private final Map<ActivityType, ActivityConfigValidator> registry;
    private final EvidenceRepository evidences;   // for PUBLISH-level ref check
    public DraftValidator(List<ActivityConfigValidator> impls, EvidenceRepository ev) { ... }
    public List<FieldError> validate(JsonNode draft, UUID eventId, ValidationLevel level);
}
```

### Per-type validators (beans, `@Component`)
- `ReadValidator`: optional `config.text`, `config.html` (max length 20k)
- `ViewImageValidator`: requires `config.imageAssetId` (UUID); existence checked only at PUBLISH level
- `MultipleChoiceValidator`: requires `config.question`, `config.options[]` (≥2, unique `id`), exactly one of `correctOptionIds`/`config.multiCorrect[]` non-empty and ⊆ option ids
- `EvidenceSelectValidator`: requires `config.visibleEvidenceIds[]` non-empty; PUBLISH: refs resolve
- `MatchingValidator`: requires `config.pairs[]` (≥2), each `left.id`,`right.id` unique; `correctPairs` ⊆ declared ids
- `DragOrderValidator`: requires `config.items[]` (≥2, unique id); `expectedOrder[]` (PUBLISH) is permutation of items
- `VerificationValidator`: requires `config.onPartial`/`onContradicted` transitions reference valid stage ids (or null); PUBLISH checks targets
- `CerValidator`: requires `config.rubric` object with at least `criteria[]` non-empty; `requiredEvidenceIds[]` non-empty
- `HypothesisChoiceValidator`: requires `config.hypotheses[]` (≥2)
- `ExploreMapValidator`: requires `config.markers[]` (≥1, unique id)
- `ReasoningConnectValidator`: requires `config.nodes[]` (≥2), `config.allowedRelations[]` non-empty
- `ReflectionPromptValidator`: optional; max length constraint on `config.prompt`

Unknown type → `FieldError` `UNSUPPORTED_ACTIVITY_TYPE` (SAVE-level: reject).

### Cross-cutting checks (both levels)
- `stages[*].id` unique, regex-match
- `stages[*].activities[*].id` unique within stage
- `stages[*].type` ∈ StageType
- `stages[*].activities[*].type` ∈ `STAGE_ALLOWED_ACTIVITIES.get(stage.type)` — SAVE level: warn? No — error at SAVE. (Keeps drafts coherent; user can still save incomplete `config`.)
- `nextStageIds[*]` targets exist in `stages[].id`
- Cycle detection: DFS on stage graph; at SAVE emit warning-level error code `STAGE_CYCLE` only when level=PUBLISH? Decision: emit at SAVE too — admins benefit early. Final terminal stage detection: at least one stage reachable with empty `nextStageIds`.

### Publish-only checks
- Required-stage presence: at least one `required=true` stage with non-READ `required=true` activity
- `completion` block: if `requiredStageIds` present, all IDs must exist; if `requireAllRequiredStages`, at least one required stage
- Evidence refs: every `config.evidenceIds`, `visibleEvidenceIds`, `requiredEvidenceIds`, `requiredSourceIds` resolves to `evidences.id` AND `evidences.event_id == lesson.event_id` AND `status IN (DRAFT, APPROVED)`
- Asset refs: `config.imageAssetId` resolves to `assets.id` with `state='ACTIVE'` (if column populated)

## Related files

Replace:
- `com/dauviet/lesson/application/DraftValidator.java` — keep `requireJsonObject/Array` as thin wrappers used by `LessonService` for raw-JSON endpoints; add new `validate(JsonNode,eventId,level)` returning `List<FieldError>`.

Create:
- `com/dauviet/lesson/draft/FieldError.java` (record)
- `com/dauviet/lesson/draft/ValidationLevel.java`
- `com/dauviet/lesson/draft/ValidationContext.java` — carries `eventId`, `ObjectMapper`, evidence-id supplier
- `com/dauviet/lesson/draft/ActivityConfigValidator.java` (interface)
- `com/dauviet/lesson/draft/validators/ReadValidator.java`, `...MultipleChoiceValidator.java`, etc. (~10 small files, ≤50 LOC each)
- `com/dauviet/lesson/draft/DraftValidationException.java` — wraps `List<FieldError>` (thrown by strict paths; controller maps to error envelope)

Modify:
- `com/dauviet/common/error/GlobalExceptionHandler.java` — add handler for `DraftValidationException` → 422 `DRAFT_SCHEMA_INVALID` with `details.errors` = list of `{path,code,message}`.
- `LessonService.updateDraft`: after `requireJsonObject`, run `validator.validate(node, l.getEventId(), SAVE)`; if errors → throw `DraftValidationException` with list.

## Implementation steps
1. Define error model + `ValidationContext` + `ValidationLevel`.
2. Convert `DraftValidator` to a `@Service` with constructor-injected `List<ActivityConfigValidator>` and `EvidenceRepository`. Build registry map in ctor; fail-fast on duplicate `supports()`.
3. Implement structural walk: parse `draftJson` → `LessonDraft`; collect errors while walking. Use `JsonNode` directly (not bound models) so we can emit paths even on type-mismatch.
4. Implement all 12 per-type validators as beans.
5. Implement stage-graph checks (unique ids, valid targets, cycle DFS).
6. Implement publish-only checks guarded by `level == PUBLISH`.
7. Wire into `LessonService.updateDraft` (SAVE level) and `LessonService.update` (objectives + draft shape only — keep current behavior).
8. Extend `GlobalExceptionHandler` for `DraftValidationException`.

## Todo
- [ ] FieldError/ValidationLevel/ValidationContext records
- [ ] ActivityConfigValidator interface + 12 impls
- [ ] DraftValidator service rewrite (structural walk, registry, cycle detect, evidence ref check)
- [ ] DraftValidationException + handler mapping
- [ ] LessonService.updateDraft SAVE-level integration
- [ ] Unit tests for each validator + registry + cycle detector (JUnit, no Spring)

## Success criteria
- `validate()` returns ordered `List<FieldError>` with machine-usable `path`.
- Save-level allows empty `stages` array, missing `config`, missing `instruction`.
- Publish-level rejects a draft missing central conclusion or with dangling `nextStageIds`.

## Risks
- JSON-path formatting inconsistency — establish `PathBuilder` helper.
- Validator registry bean collisions — fail-fast at startup if two beans support same type.

## Security
- Validator must never log `validation` block content (answer keys).
- Field paths are safe to return (already known to admin).
