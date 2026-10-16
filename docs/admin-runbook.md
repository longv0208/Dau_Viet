# Admin runbook — dau-viet-admin

Next.js 15 App Router CMS for content administration against the `dau-viet-backend` `/api/v1` surface.

## Prerequisites

- Node.js 22.x (engine floor `>=20.9.0`)
- npm 10.9+
- `dau-viet-backend` running on `:8080` with the `local` profile so the seeded
  `ADMIN_EMAIL`/`ADMIN_PASSWORD` account exists.

## Install

```
cd dau-viet-admin
npm ci
```

## Environment

Copy `.env.example` to `.env.local`. Only one variable matters:

- `BACKEND_URL` — server-side only, defaults to `http://localhost:8080`.
  The browser never sees this value; all backend traffic goes through the
  BFF route handlers, so no `NEXT_PUBLIC_*` backend URL exists by design.

## Dev

```
npm run dev
# → http://localhost:3000
```

Log in with the seeded admin (default `admin@dauviet.local` / the password
from `ADMIN_PASSWORD` in the backend env). A `LEARNER` account reaches the
403 page instead of the shell.

## Auth flow (BFF)

```
browser ──POST /api/auth/login──► Next route handler ──► backend /api/v1/auth/login
        ◄── {accessToken, expiresIn} + Set-Cookie dv_refresh (HttpOnly) ──

browser ──GET /api/proxy/admin/*──► route handler ──► backend /api/v1/admin/*
        (Authorization: Bearer <accessToken>, in-memory only)

accessToken expires ──► POST /api/auth/refresh (dv_refresh cookie) ──► rotated pair
logout ──► POST /api/auth/logout ──► revoke + clear cookie
```

- The refresh token never reaches browser JS — it lives only in the
  `dv_refresh` HttpOnly cookie (`Path=/`, `SameSite=Lax`, `Secure` in prod).
- The access token lives in module memory only (`authStore`), never in
  `localStorage`/cookies. Reloading rehydrates via `/api/auth/session`.
- `middleware.ts` is a presence-only guard; role enforcement happens in
  `(admin)/layout.tsx` (server-side `/users/me` check) and again in the
  backend's `hasRole('CONTENT_ADMIN')` on `/api/v1/admin/**`.

## Tests

```
npm run test -- --run     # Vitest + RTL + MSW (jsdom)
npm run test:e2e          # Playwright + node:http stub backend
```

`test:e2e` spins up `scripts/e2e-backend-stub.mjs` on `:8081` and `next dev`
on `:3100`. The stub is a controlled `node:http` server returning canned
`TokenResponse`/`UserProfileDto` — it is not the real backend; it only proves
the browser → BFF → backend wiring end-to-end.

If Playwright browsers cannot be installed on a machine, the component-level
suite still covers login validation, dashboard rendering, table states and the
403 surface — but browser-level AC-10 evidence is then missing and must be
flagged in task evidence.

## Build & serve

```
npm run build
npm start
```

## Known limitations

- Refresh-token rotation is single-flight in the client; a hard reload racing
  a background refresh can still surface a 401 before the cookie settles.
- No CSRF token yet — acceptable behind `SameSite=Lax`, but hardening is a
  follow-up before any state-changing public surface.
- Module pages (`/events`, `/lessons`, …) are list shells only; create/edit
  forms, media upload and the Lesson Builder are out of scope for the
  foundation task. See `design/ADMIN_SCREEN_DESIGN.md` for the roadmap.
- `Secure` is only added to the cookie in production — dev runs on plain
  `http://localhost`.
- `sort=updatedAt,desc` is whitelisted on both `/admin/events` and
  `/admin/lessons`; the dashboard "recent lessons" card relies on it.
