---
title: "TASK-0013 — Next.js Admin CMS Foundation"
description: "Bootstrap dau-viet-admin: real auth vs /api/v1/auth, BFF session, admin shell + dashboard + module shells, typed API client, tests, CI, harness registration."
status: verifying
priority: P1
effort: 14h
branch: main
tags: [admin, nextjs, auth, bff, bootstrap, high-risk]
created: 2026-10-16
---

# TASK-0013 — dau-viet-admin foundation

**Source of truth:** `tasks/TASK-0013/task.json` AC-1..AC-12.
**Risk:** high-risk (auth, session, role-based authorization).
**Module:** `dau-viet-admin/` — new; activated in `.harness/config.json` end of task.
**Out of scope:** Lesson Builder wizard, stage/activity editors, asset upload, publish UI. Those land in later tasks; this task ships the shell + honest placeholders.

## Architecture decisions

### D1 — Session model: Next.js Route Handler BFF with HttpOnly refresh cookie

The backend returns `{accessToken, refreshToken}` in JSON. The browser must never hold the raw refresh token. Chosen design (KISS, no extra state):

- Browser talks only to same-origin BFF routes under `/api/auth/*` hosted by `dau-viet-admin`.
- `POST /api/auth/login` (Route Handler): server-side `fetch` to `${BACKEND_URL}/api/v1/auth/login` with `{email,password}`. On 200, set refresh token in `Set-Cookie: dv_refresh=<token>; HttpOnly; Secure; SameSite=Lax; Path=/api/auth; Max-Age=<refreshExpiresIn>` and return only `{accessToken, expiresIn, user}` to the client.
- `POST /api/auth/refresh`: reads `dv_refresh` cookie, calls backend `/api/v1/auth/refresh`, on 200 rotates the cookie and returns a fresh `{accessToken, expiresIn}`.
- `POST /api/auth/logout`: reads cookie, calls backend `/api/v1/auth/logout`, always clears cookie (idempotent).
- `GET /api/auth/session`: returns `{user}` if a valid refresh cookie exists — used by middleware/layout to restore session after reload without exposing the refresh token.
- **Access token:** kept in React memory only (`AuthProvider` + TanStack Query context). Never persisted to localStorage / sessionStorage / cookies. On reload, client silently calls `/api/auth/refresh` to get a fresh access token before rendering protected pages (or first query triggers refresh on 401).
- **Redirect validation:** `?next=` query param on `/login` must be a same-origin path starting with `/` and not `//`. Anything else falls back to `/dashboard`.
- **Why not "tokens server-side only"?** Storing access token server-side would require a session store (Redis/DB). HttpOnly cookie for refresh + in-memory access token is the smallest design that satisfies AC-3. Backend access TTL is only 900s anyway, so a stolen in-memory access token has small blast radius.
- **CORS note:** Because the browser only calls same-origin `/api/*` BFF routes, backend CORS is irrelevant for the admin app — the BFF calls backend server-to-server. `app.cors.allowed-origins` `http://localhost:3000` remains valid for any direct probes but is not required by this design. `Secure` flag on cookie is conditionally dropped in dev (`process.env.NODE_ENV !== 'production'` allows non-HTTPS localhost) — documented.

### D2 — Auth/role enforcement (defense in depth)

- **Server:** `/api/v1/admin/**` requires `ROLE_CONTENT_ADMIN` (already enforced — verified `SecurityConfig.java:72`). Backend remains authoritative.
- **Middleware (Next.js `middleware.ts`):** for any protected matcher, only check that the `dv_refresh` cookie exists — do not verify JWT in middleware (it lives on the backend). Redirect to `/login?next=<path>` when missing. Login page itself is excluded.
- **Layout guard (Server Component in `app/(admin)/layout.tsx`):** calls `GET /api/v1/users/me` through the BFF using the access token obtained from `/api/auth/refresh`. If `role !== 'CONTENT_ADMIN'` → render forbidden state (403 page, "Tài khoản không có quyền quản trị"). If 401 → redirect `/login`. This gives learner-denied UX while backend still enforces.
- **BFF routes** under `/api/proxy/*` forward to backend with `Authorization: Bearer <access>` taken from a short-lived, memory-only cookie (or, simpler: BFF does refresh → attach access token). Chosen simplest: BFF `/api/proxy/[...path]` route reads `dv_refresh` cookie, calls `/auth/refresh` if no cached access token, attaches `Authorization` header, forwards request, streams response. Pro: browser never touches backend, never sees refresh token; access token lives only in BFF memory cache keyed by refresh-token hash. Con: adds one extra refresh call per token expiry; acceptable.

