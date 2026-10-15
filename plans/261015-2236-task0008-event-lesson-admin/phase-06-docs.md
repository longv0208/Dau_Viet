# Phase 06 — Docs + acEvidence

## Context links

- `docs/API_SPEC.md` §3 — admin endpoints table (already lists target paths; needs marking as implemented and adding error codes)
- `docs/DATABASE_DESIGN.md` §5 — append note about V5 migration applied
- `tasks/TASK-0008/task.json` — `acEvidence` field to populate

## Overview

- Priority: P2
- Status: pending
- Final documentation sweep + AC evidence mapping. No code changes.

## Key insights

- API_SPEC already lists `/admin/events`, `/admin/lessons`, `/admin/templates` as proposals — phase-06 marks them implemented and records actual signatures.
- `task.json.acEvidence` maps AC-id → artifact (test class, file, command). Required by AGENT_WORKFLOW.

## Requirements

- Update `docs/API_SPEC.md`:
  - §3 admin table: mark `/admin/events`, `/admin/lessons` (create/list/get/update/draft/archive), `/admin/lesson-templates` as **implemented**, point to phase-05 IT coverage.
  - Add new error codes to error table: `INVALID_STATUS_TRANSITION`, `EVENT_IN_USE`, `LESSON_NOT_FOUND`, `TEMPLATE_NOT_FOUND`, `TEMPLATE_DISABLED`, `DRAFT_SCHEMA_INVALID`, `OPTIMISTIC_LOCK_CONFLICT`.
  - Note `PUT /admin/lessons/{id}/draft` uses `expectedRowVersion` (matches API_SPEC's `expectedDraftRevision` intent; name chosen for consistency with `@Version` field).
- Update `docs/DATABASE_DESIGN.md`:
  - Append: "V5 (2026-10-15): `ALTER TABLE historical_events ADD COLUMN row_version` for optimistic locking; `lessons.row_version` already in V3."
- Update `tasks/TASK-0008/task.json`:
  - `acEvidence`: map AC-1..AC-7 to test classes + commit + mvnw verify outcome (or `NOT VERIFIED`).
  - `status`: `verifying` once phase-05 green; `done` after code-reviewer passes.
  - `nextAction`: e.g. "TASK-0009 lesson publish + version creation".
- Add a short note in `docs/PROJECT_OVERVIEW.md` only if implementation surfaced a real architecture change (e.g. new module boundary) — otherwise skip per YAGNI.

## Related code files

### Modify

- `docs/API_SPEC.md`
- `docs/DATABASE_DESIGN.md`
- `tasks/TASK-0008/task.json`

### Create

- None.

## Implementation steps

1. Edit API_SPEC admin section.
2. Edit DATABASE_DESIGN migration status note.
3. Update `task.json`:
   ```json
   "acEvidence": {
     "AC-1": {"kind": "IT", "ref": "AdminEventsIT", "command": "mvnw verify"},
     "AC-2": {"kind": "IT", "ref": "AdminLessonsIT", "command": "mvnw verify"},
     "AC-3": {"kind": "IT", "ref": "AdminLessonTemplatesIT", "command": "mvnw verify"},
     "AC-4": {"kind": "IT", "ref": "AdminEventsIT.anonymous_401+learner_403, EventsPublicIT", "command": "mvnw verify"},
     "AC-5": {"kind": "IT+migration", "ref": "FlywayMigrationIT.flywayV5Applied + AdminLessonsIT.updateDraft_staleExpectedVersion_409", "command": "mvnw verify"},
     "AC-6": {"kind": "IT", "ref": "All of the above", "command": "mvnw verify"},
     "AC-7": {"kind": "build", "ref": "mvnw verify exit=0", "command": "mvnw verify"}
   }
   ```
4. Final report (in Vietnamese per brief) summarising implemented functionality + actual test results + issues + readiness for TASK-0009.

## Todo

- [ ] `docs/API_SPEC.md` updated.
- [ ] `docs/DATABASE_DESIGN.md` V5 note added.
- [ ] `task.json` `acEvidence` populated.
- [ ] Final report written (Vietnamese, honest about NOT VERIFIED cases).

## Success criteria

- Docs accurately reflect implemented surface; no aspirational endpoints listed as implemented.
- `acEvidence` contains real artifacts.

## Risk assessment

- Low. Pure docs — no compile risk.

## Security considerations

- Do not document tokens/secrets.

## Next steps

- Hand off to `code-reviewer` agent for independent review of phases 01–05.
- Then TASK-0009 (lesson publish + version creation) is unblocked.
