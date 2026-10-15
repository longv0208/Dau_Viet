# Phase 05 — Publish-readiness endpoint

## Context links
- `phase-02-draft-validator.md` (ValidationLevel.PUBLISH)
- `docs/LEARNING_ENGINE_DESIGN.md` §9 (publish guardrails)
- `docs/API_SPEC.md` §3 — `POST /admin/lessons/{lessonId}/validate` listed, returns structured errors

## Overview
- Priority: P1
- Status: pending
- New endpoint `POST /api/v1/admin/lessons/{id}/validate` runs `DraftValidator` at `PUBLISH` level plus a small set of lesson-level checks and returns a structured report — does NOT create `lesson_versions`. That is TASK-0010.

## Requirements
- Idempotent POST (no body, optional `expectedRowVersion` for parity — does not mutate).
- Returns `200` with `{ready:boolean, errors:[FieldError], warnings:[FieldError], summary:{stages,activities,evidenceRefs}}`.
- Errors vs warnings: errors block publish; warnings are informational (e.g., `DRAFT`-status evidence refs, missing optional `feedback` key on activity).
- Reuse `DraftValidator.validate(draft, eventId, PUBLISH)`; do not duplicate rules.
- Lesson-level checks in service:
  - `centralQuestion` non-blank
  - `objectivesJson` non-empty array (warning if empty — BA may not require)
  - `template.schemaVersion == DraftSchema.CURRENT_VERSION` (else error `TEMPLATE_SCHEMA_MISMATCH`)
- Returns the same response shape regardless of pass/fail; caller inspects `ready` flag.

## Endpoint

```
POST /api/v1/admin/lessons/{id}/validate
Authorization: Bearer <admin>
-> 200
{
  "ready": false,
  "errors": [
    {"path":"stages[2].activities[1].id","code":"DUPLICATE_ID","message":"duplicate id 'act-intro'"},
    {"path":"stages[0].nextStageIds[0]","code":"UNKNOWN_STAGE_ID","message":"stage 'stage-x' not found"},
    {"path":"stages[3].activities[0].config.visibleEvidenceIds[2]","code":"EVIDENCE_NOT_FOUND","message":"evidence 'ev-missing' not found in event"}
  ],
  "warnings": [
    {"path":"stages[1].activities[0].feedback","code":"MISSING_FEEDBACK","message":"recommended"}
  ],
  "summary": {"stages":5,"activities":12,"evidenceRefs":7,"uniqueEvidenceRefs":4}
}
```

No `422` on validation failure — `200` + `ready:false`. Reserve `422` for malformed request itself (lesson not found still → 404). This differs from typical "throw on invalid" because the response IS the validation report — the report itself is successful.

## Service

Add to `LessonDraftService` (or new `LessonPublishCheckService` — prefer reuse in `LessonDraftService` to keep file count low):

```java
public ValidationReport checkPublishReadiness(UUID lessonId) {
    Lesson l = load(lessonId);
    List<FieldError> errors = new ArrayList<>();
    List<FieldError> warnings = new ArrayList<>();

    if (l.getCentralQuestion() == null || l.getCentralQuestion().isBlank())
        errors.add(new FieldError("centralQuestion","MISSING","central question required"));

    if (isEmptyArray(l.getObjectivesJson()))
        warnings.add(new FieldError("objectives","EMPTY","no learning objectives"));

    LessonTemplate tpl = templates.findById(l.getTemplateId()).orElseThrow(...);
    if (tpl.getSchemaVersion() != DraftSchema.CURRENT_VERSION)
        errors.add(new FieldError("templateId","TEMPLATE_SCHEMA_MISMATCH",
            "template schema_version="+tpl.getSchemaVersion()+" != "+DraftSchema.CURRENT_VERSION));

    JsonNode draft = readDraftJson(l);
    errors.addAll(draftValidator.validate(draft, l.getEventId(), ValidationLevel.PUBLISH));

    return new ValidationReport(errors.isEmpty(), errors, warnings, summarize(draft));
}
```

`ValidationReport` record: `{boolean ready, List<FieldError> errors, List<FieldError> warnings, Summary summary}`.

## Files

Create:
- `com/dauviet/lesson/api/dto/ValidationReportDto.java`
- `com/dauviet/lesson/api/dto/FieldErrorDto.java` (mirror FieldError, or expose FieldError directly — fine to expose record)

Modify:
- `AdminLessonDraftController` (or `AdminLessonController` — pick `AdminLessonDraftController` for cohesion): `POST /{id}/validate`.
- `LessonDraftService`: add `checkPublishReadiness`.

## Implementation steps
1. `FieldErrorDto`/`ValidationReportDto` records (or expose `FieldError` directly — it's a record already; just return it).
2. `LessonDraftService.checkPublishReadiness` — lesson-level + delegate to `DraftValidator`.
3. Controller endpoint — `@PostMapping("/{id}/validate")` on `AdminLessonDraftController`.
4. Return 200 always (except 404 lesson, 401/403 auth).

## Todo
- [ ] Report DTOs
- [ ] Service method
- [ ] Controller endpoint
- [ ] IT covering: happy-path ready draft returns ready:true + zero errors; broken draft returns ready:false + non-empty errors with paths

## Success criteria
- `POST /validate` on a valid draft returns `ready:true`, empty errors array.
- Invalid draft returns `ready:false`, errors contain `path`+`code`.
- Endpoint does not modify `row_version`, `draft_json`, `status`.
- No `lesson_versions` insert.

## Risks
- Caller might confuse `ready:true` with published state — document that this is a dry-run; publish is a separate endpoint (TASK-0010).

## Security
- Errors never echo `validation` object contents — only paths and codes.