Actually, simpler still and still satisfying AC-3 (KISS): keep access token in **client memory** after `/api/auth/login`/`refresh` returns it. Client `fetch` calls `/api/proxy/*` which is just a thin forwarder that expects the client to send `Authorization: Bearer <token>` to the BFF — BFF then forwards to backend unchanged. Refresh-token security goal is met (it never leaves the cookie). This avoids BFF-side token cache.

**Final session flow:**

1. Login form → `POST /api/auth/login` → sets `dv_refresh` cookie, returns `{accessToken, expiresIn, user}`.
2. Client stores `{accessToken, expiresAt}` in a React ref/context; TanStack Query `fetcher` attaches `Authorization` header.
3. Data requests go to `/api/proxy/<backend-path>` — BFF strips prefix, forwards `Authorization`, returns upstream response. (Alternative accepted: client calls backend directly with `NEXT_PUBLIC_API_BASE_URL`; the BFF-proxy path is preferred because it keeps a single origin and simplifies future cookies/CSRF — pick one in phase 2 and stick with it. Default = BFF proxy.)
4. On 401 response, client calls `POST /api/auth/refresh` once (single-flight), retries query, or redirects to login on failure.
5. On reload, `useEffect` calls `/api/auth/refresh` to rehydrate access token.

### D3 — Stack & versions (pinned, lockfile committed)

| Dep | Version | Reason |
|---|---|---|
| next | `15.1.x` | Stable, App Router mature, React 19 supported. |
| react / react-dom | `19.0.x` | Pairs with Next 15. |
| typescript | `^5.6` | Strict mode required by AC-1. |
| tailwindcss | `^3.4.x` | Tailwind 4 changes config model (CSS-first); 3.4 + `tailwind.config.ts` is the documented shadcn path — KISS. |
| shadcn/ui | latest CLI, Radix primitives | Component source vendored into `src/components/ui/`. |
| @tanstack/react-query | `^5.x` | De-facto server-state. |
| react-hook-form | `^7.x` | Forms. |
| zod | `^3.x` | Form + env validation. |
| lucide-react | latest | Icons. |
| vitest | `^2.x` | jsdom unit/component tests. |
| @testing-library/react + user-event | latest | Component testing. |
| msw | `^2.x` | Mock backend at network level for component tests. |
| playwright | `^1.4x` | One browser-level test if `npx playwright install --with-deps chromium` succeeds; otherwise fall back to an MSW-backed "browser-like" test using `next dev` + `page` object via Playwright headed=false (still Playwright) OR honest jsdom-based "navigates login → dashboard" test labeled as component-level. Decide after `npx playwright install chromium` attempt in Phase 5. |

