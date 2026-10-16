# TASK-0015 — Backend draft contract research

Surgical verification of the real Spring Boot contract. Java wins over docs; drift flagged at the end.

## 1. Draft-save endpoint (verbatim)

```java
// AdminLessonController.java — /api/v1/admin/lessons
@PutMapping("/{id}/draft")
public AdminLessonResponse updateDraft(@PathVariable UUID id,
                                       @Valid @RequestBody AdminLessonDraftRequest req,
                                       @AuthenticationPrincipal Jwt jwt)
```

```java
public record AdminLessonDraftRequest(
        @NotNull String draftJson,     // raw JSON string, must parse to a JSON object
        Long expectedRowVersion        // optional; on mismatch → 409 OPTIMISTIC_LOCK_CONFLICT
) {}
```

```java
public record AdminLessonResponse(
        UUID id, UUID eventId, UUID templateId, String title, String centralQuestion,
        String objectivesJson, String draftJson, String status,
        UUID currentVersionId, Long rowVersion,
        UUID createdBy, UUID updatedBy, Instant createdAt, Instant updatedAt) {}
```

**Errors (GlobalExceptionHandler → ApiError {code,message,details,traceId}):**
- `400 VALIDATION_ERROR` — missing/malformed JSON body.
- `404 LESSON_NOT_FOUND`.
- `409 OPTIMISTIC_LOCK_CONFLICT` — `expectedRowVersion` mismatch.
- `409 INVALID_STATUS_TRANSITION` — lesson `ARCHIVED`; also when status not `DRAFT` (LessonDraftService only). `updateDraft` itself only blocks `ARCHIVED` — a `PUBLISHED` lesson's draft_json CAN still be replaced.
- `422 DRAFT_SCHEMA_INVALID` — either from `DraftSchemaInvalidException` (draftJson not a JSON object / not parseable) or `DraftValidationException` with `details.errors[] = {path,code,message}`.

## 2. draftJson top-level schema (DraftSchema.java)

```java
public static final int CURRENT_VERSION = 1;
public static final Pattern ID_PATTERN = Pattern.compile("[a-z0-9][a-z0-9-]{1,63}");

TOP_LEVEL_KEYS   = { "schemaVersion", "stages", "completion", "objectives" }
STAGE_KEYS       = { "id", "type", "title", "required", "activities",
                     "nextStageIds", "requiredEvidenceIds" }
ACTIVITY_KEYS    = { "id", "type", "required", "instruction", "config",
                     "validation", "feedback", "evidenceRefs" }
COMPLETION_KEYS  = { "requireAllRequiredStages", "requiredStageIds", "minScore" }
```

Unknown keys → `UNKNOWN_FIELD` FieldError at SAVE.

**Stage shape:**
```json
{
  "id": "ctx",                      // required, ID_PATTERN, unique across all stages
  "type": "CONTEXT",                // required, StageType enum
  "title": "…",                     // optional string
  "required": true,                 // optional boolean (default false)
  "activities": [ … ],              // optional array; each object per ACTIVITY_KEYS
  "nextStageIds": ["ev"],           // optional string[]; must resolve to stage ids
  "requiredEvidenceIds": ["uuid"]   // optional UUID[]; existence checked at PUBLISH only
}
```

**Activity shape:**
```json
{
  "id": "r1",                       // required, ID_PATTERN, unique across whole draft
  "type": "READ",                   // required, ActivityType enum
  "required": true,                 // optional boolean
  "instruction": "…",               // optional string
  "config": { … },                  // per-type object, see §4
  "validation": { … },              // server-only block (not typed yet)
  "feedback": { … },                // free-form feedback block
  "evidenceRefs": ["uuid"]          // stage-level evidence refs inside activity; PUBLISH-checked
}
```

**Completion shape:** `{"requireAllRequiredStages":bool, "requiredStageIds":[stageIds], "minScore":number}`.

**SAVE vs PUBLISH:**
- SAVE tolerates: missing `schemaVersion`, empty `stages`, missing activity `config`, missing `correctOptionIds`, unknown evidence/asset refs (existence not checked), empty `completion`, no terminal stage, `required:true` inside `required:false` stage.
- SAVE rejects: malformed JSON, wrong types, unknown keys, duplicate ids, id not matching pattern, unknown stage/activity type, `STAGE_ACTIVITY_MISMATCH`, `UNKNOWN_STAGE_ID` in `nextStageIds`/`completion.requiredStageIds`, `CIRCULAR_TRANSITION`.
- PUBLISH adds: `schemaVersion` required, `stages` non-empty, required config fields per-type, evidence/asset existence, terminal reachable, `NO_REQUIRED_ACTIVITY`, `REQUIRED_IN_OPTIONAL_STAGE`, `EMPTY_COMPLETION`, `requireAllRequiredStages` sanity.

