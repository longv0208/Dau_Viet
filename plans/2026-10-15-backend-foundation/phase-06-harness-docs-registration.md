# Phase 06 — Harness task.json registration + docs

## Context links
- Plan: [plan.md](plan.md)
- Workflow: `docs/AGENT_WORKFLOW.md` (module registration, gate config)
- Harness config: `.harness/config.json`
- Task template: `.harness/templates/task.md`, schema `.harness/schemas/task.schema.json`

## Overview
- **Priority:** P1
- **Status:** completed
- **Effort:** 1h
- Register `backend` module as `active` in `.harness/config.json`, create `tasks/TASK-0005/` (brief + task.json), and update `docs/` so future agents can navigate the new module.

## Key insights
- `.harness/config.json` currently has `backend.status=uninitialized` with empty `gates`. Once `pom.xml` and `mvnw` exist plus smoke test passes, transition to `active` with real gates.
- `runner.shell = pwsh` — pwsh is NOT installed on this machine; `harness-self-test` will fail locally (documented). Backend gates themselves use `cmd`/binary paths so they still work.
- Task IDs next available: TASK-0005 (0004 is mobile bootstrap, still `implementing`).

## Requirements
- Update `.harness/config.json`:
  ```json
  "backend": {
    "path": "dau-viet-backend",
    "status": "active",
    "manifests": ["pom.xml", "mvnw.cmd"],
    "gates": [
      {
        "id": "backend-compile",
        "executable": "cmd.exe",
        "args": ["/c", "set JAVA_HOME=E:\\Java\\jdk-21&& mvnw.cmd -q -DskipTests compile"],
        "cwd": "dau-viet-backend",
        "timeoutSeconds": 240
      },
      {
        "id": "backend-test",
        "executable": "cmd.exe",
        "args": ["/c", "set JAVA_HOME=E:\\Java\\jdk-21&& mvnw.cmd -q verify"],
        "cwd": "dau-viet-backend",
        "timeoutSeconds": 600
      }
    ]
  }
  ```
  Use `cmd.exe /c` because `mvnw.cmd` is a batch file (PowerShell `pwsh` wouldn't invoke it directly without `cmd`). Setting `JAVA_HOME` inline works around the broken env var.
- Create `tasks/TASK-0005/brief.md` — summary per template (Goal, ACs, Scope, Plan link, Verification map).
- Create `tasks/TASK-0005/task.json` — `type=feature`, `risk=high-risk` (DB + public API), `status=implementing` (or `ready` before work starts), `modules=["backend"]`, `scope=["dau-viet-backend/","docs/backend-flutter-contract-notes.md","plans/2026-10-15-backend-foundation/"]`, ACs listed below, `planPath` pointing to this plan, `dependencies=["TASK-0004"]` optional (no strict dep — decide: remove dependency since backend doesn't depend on mobile).

  **Acceptance criteria:**
  - AC-1: `dau-viet-backend/` Maven project compiles (`mvnw -DskipTests package` green on Java 21).
  - AC-2: `docker compose up -d postgres` boots Postgres 16 healthy on port 5433.
  - AC-3: Flyway V1 creates `historical_events` with snake_case cols, UUID PK, timestamptz, CHECK on status.
  - AC-4: `GET /api/v1/events` returns paginated published events only; 400 on invalid page/size/sort.
  - AC-5: `GET /api/v1/events/{id}` returns detail for published; 404 `EVENT_NOT_FOUND` for missing/draft; 400 `MALFORMED_ID` for non-UUID.
  - AC-6: Error contract `{code,message,details,traceId}` on all errors; `X-Request-Id` header echoed.
  - AC-7: Spring Security permits public GETs on `/api/v1/events/**` + actuator health/info; other endpoints 401.
  - AC-8: Dev seed inserts Bach Dang 938 idempotently under `local` profile only.
  - AC-9: `mvnw verify` runs unit + Testcontainers integration tests green (or NOT VERIFIED if Docker daemon absent, with reason recorded).
  - AC-10: `docs/backend-flutter-contract-notes.md` documents field deltas for the next mobile task.

- Update `docs/`:
  - `docs/backend-runbook.md` (new): prerequisites (JDK 21 at `E:\Java\jdk-21`, Docker, Maven wrapper), `docker compose -f dau-viet-backend/docker-compose.yml up -d`, `mvnw spring-boot:run -Dspring-boot.run.profiles=local`, health check URL, common issues (JAVA_HOME broken, port collisions, Docker daemon).
  - `docs/development-roadmap.md` (if exists): mark backend foundation done.
  - `docs/project-changelog.md` (if exists): add entry.
  - `docs/system-architecture.md` (if exists): append backend module summary.
  - `AGENTS.md`: update the "registry starts uninitialized" line — backend is now active.
  - `docs/API_SPEC.md` (if exists): add `/api/v1/events` endpoints section.

## Related code files
- Modify: `.harness/config.json`
- Create: `tasks/TASK-0005/brief.md`
- Create: `tasks/TASK-0005/task.json`
- Create: `docs/backend-runbook.md`
- Create: `docs/backend-flutter-contract-notes.md` (already covered in phase-05)
- Modify (if they exist): `docs/development-roadmap.md`, `docs/project-changelog.md`, `docs/system-architecture.md`, `docs/API_SPEC.md`, `AGENTS.md`

## Implementation steps
1. Verify all earlier phases complete and `mvnw verify` green (or NOT VERIFIED with reason).
2. Update `.harness/config.json` → `backend.status = "active"` + manifests + gates as above.
3. Create `tasks/TASK-0005/brief.md` + `task.json` matching the schema (validate against `.harness/schemas/task.schema.json`).
4. Write `docs/backend-runbook.md`.
5. Write `docs/backend-flutter-contract-notes.md` (from phase-05 output).
6. Update existing docs (roadmap/changelog/architecture/API_SPEC/AGENTS) if present.
7. Run `scripts/harness/harness.ps1 doctor` if pwsh available — else record not run.
8. Commit when authorized: `feat(backend): bootstrap Spring Boot backend with historical events API`.

## Todo checklist
- [ ] `.harness/config.json` backend active with two real gates
- [ ] `tasks/TASK-0005/` exists, validates against schema
- [ ] `docs/backend-runbook.md` written
- [ ] `docs/backend-flutter-contract-notes.md` written
- [ ] `AGENTS.md` updated (backend no longer uninitialized)
- [ ] Docs `roadmap`/`changelog`/`architecture`/`API_SPEC` updated where present
- [ ] All ACs have at least one artifact link in `acEvidence`

## Success criteria
- `harness doctor` (when pwsh exists) reports `backend` module active and gates green
- `tasks/TASK-0005/task.json` validates against schema
- Fresh-clone developer can follow `docs/backend-runbook.md` to boot the stack

## Risk assessment
- Wrong gate `executable` (`mvnw.cmd` vs `cmd.exe /c`) — use `cmd.exe` form shown.
- Forgetting `set JAVA_HOME=...` inline — backend gate would fail on machines sharing this broken env var.
- Marking backend `active` before smoke test → harness dishonesty; only flip after phase-01 + 03 smoke runs.

## Security considerations
- No secrets committed in `application-local.yml` (defaults are dev-only).
- Docs mention never to commit `.env` or production datasource credentials.

## Next steps
- Next task: extend schema for `lessons` + `lesson_versions`, build admin authoring API, refactor Flutter mocks to consume `GET /api/v1/events`.
