# Phase 08 — Admin Tests + Docs + Final Verify

## Context Links

- Test infra: Vitest + React Testing Library + MSW — patterns trong `features/events/event-form.test.tsx`, `events-table.test.tsx`, `auth/login-form.test.tsx`.
- Docs: `docs/API_SPEC.md`, `docs/DATABASE_DESIGN.md`, `docs/project-changelog.md`.
- Build: `npm ci && npm run typecheck && npm run test && npm run build` trong `dau-viet-admin`.

## Overview

- Priority: P1
- Status: pending
- Effort: 2h
- Vitest cho cac component UI moi (gamification tab, dossier library, rule builder) + cap nhat docs + final verify toan bo.

## Requirements

### Vitest coverage

- `rule-ast.test.ts` — `formToAst`/`astToForm` cho tung leaf type, depth<=2, field rejection (da o Phase 06).
- `policy-editor.test.tsx` — render form, pick lessons, validate mock tra errors, publish confirm dialog.
- `dossier-link-table.test.tsx` — reorder/remove triggers mutation dung payload.
- `dossier-picker-dialog.test.tsx` — search + chon dossier.
- `dossiers-table.test.tsx` — filter type/status trigger query.
- `dossier-detail.test.tsx` — PUT payload dung, publish flow, 409 conflict hien error.
- `rule-builder.test.tsx` — them/xoa leaf, preview description tieng Viet, validate call.
- `reconcile-panel.test.tsx` — confirm dialog + result card render `itemsGranted/usersScanned/batches`.
- `scope-banner.test.tsx` — 3 scope render dung.

### MSW handlers

Them handlers moi vao `src/test/msw/handlers.ts` (hoac tuong duong):
- `GET /admin/events/:id/completion-policies`, `POST .../validate`, `POST .../publish`, `POST /admin/events/:id/completion-policies`, `PUT .../{policyId}`.
- `GET/POST /admin/dossiers`, `GET/PUT /admin/dossiers/:id`, `POST /admin/dossiers/:id/publish`, `POST /admin/dossiers/:id/archive`.
- `GET/PUT /admin/events/:id/dossiers`.
- `POST /admin/items/:id/rule/validate`, `GET /admin/items/:id/rule/history`.
- Fixtures: policy list, dossier list, rule history.

### Docs updates

- `docs/API_SPEC.md` — section "Admin Gamification (GAME-06)": tat ca endpoint + request/response example + error codes.
- `docs/DATABASE_DESIGN.md` — `historical_dossier_versions` schema + rationale; update `event_completion_policies` (thay doi mutability); `event_dossiers` (link replace semantics).
- `docs/project-changelog.md` — entry GAME-06.
- `docs/development-roadmap.md` — mark GAME-06 phase done (neu file nay ton tai).
- `docs/PROGRESS.md` — tu dong sinh tu task.json (khong sua tay).

### Final verify

- `cd dau-viet-backend && ./mvnw verify` — build + tests pass.
- `cd dau-viet-admin && npm ci && npm run typecheck && npm run test && npm run build` — sach.
- `git status` — khong file thua, khong .env, khong commit.
- `git diff --check` — whitespace clean.

## Implementation Steps

1. Viet Vitest cho tung component (uu tien `rule-ast` + `policy-editor` + `dossier-detail` — 3 cai quan trong nhat).
2. MSW handlers + fixtures.
3. Chay `npm run test` — fix.
4. Doc `docs/API_SPEC.md` hien tai -> append section GAME-06.
5. Doc `docs/DATABASE_DESIGN.md` -> them `historical_dossier_versions`.
6. Doc `docs/project-changelog.md` -> entry.
7. Final verify commands.

## Todo List

- [ ] Vitest cho cac component chinh.
- [ ] MSW handlers + fixtures.
- [ ] `API_SPEC.md` update.
- [ ] `DATABASE_DESIGN.md` update.
- [ ] `project-changelog.md` update.
- [ ] `development-roadmap.md` update (neu co).
- [ ] `./mvnw -pl dau-viet-backend verify` pass.
- [ ] `npm ci / typecheck / test / build` pass trong `dau-viet-admin`.
- [ ] `git status` clean.

## Success Criteria

- Coverage dat muc du (`rule-ast` >= 90%; cac component chinh co it nhat render + interaction test).
- Moi tests pass; khong co fake/skip de qua build.
- Docs dung version, links con hoat dong.

## Risk Assessment

- MSW fixture drift so voi backend -> doc DTOs that tu Phase 02/03 truoc khi viet fixtures.
- Docker cho Testcontainers backend IT — neu khong chay duoc, ghi ro vao changelog + bao user (khong giau).

## Security Considerations

- Khong commit `.env`, credentials, tokens.
- Changelog khong de lo internal IPs/users.

## Next Steps

- Handoff: bao cao summary cho user (tests pass, files da viet, khong commit).
