# Agent instructions

## Start every task

1. Read `docs/PROJECT_OVERVIEW.md`, `docs/TECH_STACK.md` and `docs/CODING_RULES.md`.
2. Read `tasks/<id>/task.json` and `brief.md`; task JSON is the execution source of truth.
3. Inspect relevant files and local changes before editing. Preserve other contributors' work.
4. Read `docs/AGENT_WORKFLOW.md` for risk, verification and handoff policy.

## Context routing

| Change | Additional source |
|---|---|
| API, DTO, authorization | `docs/API_SPEC.md` |
| Database, migration, transaction | `docs/DATABASE_DESIGN.md` |
| Lesson, activity, attempt, reward | `docs/LEARNING_ENGINE_DESIGN.md` |
| Harness | `.harness/config.json`, `.harness/schemas/task.schema.json`, implementation plan |

The three application modules are `dau-viet-backend`, `dau-viet-admin`, and `dau-viet-mobile`.
`dau-viet-backend` is `active` (Spring Boot + Flyway foundation, TASK-0005); `dau-viet-mobile` is `active` (Flutter demo); `dau-viet-admin` remains uninitialized. See `docs/backend-runbook.md` for running the backend locally.

## Workflow and delegation

- Understand → Plan → Implement → Verify → Review → Document → Handoff.
- Delegate planning to `planner-researcher`; if that alias is unavailable, use `planner` with a research responsibility and record the actual role.
- Delegate validation to `tester`, review to `code-reviewer`, and relevant documentation updates to `docs-manager`.
- For server/CI failures, delegate diagnosis to `debugger` before fixing.
- Assign one owner per file/task; avoid concurrent writers. Report tool/role limitations honestly.
- Tiny docs/copy changes need a brief. Normal and high-risk changes need a linked plan and AC-to-check mapping.
- API/DB/auth/ownership/version/reward changes are high-risk. Do not downgrade risk to bypass gates.
- Routine implementation decisions proceed within authorization. Unresolved product/architecture choices go to the user.

## Product invariants

- Backend is authoritative for correctness, progress, completion and reward.
- Published lesson versions are immutable; attempts remain pinned to a published version.
- Check ownership and authorization on the server, including negative tests.
- Submission/completion/reward retries must be idempotent; test transaction and uniqueness behavior.
- Never expose private answer keys to learners or logs.
- No event-specific branches in generic learning handlers/renderers.
- Reuse existing components; preserve API contracts; document breaking changes.
- Never commit secrets. Use structured error handling; do not swallow errors.

## Code intelligence

Use GitNexus only when available and its index matches the current source snapshot.
Record stale/unavailable indexes and gaps (DI, reflection, HTTP, generated code).
Fallback to targeted search and actual symbol/reference tools, then broaden tests for uncertain impact.
Use Context7 for current package documentation when available. Use Serena overview/reference tools when available; otherwise use `rg` and targeted reads. Never invent a tool result.

## Completion

- Run applicable checks and inspect `git diff --check` and scope.
- Missing commands/tests, timeouts and failed checks are not success; N/A needs a policy reason.
- Evidence must identify the current inputs, gate config, tool versions, command and real outcome.
- Any relevant edit invalidates old verification/review evidence.
- Independent review must address blockers; each AC needs an explicit check and artifact.
- Update docs when behavior changes. Store next action, blockers and handoff before finish.
- Task status lives in JSON; `docs/PROGRESS.md` is generated from it.
- Commit/push only within user authorization; the harness does not do them automatically.
- Markdown uses plain headings/lists without decorative icons.
