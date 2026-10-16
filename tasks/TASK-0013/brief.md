# TASK-0013: Next.js Admin CMS Foundation

## Goal

Bootstrap `dau-viet-admin` — the Next.js + TypeScript admin web app for Content Admins — with real authentication against the existing Spring Boot `/api/v1/auth` contract, a reusable admin shell (sidebar, header, breadcrumbs), the A-01 Login and A-02 Dashboard screens, honest module entry pages, a typed API layer, a Vietnamese design system, automated tests, CI coverage and harness registration.

The full Lesson Builder wizard, stage/activity editors, media upload and publishing UI are explicitly out of scope for this task.

## Requirements and acceptance criteria

Mirrored in `task.json` (AC-1..AC-12). Highlights:

- App Router + strict TypeScript + Tailwind + shadcn/ui + TanStack Query + RHF/Zod; pinned lockfile; ESLint/typecheck/env validation/aliases.
- Real login against `POST /api/v1/auth/login`; `TokenResponse{accessToken, tokenType, expiresIn, refreshToken, refreshExpiresIn}`; refresh rotation via `POST /api/v1/auth/refresh`; `POST /api/v1/auth/logout` revokes the refresh token server-side.
- Refresh token never in `localStorage` — prefer HttpOnly cookie / server-side BFF session. Access token short-lived (backend TTL 900s).
- `/api/v1/admin/**` requires `ROLE_CONTENT_ADMIN` server-side; learner JWT must be denied, unauthenticated users redirected to `/login`.
- Admin shell per `design/ADMIN_SCREEN_DESIGN.md`: sidebar, top nav, breadcrumbs, admin identity, logout, collapsible sidebar, mobile nav, error boundaries, 404/403 states.
- Dashboard must not fabricate metrics; only backend-supported data (e.g. `GET /api/v1/admin/ping`) or navigation.
- Typed API client mirroring backend DTOs + `docs/API_SPEC.md`; standardized `ApiError{code,message,details,traceId}` parsing.
- Entry page shells: `/events`, `/lessons`, `/assets`, `/templates`, `/versions` (honest coming-soon where unimplemented).
- Tests: unit/component + at least one browser-level Login -> Dashboard against a mocked backend; mocked tests labeled as such.
- CI job (`.github/workflows/admin-ci.yml`): install, lint, typecheck, test, build — must not break `backend-ci.yml`.
- `docs/admin-runbook.md`, `.env.example`, `.harness/config.json` admin -> active with real gates.

## Scope

- `dau-viet-admin/` (new module), `tasks/TASK-0013/`, `docs/API_SPEC.md`, `docs/admin-runbook.md`, `.harness/config.json`, `.github/workflows/admin-ci.yml`, `plans/`.
- Do NOT modify completed TASK-0007..0012 backend code unless a verified integration blocker exists.

## Constraints and risk

High-risk: authentication, session/token handling, role-based authorization. Backend contracts are fixed — do not invent endpoints or fields. Backend already has: login/refresh/logout DTOs, `UserProfileDto` via `GET /api/v1/users/me`, `GET /api/v1/admin/ping` (CONTENT_ADMIN probe), CORS allowing `http://localhost:3000`, dev admin seed via `ADMIN_EMAIL`/`ADMIN_PASSWORD` under `local` profile.

## Plan

`plans/` — to be created by the planner agent before implementation.

## Verification mapping

| AC | Check | Expected outcome | Evidence artifact |
|---|---|---|---|
| AC-1..12 | npm install/lint/typecheck/test/build, browser test, CI definition, harness gates | All commands exit 0; tests green | Fill after runs |

## Handoff

To be filled on completion.
