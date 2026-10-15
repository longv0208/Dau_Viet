# Phase 03 — Stage + Activity APIs

## Context links
- `phase-01-draft-schema-contract.md` (canonical draft_json)
- `phase-02-draft-validator.md` (SAVE-level validation)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/api/AdminLessonController.java` (existing lesson CRUD)
- `dau-viet-backend/src/main/java/com/dauviet/lesson/application/LessonService.java`

## Overview
- Priority: P1
- Status: pending
- Sub-resource endpoints under `/api/v1/admin/lessons/{lessonId}/draft/stages` and `/stages/{stageId}/activities` operate directly on `draft_json` inside `lessons` row. All mutations respect `expectedRowVersion` for optimistic lock.

## Requirements
- Stable IDs auto-generated when client omits (`stage-<slug>` / `act-<slug>`) or supplied by client.
- Reorder via `PUT order` with full ordered-ID array — atomic, idempotent.
- All mutations write back the full `draft_json` to the lesson row (single-column update), run SAVE-level `DraftValidator` before commit, and re-throw `DraftValidationException` if errors.
- Stage deletion cascades to its activities and clears `nextStageIds` references that point to it (plus `completion.requiredStageIds` entries). Activity deletion clears `config.evidenceIds` references? — No. Evidence refs are validated only at publish-check; deleting an activity does not alter other activities.
- Activity add/update enforces `STAGE_ALLOWED_ACTIVITIES` allow-list.
- All endpoints `CONTENT_ADMIN` (existing `/api/v1/admin/**` filter).

## Endpoint surface

### Stages

```
GET    /api/v1/admin/lessons/{lessonId}/draft/stages
       -> 200 { stages:[StageDto], rowVersion }
POST   /api/v1/admin/lessons/{lessonId}/draft/stages
       body { id?, type, title?, required?, activities?, nextStageIds?, position? }
       -> 201 StageDto  (position defaults to append)
GET    /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}
       -> 200 StageDto
PATCH  /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}
       body { title?, required?, nextStageIds?, expectedRowVersion }
       (type & id immutable)
       -> 200 StageDto
DELETE /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}?expectedRowVersion=N
       -> 204
PUT    /api/v1/admin/lessons/{lessonId}/draft/stages/order
       body { orderedIds:[...], expectedRowVersion }
       -> 200 { stages:[StageDto], rowVersion }
```

### Activities

```
GET    /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities
       -> 200 { activities:[ActivityDto], rowVersion }
POST   /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities
       body { id?, type, required?, instruction?, config?, validation?, feedback?, evidenceRefs?, position? }
       -> 201 ActivityDto
GET    /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}
PATCH  /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}
       body { required?, instruction?, config?, validation?, feedback?, evidenceRefs?, expectedRowVersion }
       (type & id immutable)
DELETE /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/{activityId}?expectedRowVersion=N
PUT    /api/v1/admin/lessons/{lessonId}/draft/stages/{stageId}/activities/order
       body { orderedIds:[...], expectedRowVersion }
```

### Validation behaviour

- POST/PATCH stage: run `DraftValidator.validate(draft, eventId, SAVE)` after applying mutation. Errors → 422.
- PATCH `nextStageIds`: must reference existing stage IDs, must not include self → 422 `CIRCULAR_TRANSITION` or `UNKNOWN_STAGE_ID`. Self-loop counted as cycle.
- POST activity: `type` must ∈ `STAGE_ALLOWED_ACTIVITIES.get(stage.type)` → 422 `STAGE_ACTIVITY_MISMATCH`.
- PUT order: `orderedIds` length must equal current collection size and contain same set → 400 `VALIDATION_ERROR` (mismatched ids).

## DTOs (records)

```java
public record StageDto(
    String id, String type, String title, Boolean required,
    List<ActivityDto> activities, List<String> nextStageIds,
    List<String> requiredEvidenceIds) {}

public record ActivityDto(
    String id, String type, Boolean required, String instruction,
    JsonNode config, JsonNode validation, JsonNode feedback,
    List<String> evidenceRefs) {}

public record StageUpsertRequest(
    String id, @NotBlank String type, String title, Boolean required,
    List<String> nextStageIds, Integer position, Long expectedRowVersion) {}

public record StagePatchRequest(
    String title, Boolean required, List<String> nextStageIds,
    List<String> requiredEvidenceIds, Long expectedRowVersion) {}

public record ActivityUpsertRequest(
    String id, @NotBlank String type, Boolean required, String instruction,
    JsonNode config, JsonNode validation, JsonNode feedback,
    List<String> evidenceRefs, Integer position, Long expectedRowVersion) {}

public record ActivityPatchRequest(
    Boolean required, String instruction, JsonNode config,
    JsonNode validation, JsonNode feedback, List<String> evidenceRefs,
    Long expectedRowVersion) {}

public record OrderRequest(@NotEmpty List<String> orderedIds, Long expectedRowVersion) {}

public record DraftStagesResponse(List<StageDto> stages, Long rowVersion) {}
public record DraftActivitiesResponse(List<ActivityDto> activities, Long rowVersion) {}
```

## Service architecture

Create `LessonDraftService` (sibling to `LessonService`) — does NOT touch `Lesson.status`/`current_version_id`; only `draft_json` + `updated_by` + relies on `@Version row_version` for optimistic lock.

```java
@Service
public class LessonDraftService {
    private final LessonRepository lessons;
    private final DraftValidator draftValidator;
    private final ObjectMapper om;

    public StageDto addStage(UUID lessonId, StageUpsertRequest req, UUID adminId);
    public StageDto patchStage(UUID lessonId, String stageId, StagePatchRequest req, UUID adminId);
    public void deleteStage(UUID lessonId, String stageId, Long expected, UUID adminId);
    public DraftStagesResponse reorderStages(UUID lessonId, OrderRequest req, UUID adminId);
    public List<StageDto> listStages(UUID lessonId);
    public StageDto getStage(UUID lessonId, String stageId);

    public ActivityDto addActivity(...);        // mirrors stage methods
    public ActivityDto patchActivity(...);
    public void deleteActivity(...);
    public DraftActivitiesResponse reorderActivities(...);
    public List<ActivityDto> listActivities(...);
    public ActivityDto getActivity(...);
}
```

Internal helpers:
- `load(lessonId)` → `Lesson` (404 if absent)
- `readDraft(lesson)` → `ObjectNode` (parse `draftJson`)
- `mutateDraft(lesson, Function<ObjectNode,ObjectNode> mutator, Long expected, UUID adminId)`: check `expectedRowVersion`, apply mutator, run `DraftValidator` SAVE-level, `setDraftJson(mapper.writeValueAsString(node))`, `setUpdatedBy(adminId)`, `saveAndFlush`.
- `requireStage(node, stageId)` → `ObjectNode` (404 `STAGE_NOT_FOUND`)
- `requireActivity(stageNode, activityId)` → `ObjectNode` (404 `ACTIVITY_NOT_FOUND`)
- `genId(prefix, takenSet)` — slug collision-safe: `stage-<n>` if slug empty.

`StageService.deleteStage` cleans: removes stage node, walks siblings' `nextStageIds` arrays removing the deleted id, removes from `completion.requiredStageIds`.

## Files

Create:
- `com/dauviet/lesson/api/AdminLessonDraftController.java` — single controller for all stage/activity sub-resources (paths nested under lesson id)
- `com/dauviet/lesson/api/dto/{StageDto,ActivityDto,StageUpsertRequest,StagePatchRequest,ActivityUpsertRequest,ActivityPatchRequest,OrderRequest,DraftStagesResponse,DraftActivitiesResponse}.java`
- `com/dauviet/lesson/application/LessonDraftService.java`
- `com/dauviet/lesson/domain/{StageNotFoundException,ActivityNotFoundException,UnsupportedActivityTypeException,CircularTransitionException,DraftOrderMismatchException}.java`

Modify:
- `GlobalExceptionHandler` — map `StageNotFoundException`/`ActivityNotFoundException` → 404; `CircularTransitionException` → 422 `CIRCULAR_TRANSITION`; `UnsupportedActivityTypeException` → 422 `UNSUPPORTED_ACTIVITY_TYPE`; `DraftOrderMismatchException` → 400 `VALIDATION_ERROR`.
- `ErrorCode` — add `STAGE_NOT_FOUND`, `ACTIVITY_NOT_FOUND`, `STAGE_ACTIVITY_MISMATCH`, `CIRCULAR_TRANSITION`, `UNSUPPORTED_ACTIVITY_TYPE`, `EVIDENCE_NOT_FOUND`, `EVIDENCE_IN_USE`, `ASSET_NOT_FOUND`, `LESSON_NOT_READY` (publish-check uses code list, not single error).

## Implementation steps
1. DTOs + new error codes + exceptions.
2. `LessonDraftService` scaffolding: `load`, `readDraft`, `mutateDraft`, `requireStage`, `requireActivity`, `genId`.
3. Stage CRUD methods (list, get, add, patch, delete with transition cleanup, reorder).
4. Activity CRUD methods (same pattern, plus allow-list check).
5. `AdminLessonDraftController` wiring all endpoints; `@AuthenticationPrincipal Jwt` → adminId (copy `adminId()` helper from `AdminLessonController` or extract shared util — extract to `AdminAuth` helper to avoid dup).
6. Extend `GlobalExceptionHandler` for new exceptions.
7. Wire `LessonService.updateDraft` (existing full-draft PUT) to use SAVE-level `DraftValidator` too — keeps both entry-points consistent.

## Todo
- [ ] All DTOs + exceptions + error codes
- [ ] `LessonDraftService` stage CRUD + reorder + transition cleanup
- [ ] `LessonDraftService` activity CRUD + reorder + allow-list
- [ ] `AdminLessonDraftController` with all routes
- [ ] `GlobalExceptionHandler` mappings
- [ ] Reuse `expectedRowVersion` optimistic-lock pattern

## Success criteria
- Reorder is atomic: concurrent `PUT order` with stale `expectedRowVersion` → 409.
- Add stage with `nextStageIds:[missing]` → 422 with path `nextStageIds[0]` and code `UNKNOWN_STAGE_ID`.
- Delete stage `S2` that `S1.nextStageIds=[S2]` removes `S2` from `S1.nextStageIds` automatically.
- Activity POST on stage CONTEXT with type=MATCHING → 422 `STAGE_ACTIVITY_MISMATCH`.
- `AdminLessonIT` still green (PUT full draft still works after `DraftValidator` change — keep SAVE level so `{"stages":[]}` passes).

## Risks
- Full `draft_json` rewrite per sub-resource call = race-prone if clients mix raw PUT + sub-resource PATCH. Mitigation: same `expectedRowVersion` contract, return new `rowVersion` in every response.
- JSON paths in errors must match what admin UI will display — keep `stages[i].activities[j]` consistent.

## Security
- All routes under `/api/v1/admin/**` → `CONTENT_ADMIN` (existing SecurityConfig covers).
- `validation`/`config.correct*` fields accepted on write — they're server-side secrets, that's correct for admin flow.
