# Phase 06 — CI + docs + harness registration (AC-11, AC-12)

## Overview
- Priority: P1 · Status: pending · Effort: ~2h
- Add `.github/workflows/admin-ci.yml`, `docs/admin-runbook.md`, activate admin module in `.harness/config.json`, finalize `tasks/TASK-0013/task.json` evidence.

## Files to create / modify

```
.github/workflows/admin-ci.yml       NEW
docs/admin-runbook.md                NEW
dau-viet-admin/.env.example          (Phase 01; re-verify no secrets)
dau-viet-admin/README.md             NEW — quick-start pointing at runbook
.harness/config.json                 EDIT — admin module active + gates
tasks/TASK-0013/task.json            EDIT — planPath, evidenceRefs, status transitions
docs/API_SPEC.md                     EDIT — append "Admin client implementation note" linking runbook (minor)
docs/PROJECT_OVERVIEW.md             EDIT — note admin module bootstrapped (one line)
docs/development-roadmap.md          EDIT (if exists) — progress entry
docs/project-changelog.md            EDIT — changelog entry
```

## `.github/workflows/admin-ci.yml`

```yaml
name: admin-ci

on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - "dau-viet-admin/**"
      - ".github/workflows/admin-ci.yml"
  push:
    branches: [main]
    paths: ["dau-viet-admin/**"]
  workflow_dispatch:

permissions: { contents: read }

concurrency:
  group: admin-ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify:
    name: admin verify (Node 22)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    defaults:
      run: { working-directory: dau-viet-admin }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: dau-viet-admin/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run test -- --run
      - run: npm run build
      - name: Playwright E2E (chromium)
        run: npx playwright install --with-deps chromium && npm run test:e2e
      - name: Upload test reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: admin-test-reports-${{ github.run_id }}
          path: |
            dau-viet-admin/test-results/
            dau-viet-admin/playwright-report/
            dau-viet-admin/coverage/
          if-no-files-found: ignore
          retention-days: 14
```

Paths filter ensures backend CI is unaffected.

## `docs/admin-runbook.md` sections

1. **Prerequisites** — Node 22, npm 10.9+, backend running on `:8080` (`local` profile for seeded admin).
2. **Install** — `cd dau-viet-admin; npm ci`.
3. **Env vars** — `BACKEND_URL` (server-only, default `http://localhost:8080`); note `NEXT_PUBLIC_*` is NOT used for backend (BFF keeps it server-side).
4. **Dev** — `npm run dev` → `:3000`; backend `local` profile seeds `ADMIN_EMAIL`/`ADMIN_PASSWORD`.
5. **Auth flow** — diagram of BFF: browser → `/api/auth/login` → backend → Set-Cookie `dv_refresh` HttpOnly; subsequent requests via `/api/proxy/*` with `Authorization: Bearer <access>`; refresh on expiry or reload; logout revokes.
6. **Tests** — `npm run test`, `npm run test:e2e`; **explicit statement** if Playwright unavailable + which spec is the component-level fallback.
7. **Build** — `npm run build && npm start`.
8. **Known limitations** — refresh-token race across tabs (mitigated by single-flight), CSRF hardening TODO, module CRUD pending, no i18n library, dev-mode `Secure` cookie flag off.
9. **Remaining modules** — link to `design/ADMIN_SCREEN_DESIGN.md` for the Lesson Builder roadmap.

## `.harness/config.json` edit

```jsonc
"admin": {
  "path": "dau-viet-admin",
  "status": "active",
  "manifests": ["package.json", "package-lock.json", "next.config.mjs", "tsconfig.json"],
  "gates": [
    { "id":"admin-install",  "executable":"cmd.exe", "args":["/c","npm ci"],                  "cwd":"dau-viet-admin", "timeoutSeconds":300 },
    { "id":"admin-lint",     "executable":"cmd.exe", "args":["/c","npm run lint"],            "cwd":"dau-viet-admin", "timeoutSeconds":180 },
    { "id":"admin-typecheck","executable":"cmd.exe", "args":["/c","npm run typecheck"],       "cwd":"dau-viet-admin", "timeoutSeconds":180 },
    { "id":"admin-test",     "executable":"cmd.exe", "args":["/c","npm run test -- --run"],   "cwd":"dau-viet-admin", "timeoutSeconds":300 },
    { "id":"admin-build",    "executable":"cmd.exe", "args":["/c","npm run build"],           "cwd":"dau-viet-admin", "timeoutSeconds":600 }
  ]
}
```

No `Invoke-Expression`, no shell strings — `args` arrays only per AGENT_WORKFLOW.md.

## `tasks/TASK-0013/task.json` updates

- `status`: `draft` → `ready` → `implementing` → `verifying` → `reviewing` → `done` (driven by harness `start`/`verify`/`finish`).
- `planPath`: `plans/261016-0530-task0013-admin-foundation/plan.md`.
- `evidenceRefs`: appended by `harness verify` — paths to `.harness/runs/TASK-0013/evidence-verify-*.json`.
- `nextAction`/`handoffRef` updated on transitions.

## Success criteria

- `pwsh -File scripts/harness/harness.ps1 verify -TaskId TASK-0013` runs admin gates green (or honest failure note if `pwsh` missing — see HARNESS_RUNBOOK §Setup; do not mark N/A to bypass).
- `admin-ci.yml` present, syntactically valid (`actionlint` optional; CI run on next push proves).
- `docs/admin-runbook.md` complete; no secrets in `.env.example` or repo.
- Independent review by `code-reviewer` agent — no P0/P1 blockers.

## Risks

- `pwsh` missing on this machine — harness `verify` will fail the `harness-self-test` gate. Document honestly; do not fake.
- First `npm ci` in CI slower than local — timeout-minutes: 15 should be sufficient for a fresh Next.js project.
- `package-lock.json` must be committed; `.npmrc` not required.