## 3. Enums (verbatim)

```java
public enum StageType {
    CONTEXT, DISCOVERY, EVIDENCE, REASONING, HYPOTHESIS,
    RECONSTRUCTION, VERIFICATION, CONCLUSION, REFLECTION
}

public enum ActivityType {
    READ, VIEW_IMAGE, MULTIPLE_CHOICE, EXPLORE_MAP, EVIDENCE_SELECT,
    MATCHING, REASONING_CONNECT, HYPOTHESIS_CHOICE, DRAG_ORDER,
    VERIFICATION, CER, REFLECTION_PROMPT
}
```

`CER` is the canonical name (not `CLAIM_EVIDENCE_REASONING`).

**Stage → allowed activities (DraftSchema.STAGE_ALLOWED_ACTIVITIES):**

| StageType | Allowed ActivityTypes |
|---|---|
| CONTEXT | READ, VIEW_IMAGE |
| DISCOVERY | EXPLORE_MAP, VIEW_IMAGE, READ |
| EVIDENCE | EVIDENCE_SELECT, MULTIPLE_CHOICE, READ |
| REASONING | MATCHING, REASONING_CONNECT, MULTIPLE_CHOICE, READ |
| HYPOTHESIS | HYPOTHESIS_CHOICE, READ |
| RECONSTRUCTION | DRAG_ORDER, READ |
| VERIFICATION | VERIFICATION, MULTIPLE_CHOICE, READ |
| CONCLUSION | CER, READ |
| REFLECTION | REFLECTION_PROMPT, READ |

READ is universal — allowed in every stage.

## 4. Per-activity `config` contract (validators/)

| Type | `config` shape (required at SAVE) | Required at PUBLISH only | Notes |
|---|---|---|---|
| READ | `{ text?: string }` — config itself optional | `text ≤ 20_000` chars | config-free at SAVE is OK |
| VIEW_IMAGE | `{ imageAssetId: string }` — required at SAVE | asset `state=ACTIVE` exists | `imageAssetId` is the asset UUID |
| EXPLORE_MAP | `{ markers: [{id,...}] }` ≥1 unique ids | — | per-item shape loose |
| EVIDENCE_SELECT | `{ visibleEvidenceIds: string[] }` ≥1 | each id exists in event + status DRAFT/APPROVED | `minRequired` used at runtime (default 1) — not validated at SAVE |
| MULTIPLE_CHOICE | `{ question: string, options: [{id,...}] }` ≥2 unique ids + exactly one of `correctOptionIds[]` or `multiCorrect[]` (subset of option ids) | one of the correct-id arrays is required | both at once → `INVALID_CONFIG`; each option needs `id`; label/text is not validated |
| MATCHING | `{ pairs: [{left:{id,...}, right:{id,...}}] }` ≥2, unique left/right ids | `correctPairs: [{left,right}]` optional, each must reference declared ids | item fields beyond `id` are free-form |
| DRAG_ORDER | `{ items: [{id,...}] }` ≥2 unique ids | `expectedOrder: string[]` required at PUBLISH, permutation of item ids | items need only `id`; label free |
| VERIFICATION | config optional at SAVE | `visibleSourceIds[]`, `requiredEvidenceIds[]` — evidence-checked at PUBLISH | outcome-driven transitions via `onPartial`/`onContradicted` (activity-level fields, not config) |
| CER | `config` required at SAVE; `{ rubric: { criteria: […] } non-empty, requiredEvidenceIds: string[] ≥1 }` | `requiredEvidenceIds` evidence-checked | no claim/evidence/reasoning prompt fields in validator — the runtime reads `claim`/`reasoning` from learner output, not config |
| REASONING_CONNECT | `{ nodes: [{id,...}] ≥2, allowedRelations: string[] ≥1 }` | — | relation semantics loose |
| HYPOTHESIS_CHOICE | `{ hypotheses: [{id,...}] ≥2 }` | — | expected hypothesis key not validated |
| REFLECTION_PROMPT | `{ prompt?: string ≤2_000 }` — config optional | — | free-form |

**Server-only keys** (stripped before learner sees them; safe to author, never displayed to learners): `correctOptionIds, correctPairs, correctOrder, expectedOrder, requiredEvidenceIds, expectedHypothesis, answerKey, answer, key, expected`. Builder UI must treat these as authoring-only fields and avoid rendering them as "learner-facing" preview.

## 5. StageTransitionResolver semantics

