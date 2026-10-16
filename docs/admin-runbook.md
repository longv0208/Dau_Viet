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
- Refresh rotation is coordinated on both sides:
  - Client: `refresh-coordinator.ts` single-flights every call (bootstrap,
    401 retry, StrictMode remount) onto one in-flight Promise, and a
    `BroadcastChannel("dv-auth")` lets a second tab adopt the rotated token
    instead of rotating the same cookie again.
  - Server: `api/auth/refresh/route.ts` keeps a module-level map keyed by
    the presented token's SHA-256. Two requests carrying the same cookie
    await the same upstream rotate and each gets its own `Set-Cookie` —
    prevents the replay → `revokeFamily` forced logout.
- `middleware.ts` is a presence-only guard; role enforcement happens in
  `(admin)/layout.tsx` (server-side `/users/me` check) and again in the
  backend's `hasRole('CONTENT_ADMIN')` on `/api/v1/admin/**`.

## Tests

```
npm run test -- --run     # Vitest + RTL + MSW (jsdom)
npm run test:e2e          # Playwright + node:http stub backend
```

`test:e2e` spins up `scripts/e2e-backend-stub.mjs` on `:8081` and `next dev`
on `:3100`. The stub is a controlled `node:http` server that keeps a small
in-memory store for auth, `/admin/events`, `/admin/lessons`,
`PUT /admin/lessons/{id}/draft`, `POST /admin/lessons/{id}/validate` and
`/admin/lesson-templates` — it is not the real backend; it proves the
browser → BFF → backend wiring and the authoring flow (create event →
lesson wizard → save draft → reopen → build stages → save → reload)
end-to-end.

If Playwright browsers cannot be installed on a machine, the component-level
suite still covers login validation, dashboard rendering, table states and the
403 surface — but browser-level AC-10 evidence is then missing and must be
flagged in task evidence.

## Build & serve

```
npm run build
npm start
```

## Stage & Activity Builder (`/lessons/[id]/builder`)

Added in TASK-0015. A 3-pane workspace for authoring `draftJson` without
writing JSON:

- **Left — stage navigator**: ordered stage list, add (9 stage types), reorder
  up/down, duplicate (re-ids stage + activities, appends "(bản sao)"), delete
  with inline Xoá/Giữ confirm.
- **Center — stage editor**: title, stage type, required toggle, nextStageIds
  checkbox chips (empty = terminal stage), activity list with reorder/delete,
  "Thêm hoạt động" opens the type picker filtered by
  `STAGE_ALLOWED_ACTIVITIES` (READ is universal).
- **Right — inspector**: template seeding, completion editor, server-error
  panel (click-to-jump), publish-readiness card.

Save pipeline: the whole `Draft` document serializes to one
`PUT /admin/lessons/{id}/draft` with `expectedRowVersion`. Responses:

- `200` → clean state, `rowVersion` refreshed, cache invalidated.
- `422 DRAFT_SCHEMA_INVALID` → `details.errors[]` mapped into the validation
  panel; clicking an entry selects the failing stage/activity.
- `409 OPTIMISTIC_LOCK_CONFLICT` → banner prompts reload; never auto-retries.

Typed editors exist for READ, VIEW_IMAGE, MULTIPLE_CHOICE, EVIDENCE_SELECT,
MATCHING, DRAG_ORDER, CER, REFLECTION_PROMPT. The other four types
(EXPLORE_MAP, REASONING_CONNECT, HYPOTHESIS_CHOICE, VERIFICATION) render an
honest read-only fallback — the raw config is preserved on save via the
spread-through codec; they are never silently rewritten. Evidence/asset id
fields are free-text UUID inputs until the pickers land in TASK-0016.

Server-only keys (correctOptionIds, correctPairs, expectedOrder,
requiredEvidenceIds) are emitted by the visual arrangement — MC option
marking, DRAG_ORDER list order, MATCHING pair pairing — and labelled as not
shown to learners.

Template seeding ("Tạo cấu trúc từ khung bài học") parses the template's
`presetJson`, regenerates every stage/activity id (slug pattern
`^[a-z0-9][a-z0-9-]{1,63}$`, NOT UUIDs), remaps internal `nextStageIds`, and
appends after an explicit confirm — it never replaces existing stages.

Status semantics: `PUBLISHED` shows a banner (edits go to a new draft; the
published snapshot is immutable), `ARCHIVED` renders the whole builder
read-only. Unsaved-changes guard warns on in-app navigation and tab close.



- The real-backend smoke test (CONTENT_ADMIN login, reload, logout,
  LEARNER-denied, expired-token recovery, refresh rotation) has NOT been run
  on this machine — Docker daemon is stopped, the `postgresql-x64-18`
  service has an incomplete install (`lib/` missing), and no other Postgres
  instance is reachable. The stub-backed Playwright suite is the closest
  current evidence; a real-backend pass remains a follow-up gate before any
  production sign-off.
- No CSRF token yet — acceptable behind `SameSite=Lax`, but hardening is a
  follow-up before any state-changing public surface.
- Authoring scope after TASK-0015: `/events` list + search + status filter,
  `/events/new` + `/events/[id]` create/edit (slug auto-suggest, tags, unsaved
  guard, optimistic-lock via `expectedRowVersion`); `/lessons` list +
  event/status filters, `/lessons/new` 4-step wizard (event → template →
  basic info → confirm), `/lessons/[id]` basic editor (title, central
  question, objectives list; PATCHes `expectedRowVersion`),
  `/lessons/[id]/builder` visual Stage & Activity Builder (see section
  above). Media upload, evidence catalogue pickers and publish UI remain out
  of scope — see `design/ADMIN_SCREEN_DESIGN.md` for the roadmap.
- `Secure` is only added to the cookie in production — dev runs on plain
  `http://localhost`.
- `sort=updatedAt,desc` is whitelisted on both `/admin/events` and
  `/admin/lessons`; the dashboard "recent lessons" card relies on it.
