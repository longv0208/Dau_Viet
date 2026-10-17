# Phase 05 — Verify & report

## Context Links

- Plan root: `plans/261017-1630-critical-content-preview-bugfix/`
- Reports: `plans/reports/`
- Backend: `dau-viet-backend/` (Maven `./mvnw`)
- Admin: `dau-viet-admin/` (`npm`, `npx vitest`, `npx playwright`)

## Overview

- Priority: P1
- Status: pending
- Run all verification gates, note environment limitations, write Vietnamese completion report.

## Key Insights

- Docker unavailable locally → Testcontainers ITs cannot run. All coverage relies on unit tests + stub e2e.
- `task.json` for this work item lives in `tasks/<id>/task.json` — update status to reflect completion phase if the harness requires it.
- Report goes to `plans/reports/` in Vietnamese, named `planner-{date}-critical-content-preview-bugfix.md` or follow existing report naming in `plans/reports/`.

## Requirements

- All unit + e2e checks green.
- IT absence documented as environmental (Docker), not a failure.
- Report written in Vietnamese to `plans/reports/`.

## Implementation Steps

1. Backend unit tests:
   ```
   cd dau-viet-backend && ./mvnw test -Dtest=LearnerProjectionServiceTest,ScoredHandlersTest
   ```
   Then full unit suite:
   ```
   ./mvnw test
   ```
   Note any IT classes that fail due to missing Docker — record as environmental, not code failure.
2. Admin checks (from `dau-viet-admin/`):
   ```
   npx tsc --noEmit
   npm run lint
   npx vitest run
   npm run build
   npx playwright test --workers=1
   ```
3. `git diff --check` — no whitespace errors.
4. Write report to `plans/reports/` in Vietnamese:
   - Summary of what was fixed per DoD item.
   - Commands run + results.
   - IT limitation note (Docker unavailable).
   - Any unresolved issues.
5. Update `tasks/<id>/task.json` status if applicable.

## Todo List

- [ ] `./mvnw test` backend green (unit only; IT noted)
- [ ] `npx tsc --noEmit` clean
- [ ] `npm run lint` clean
- [ ] `npx vitest run` green
- [ ] `npm run build` clean
- [ ] `npx playwright test --workers=1` green
- [ ] `git diff --check` clean
- [ ] Report written to `plans/reports/` (Vietnamese)

## Success Criteria

- All runnable checks pass.
- Report exists and covers all 11 DoD items.

## Risk Assessment

- Playwright e2e may be slow/flaky on first run — retry once before declaring failure.
- Backend IT classes (Testcontainers) will fail without Docker — exclude with `-Dtest='!*IT'` if needed; document in report.

## Next Steps

- Report back to lead with plan path + summary.
