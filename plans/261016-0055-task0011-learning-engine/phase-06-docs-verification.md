# Phase 06 — Docs Update, Verification, Task Handoff

## Context Links

- `docs/API_SPEC.md` §2 learner endpoints table (rows 52–57 currently proposals — mark implemented)
- `docs/LEARNING_ENGINE_DESIGN.md` §13 open decisions
- `docs/DATABASE_DESIGN.md` learner runtime section
- `docs/AGENT_WORKFLOW.md` — evidence + handoff policy
- `tasks/TASK-0011/task.json`

## Overview

| Priority | Status | Effort |
|---|---|---|
| P0 | pending | 1.5h |

Close the loop: update docs to reflect implemented surface, record BA-ambiguous semantics chosen in phase 02, run full `mvnw verify`, prepare `task.json` evidence and handoff to `code-reviewer`.

## Requirements

### API_SPEC.md

- Mark `POST /lessons/{lessonId}/attempts`, `GET /attempts/{attemptId}`, `GET /attempts/{attemptId}/current`, `POST /attempts/{attemptId}/activities/{activityId}/submissions`, `POST /attempts/{attemptId}/complete` as **implemented TASK-0011**.
- Document request/response shapes for each (per phase-04 DTOs).
- Document new error codes in §1 error table: `ATTEMPT_NOT_FOUND`, `ATTEMPT_NOT_OWNER`, `ATTEMPT_NOT_IN_PROGRESS`, `ACTIVITY_NOT_AVAILABLE`, `ATTEMPT_ALREADY_COMPLETED`, `ACTIVITY_ALREADY_SUBMITTED`, `SNAPSHOT_INVALID_FOR_ACTIVITY`, `LESSON_VERSION_MISMATCH`, `UNSUPPORTED_ACTIVITY_TYPE`.
- Note `Idempotency-Key` accepted but not persisted (deferred to TASK-0012).
- Note `lesson_results`/`user_evidence`/`reward_transactions` not yet written.

### LEARNING_ENGINE_DESIGN.md

- Update §5 — replace the sketch `EvaluationResult` with the actual `ActivityResult` shape and note `ActivityHandler`/`ActivityHandlerRegistry` location under `com.dauviet.learning.handler`.
- §6 — mark each activity row with implemented-semantics note (link to phase-02 file).
- §7 — note attempt state is implemented but `COMPLETED`/`ABANDONED` transitions land in TASK-0012.
- §13 — append the "Evaluation Semantics (chosen for MVP)" table from phase-02 so BA/PO can review; mark which open questions are now resolved vs still open.

### DATABASE_DESIGN.md

- Confirm `learner_attempts`/`activity_attempts` write path is now used (previously only declared in V4). Update the "Đề xuất" paragraph with the actual `state_json` schema (completedActivityIds, outputs, currentStageId, currentActivityId) so readers know the field is in use.

### Verification

- `cd dau-viet-backend && mvnw verify` — full suite green.
- `git diff --check` — no whitespace errors.
- `git status` — confirm scope limited to `dau-viet-backend/`, `docs/`, `tasks/TASK-0011/`, `plans/261016-0055-task0011-learning-engine/`.

### task.json updates (by implementer/finisher)

- `status: "reviewing"` after implementation, then `"done"` after code-reviewer pass.
- `acEvidence` — map each AC-1..AC-9 to the concrete test classes/methods that prove it.
- `nextAction` — handoff to `code-reviewer` with this plan path.

## Related Code Files

**Modify**

- `docs/API_SPEC.md`
- `docs/LEARNING_ENGINE_DESIGN.md`
- `docs/DATABASE_DESIGN.md`
- `tasks/TASK-0011/task.json`

## Implementation Steps

1. Update API_SPEC with implemented endpoints + new error codes + deferred items.
2. Update LEARNING_ENGINE_DESIGN with chosen semantics table + resolved open questions.
3. Update DATABASE_DESIGN with `state_json` schema.
4. Run `mvnw verify` from `dau-viet-backend` with `JAVA_HOME=E:\Java\jdk-21`.
5. Fill `acEvidence` in `task.json` and flip status.
6. Hand off to `code-reviewer` with pointers to plan + acEvidence.

## Todo List

- [ ] API_SPEC updated (endpoints + error codes + deferred notes)
- [ ] LEARNING_ENGINE_DESIGN §5/§6/§7/§13 updated with chosen semantics
- [ ] DATABASE_DESIGN `state_json` schema documented
- [ ] `mvnw verify` exit 0; regression suite green
- [ ] `git diff --check` clean
- [ ] `task.json` evidence + status updated
- [ ] `code-reviewer` handoff message includes plan path + acEvidence + open questions

## Success Criteria

- All docs consistent with implemented behavior.
- No `LEARNER_HIDDEN_KEYS` reachable through any learner endpoint.
- `task.json` `acEvidence` lists real tests, not placeholders.

## Risk Assessment

- **Docs drift** — if implementation diverges from plan (e.g., different outcome names), docs must reflect actual code, not plan.
- **Verification skipped under time pressure** — `mvnw verify` is non-negotiable for high-risk tasks per `AGENT_WORKFLOW.md`.

## Security Considerations

- Confirm one last time in docs review that no admin-only field documented as learner-visible.

## Next Steps / Open Questions for User

- VERIFICATION `SUPPORTED` rule: hypothesis chosen + all `requiredEvidenceIds` present. OK?
- CER: completion-only (any non-empty claim+reasoning) vs rubric-enforced?
- `minScore` semantics: percent of required activities completed (chosen) vs weighted rubric.
- EXPLORE_MAP `minMarkers` config — new optional field; default all.
- `ABANDONED` resume policy — defer to TASK-0012.
- Whether `/attempts/{id}/result` (in API_SPEC §2 row 57) ships with TASK-0012 (planned).