- `nextStageIds[]` is array-order, declarative. Cycle = `CIRCULAR_TRANSITION` (SAVE).
- Publish requires at least one stage with empty `nextStageIds` reachable from `stages[0]`.
- At runtime, transitions skip required-free "transparent" stages.
- Activity-level `onPartial`/`onContradicted` trigger REVISE hops; they live on the **activity object** (top-level alongside `id`/`type`), not inside `config`. Currently `ACTIVITY_KEYS` does NOT list them — emitting them today would be `UNKNOWN_FIELD`. Do not write them; if needed for VERIFICATION activities, file a backend gap.

## 6. Template / presetJson behavior

- `POST /admin/lessons` does NOT merge `template.presetJson`. If `draftJson` is omitted the column default `'{}'::jsonb` is used (`LessonService.create` → `req.draftJson() == null ? "{}" : …`).
- `GET /admin/lesson-templates` returns `LessonTemplateResponse[]` with raw `presetJson` string. Shape is opaque — not validated by the Java layer today (only `jsonb_typeof='object'`).
- **Implication:** the Builder's "Tạo cấu trúc từ khung bài học" action must parse `presetJson` client-side and write it into the draft. There is no backend endpoint that does the instantiation.

## 7. Snapshot / publish path

- `PUT /admin/lessons/{id}/draft` only writes `lessons.draft_json` (JSONB). `current_version_id` and `lesson_versions.snapshot_json` are untouched.
- `lesson_versions` is hard-immutable via DB trigger (`prevent_lesson_version_mutation`).
- `POST /admin/lessons/{id}/validate` returns `PublishReadinessResponse` (read-only; safe to call for "publish readiness" indicator).
- `POST /admin/lessons/{id}/publish` runs the real publish — out of scope for the builder.

## 8. Doc↔code drift

- `docs/LEARNING_ENGINE_DESIGN.md` line 16 says activity has `output` field — `ACTIVITY_KEYS` does not allow it. Java wins.
- Line 30 mentions `MAP_PLACE` — not in `ActivityType`.
- Line 32 says Conclusion stage uses `CER` — matches.
- `docs/API_SPEC.md` line 230 says `PUT /{id}/draft` validates "draftJson is a JSON object" — accurate but understates: it also runs the SAVE-level schema walk.

## 9. Open questions / risks

- **`onPartial`/`onContradicted`**: referenced by `StageTransitionResolver` but not in `ACTIVITY_KEYS`. Either DraftSchema is missing keys or the resolver reads fields that can never be saved. Needs confirmation; builder should not emit them until backend adds keys.
- **VERIFICATION activity's stage-transition fields** are not part of `config` — same `UNKNOWN_FIELD` risk if author tries to drive transitions.
- **`presetJson` shape is opaque.** Sample seed data uses `'{}'` so builder cannot rely on a structure. If template presetJson turns out non-empty in real DB, its stage shape must mirror draft stage shape — verify with Content Admin before relying on it.
- **Evidence catalogue endpoint**: `GET /admin/evidences` exists (stub returns empty page). EVIDENCE_SELECT editor needs a real picker — TASK-0016 candidate per brief; for now provide free-text UUID list + warning.
- **Asset picker**: `imageAssetId` is a UUID. No asset-list endpoint verified in this pass (did not grep `/admin/assets`); same "free text + warning" pattern unless TASK-0016 supplies one.
- **`rowVersion` is `Long` server-side; `expectedRowVersion` is optional.** Send it always — protects against concurrent edits.
- **`updateDraft` allows PUBLISHED lessons' draft to be replaced** — only `ARCHIVED` is rejected. UI should warn on `status==='PUBLISHED'` (new edits fork a new draft but published version stays immutable).
- **ID format**: `^[a-z0-9][a-z0-9-]{1,63}$` — NOT UUIDs. `crypto.randomUUID()` will fail validation. Builder must generate slug-style ids (`stage-abc123` etc.).

## Files cited

- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonDraftRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/dto/AdminLessonResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftSchema.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/DraftValidator.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/StageType.java`, `ActivityType.java`, `FieldError.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/draft/validators/AbstractActivityValidator.java`, `SimpleActivityValidators.java`, `MultipleChoiceValidator.java`
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java`, `LessonDraftService.java`
- `dau-viet-backend/src/main/java/com/dauviet/learning/resolver/StageTransitionResolver.java`
- `dau-viet-backend/src/main/resources/db/migration/V3__authoring_publishing_evidence_assets.sql`
- `docs/API_SPEC.md`, `docs/LEARNING_ENGINE_DESIGN.md`