**Out:** state managers beyond React Query/Context, NextAuth/Auth.js (would conflict with backend refresh rotation and adds a layer we don't need), Tailwind 4, app-level i18n library (Vietnamese hardcoded per CODING_RULES — code identifiers English, UI labels Vietnamese).

### D4 — Directory layout

Feature-oriented under `src/` (mirrors backend `api/application/domain` discipline at frontend scale):

```
dau-viet-admin/
├── .env.example                  # BACKEND_URL, NEXT_PUBLIC_*; no secrets
├── .env.local                    # gitignored
├── .eslintrc.cjs                 # or eslint.config.mjs flat
├── .gitignore
├── next.config.mjs
├── package.json                  # pinned deps, lockfile committed
├── postcss.config.mjs
├── tailwind.config.ts
├── tsconfig.json                 # strict, paths @/* -> src/*
├── playwright.config.ts          # if used
├── vitest.config.ts
├── vitest.setup.ts
├── src/
│   ├── env.ts                    # zod-validated env (BACKEND_URL etc.)
│   ├── middleware.ts             # cookie-presence redirect guard
│   ├── app/
│   │   ├── layout.tsx            # root: fonts (Be Vietnam Pro, Noto Serif), providers
│   │   ├── page.tsx              # redirect / -> /dashboard
│   │   ├── globals.css           # tailwind + design tokens (CSS vars from ART_DIRECTION)
│   │   ├── login/page.tsx        # A-01
│   │   ├── (admin)/
│   │   │   ├── layout.tsx        # AdminShell + role guard
│   │   │   ├── dashboard/page.tsx        # A-02
│   │   │   ├── events/page.tsx           # shell: DataTable wired to real list API
│   │   │   ├── lessons/page.tsx          # shell: DataTable wired
│   │   │   ├── templates/page.tsx        # shell: read-only list
│   │   │   ├── assets/page.tsx           # coming-soon stub
│   │   │   ├── versions/page.tsx         # shell placeholder (list versions requires lessonId — link from lessons later)
│   │   │   ├── error.tsx                 # error boundary
│   │   │   ├── forbidden.tsx             # 403
│   │   │   └── not-found.tsx             # 404
│   │   └── api/
│   │       ├── auth/login/route.ts
│   │       ├── auth/refresh/route.ts
│   │       ├── auth/logout/route.ts
│   │       ├── auth/session/route.ts
│   │       └── proxy/[...path]/route.ts  # forwarder to BACKEND_URL
│   ├── components/
│   │   ├── ui/                   # shadcn vendored primitives
│   │   ├── admin-shell.tsx       # A-C01
│   │   ├── page-header.tsx       # A-C02
│   │   ├── data-table.tsx        # A-C03 minimal (no sorting libs)
│   │   ├── status-chip.tsx       # A-C04
│   │   ├── empty-state.tsx
│   │   ├── error-state.tsx
│   │   ├── confirm-dialog.tsx
│   │   ├── skeleton.tsx
│   │   ├── breadcrumbs.tsx
│   │   └── toast.tsx             # sonner or radix toast — pick one (default sonner)
│   ├── features/
│   │   ├── auth/                 # login form (RHF+zod), AuthProvider, useAccessToken, useLogout
│   │   ├── dashboard/            # welcome, quick-nav cards, admin ping probe
│   │   ├── events/               # list query + columns
│   │   ├── lessons/              # list query + columns
│   │   ├── templates/            # list query
│   │   └── forbidden/            # learner-denied view
│   ├── lib/
│   │   ├── api-client.ts         # typed fetcher, error mapping, query keys
│   │   ├── api-error.ts          # ApiError envelope type + parse
│   │   ├── dto/                  # mirrors backend DTOs (auth, user, event, lesson, template, page)
│   │   ├── pagination.ts
│   │   ├── query-keys.ts         # single source of queryKey builders
│   │   └── utils.ts              # cn() etc.
│   └── test/
│       ├── msw/handlers.ts       # default backend stubs
│       ├── msw/server.ts
│       └── fixtures.ts
└── tests/
    ├── unit/                     # *.test.ts(x)
    └── e2e/login.spec.ts         # playwright — only if installable
```

**File-size rule:** keep each file ≤ 200 lines per `development-rules.md`; split `data-table`, `admin-shell`, feature page if approaching the limit.

### D5 — Typed API layer

- `api-client.ts` exposes `apiFetch<T>(path, init)` — base URL `${origin}/api/proxy`, JSON body, attaches `Authorization` from auth store, parses `ApiError` envelope into a typed `ApiClientError` (`status`, `code`, `message`, `details`, `traceId`). No `any`, no `as` without a comment.
- DTOs in `lib/dto/` mirror backend records exactly: `TokenResponse`, `UserProfileDto`, `PageResponse<T>`, `AdminEventSummaryResponse`, `AdminLessonSummaryResponse`, `LessonTemplateResponse`, `ApiError`. Camel-case fields as backend serializes.
- `query-keys.ts` exports namespaced builders: `qk.events.list(params)`, `qk.lessons.list(params)`, `qk.templates.list()`, `qk.admin.ping()` — prevents key drift.
- **Do not invent endpoints.** Only wire what exists: `/auth/*`, `/users/me`, `/admin/ping`, `/admin/events`, `/admin/lessons`, `/admin/lesson-templates`, `/admin/evidences` (list-only used this task). Mutations arrive in later tasks — pages render honest "Sắp ra mắt" (coming soon) cards for them.

### D6 — Dashboard honesty

A-02 shows:
- Welcome header with admin `displayName` + `role` (from `/users/me` via TanStack Query `staleTime: 60s`).
- Quick-nav cards to `/events`, `/lessons`, `/templates`, `/assets`, `/versions`.
- Backend status card using `GET /admin/ping` (one real endpoint, honest "Kết nối backend: OK / lỗi").
- Recent drafts list: call `GET /admin/lessons?size=5&sort=updatedAt,desc` — if the backend supports that sort, render it; else render honest "—" placeholder. **No fabricated metrics.**

### D7 — Testing

- **Unit/component (Vitest + jsdom + RTL + MSW):**
  - Login form: required-field errors (Vietnamese), invalid email, submit disabled while pending.
  - Login flow: success sets cookie (assert BFF `Set-Cookie` on MSW response — or, more honest, assert MSW hit + access token in store), invalid creds shows `INVALID_CREDENTIALS` message, refresh rotation calls `/auth/refresh`, logout posts to `/auth/logout` and clears state.
  - Auth guard: unauthenticated `/dashboard` → redirect to `/login`; learner role → forbidden view.
  - `api-client`: maps 401/403/404/422/500 → typed error with `code`/`traceId`.
  - Layout: sidebar renders nav items, collapsible on click, mobile hides sidebar below `md`.
  - DataTable: renders rows from fixture PageResponse; empty state.
- **Browser-level (AC-10):** One Playwright test `login.spec.ts` — starts `next dev` with `BACKEND_URL=http://localhost:NNNN` pointing at a stub MSW-style server (use `msw` `NodeHttpServer` or a small `node:http` stub that returns canned `TokenResponse` + `UserProfileDto`), opens `/login`, fills form, submits, asserts navigation to `/dashboard` and "Xin chào, <displayName>" visible. If Playwright browsers cannot be installed on this machine, document the limitation honestly in `docs/admin-runbook.md` and substitute a `vitest` "integration" spec that mounts `<LoginPage>` → `<AdminLayout>` → `<Dashboard>` against MSW — labeled as component-level, NOT E2E.

### D8 — CI (`.github/workflows/admin-ci.yml`)

Mirror backend-ci.yml shape:

```yaml
name: admin-ci
on:
  pull_request: { paths: ["dau-viet-admin/**", ".github/workflows/admin-ci.yml"] }
  push: { branches: [main], paths: ["dau-viet-admin/**"] }
  workflow_dispatch:
permissions: { contents: read }
concurrency: { group: admin-ci-${{ github.ref }}, cancel-in-progress: true }
jobs:
  verify:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: dau-viet-admin } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22", cache: npm, cache-dependency-path: dau-viet-admin/package-lock.json }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run test -- --run
      - run: npm run build
      - name: E2E (playwright, optional)
        run: npx playwright install --with-deps chromium && npm run test:e2e
        continue-on-error: false   # set true ONLY if env cannot support browsers; prefer real
```

### D9 — Harness registration

`.harness/config.json` admin module → `active` with gates:

```json
{
  "id": "admin-install", "executable": "cmd.exe",
  "args": ["/c", "npm ci"], "cwd": "dau-viet-admin", "timeoutSeconds": 300
},
{ "id": "admin-lint",      "args": ["/c","npm run lint"],       ... },
{ "id": "admin-typecheck", "args": ["/c","npm run typecheck"],  ... },
{ "id": "admin-test",      "args": ["/c","npm run test -- --run"], ... },
{ "id": "admin-build",     "args": ["/c","npm run build"],      "timeoutSeconds": 600 }
```

Manifests: `package.json`, `package-lock.json`, `next.config.mjs`, `tsconfig.json`.

## Phase map (details in `phase-XX-*.md`)

| Phase | File | Effort | AC |
|---|---|---|---|
| 01 — Bootstrap & tooling | `phase-01-bootstrap.md` | 2h | AC-1 |
| 02 — Auth BFF + API client | `phase-02-auth-and-api.md` | 3h | AC-2, AC-3, AC-8 |
| 03 — Design system + AdminShell | `phase-03-design-system-shell.md` | 2.5h | AC-5, AC-7 (partially) |
| 04 — Pages (Login, Dashboard, module shells) | `phase-04-pages.md` | 2.5h | AC-4, AC-5, AC-6, AC-9 |
| 05 — Tests | `phase-05-tests.md` | 2h | AC-10 |
| 06 — CI + docs + harness | `phase-06-ci-docs-harness.md` | 2h | AC-11, AC-12 |

Sequenced strictly — D2 relies on D1 BFF existing; pages rely on shell; tests rely on pages.

## Risks / assumptions / open questions

- **ASSUMPTION-1:** Playwright browsers may not install on this Windows box (no pwsh, proxy, etc.). If `npx playwright install chromium` fails twice, fall back to an honestly-labeled "browser-like" Vitest+MSW integration spec; document in runbook. AC-10 explicitly allows mocked backend but requires "at least one browser-level test" — the fallback is component-level which does not fully satisfy AC-10; flag this honestly in evidence.
- **ASSUMPTION-2:** Backend `updatedAt,desc` sort on `/admin/lessons` may not be supported (check `AdminLessonController` sort whitelist). Dashboard "recent drafts" falls back to `size=5` default order. Verified during Phase 4.
- **ASSUMPTION-3:** `Secure` cookie flag disabled under dev (`NODE_ENV !== 'production'`) because localhost is HTTP. Documented in runbook.
- **ASSUMPTION-4:** BFF proxy approach chosen over direct browser→backend calls — both satisfy AC-3; proxy is simpler for future CSRF/cookie consolidation and keeps a single origin. If implementer prefers direct calls, that is acceptable — must keep refresh token out of browser regardless.
- **ASSUMPTION-5:** No i18n library — Vietnamese labels hardcoded per coding rules; translations outside scope.
- **OPEN-Q-1:** `?next=` deep-link on `/login` — only same-origin paths accepted; do we need to preserve query strings on redirect? (Default yes, allowlist paths starting `/`.)
- **OPEN-Q-2:** Does `GET /admin/lessons` support `sort=updatedAt,desc`? Verify at Phase 4; if not, use default order.
- **OPEN-Q-3:** Should `/versions` page exist standalone (cross-lesson version history isn't in API_SPEC — versions are per-lesson)? Default: render "chọn lesson để xem phiên bản" empty state — honest, no fabricated list.

## Definition of done

- `npm ci && npm run lint && npm run typecheck && npm run test -- --run && npm run build` all exit 0 inside `dau-viet-admin/`.
- Manual smoke: backend `local` profile running, `ADMIN_EMAIL`/`ADMIN_PASSWORD` seeded; login → dashboard renders; reload → session restored; logout clears.
- `.github/workflows/admin-ci.yml` defined.
- `.harness/config.json` admin module `active` with the four gates registered and `pwsh scripts/harness/harness.ps1 verify -TaskId TASK-0013` passes (or honest failure on `harness-self-test` if `pwsh` still missing — see HARNESS_RUNBOOK).
- `docs/admin-runbook.md` covers install/env/dev/test/build/auth flow/limitations.
- `tasks/TASK-0013/task.json` `planPath` updated to this plan; evidence appended after runs.

## Unresolved questions (for product)

None blocking. OPEN-Q-1..3 above are implementation-detail level and resolved by defaults in the relevant phase file.
