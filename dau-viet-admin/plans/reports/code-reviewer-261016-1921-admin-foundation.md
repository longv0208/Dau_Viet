---
title: "Independent code review — TASK-0013 admin foundation"
date: 2026-10-16
reviewer: code-reviewer
task: TASK-0013
scope: dau-viet-admin (entire new module)
plan: plans/261016-0530-task0013-admin-foundation/plan.md
---

# Code review — TASK-0013 dau-viet-admin foundation

## Scope

- Files reviewed: all of `dau-viet-admin/src/**` (40 files), `tests/**`, `scripts/e2e-backend-stub.mjs`, `playwright.config.ts`, `vitest.config.ts`, `tsconfig.json`, `next.config.mjs`, `package.json`, `.env.example`, `.gitignore`, `.github/workflows/admin-ci.yml`, `docs/admin-runbook.md`, `.harness/config.json` admin block.
- Cross-checked DTOs against `dau-viet-backend/src/main/java/com/dauviet/{auth,user,common,lesson,historicalevent}/**/dto` records and `AdminLessonTemplateController#listEnabled` return type.
- Verified `SecurityConfig.java:72` still enforces `hasRole("CONTENT_ADMIN")` on `/api/v1/admin/**`.
- Verified `AdminLessonController` sort whitelist includes `updatedAt` (line 54) — so dashboard's `sort=updatedAt,desc` is real, not fabricated.
- Verified `RefreshTokenService.rotate()` revokes the old token and issues a successor (single-use chain) — this is the property that makes the bug below a real correctness issue.

## Overall assessment

Code quality is high: type-safe DTOs mirror backend exactly, security posture is intentional (HttpOnly cookie + in-memory access token + BFF proxy with hop-by-hop stripping + explicit Set-Cookie drop), Vietnamese UI is consistent, all file sizes are well under the 200-line rule, no fabricated endpoints or metrics, honest "Sắp ra mắt"/"Chọn một bài học" placeholders, real MSW and node:http stubs (no fake-green). Lint/typecheck/build/tests were already verified green per task hand-off.

**However there is one P0 session-handling bug that breaks the auth flow on the second navigation after a reload, plus a small set of P1/P2 issues.**

## Critical (P0) — must fix before finish

### P0-1 — Rotated `dv_refresh` cookie is dropped inside `(admin)/layout.tsx`; the next client refresh is guaranteed to fail and revoke the whole family

**Files:**
- `dau-viet-admin/src/app/(admin)/layout.tsx:32` — calls `fetch("${proto}://${host}/api/auth/session", …)` and only consumes `res.json()`. The `Set-Cookie` header on `res` is never read or forwarded.
- `dau-viet-admin/src/app/api/auth/session/route.ts:38-66` — correctly rotates and re-sets the cookie on its own response, but that response goes to the layout's fetch, not to the browser.
- `dau-viet-admin/src/app/(admin)/layout.tsx:20` — comment claims "The rotated cookie from /api/auth/session is forwarded via Set-Cookie so the single-use rotation chain stays valid." That statement is **false as implemented**.

**Why this is a real bug, not a theoretical one:**

Backend `RefreshTokenService.rotate()` (lines 80-115) does `tokens.save(current.setRevokedAt(now))` then issues a successor, **and** treats a revoked-token presentation as theft → `revokeFamily()` kills every token in the family (line 91).

So the actual flow on every navigation/reload:

1. Browser reloads `/dashboard`. Middleware sees `dv_refresh=T1`, allows.
2. `(admin)/layout.tsx` calls `/api/auth/session` with `cookie: dv_refresh=T1`.
3. Session route posts `{refreshToken: T1}` to `/api/v1/auth/refresh`. Backend marks **T1 revoked** and returns `T2`.
4. Session route does `Set-Cookie: dv_refresh=T2` on its own response — which only the layout's internal `fetch` sees. The browser never gets `T2`.
5. Layout renders `AdminShell` with the user payload, returns HTML to the browser. Browser still holds **T1**, which is now revoked.
6. Any client-side `apiFetch` (e.g. `useQuery` for `/users/me`, `/admin/ping`, `/admin/lessons`) sends the in-memory access token — which is empty after a reload, so the request goes without `Authorization` → upstream 401 → `apiFetch` calls `tryRefresh()` → `POST /api/auth/refresh` with **T1** → backend sees `isRevoked(T1)=true` → `revokeFamily()` → 401 → `authStore.clear()` + `window.location.assign("/login")`.

The user is force-logged out on the first client query after a reload, **and** their whole refresh-token family is killed (so even logging in again from another tab would have been killed too — although here it's a single-user flow, it's still an unnecessary theft-response). Every page navigation back through a protected route repeats the cycle.

The reason the existing e2e test passes: `login.spec.ts` only does one navigation (login → dashboard), and the only query in `DashboardPage` (`me`) succeeds because the access token returned by the layout's `session` call is rendered into the page's HTML — wait, no, it isn't. Let me re-check.

Actually re-reading the flow more carefully: after the layout's `/api/auth/session` returns `accessToken=T2_access`, the layout only uses it to fetch `/users/me` server-side and pass `user` to `AdminShell` as a prop. **The new access token `T2_access` is not propagated to the client** — `authStore` on the browser is still empty after a reload. So the first client `apiFetch` from a component like `useQuery({queryKey: qk.me()})` goes to `/api/proxy/users/me` **without an Authorization header** → 401 → `tryRefresh()` → fails because `dv_refresh=T1` is already revoked → logout.

Why does the e2e test still pass? Because the test only asserts `page` has URL `/dashboard` and "Xin chào" / "Backend: hoạt động" are visible. The "Xin chào" text comes from `me.data?.displayName` — which is fetched by `useQuery` — and that call **will** fail per the analysis above. So either:
- The test is actually catching this and the user is seeing the loading skeleton long enough that the assertion still races ahead, OR
- There's a path I'm missing where the layout's rotated cookie reaches the browser.

Let me re-check the layout once more — no, the layout returns JSX; the fetch response's `set-cookie` header stays in that response object. There is no Next mechanism to forward it. This is a real bug.

**Wait — I want to double-check whether Next's internal fetch within a Server Component does propagate `Set-Cookie` to the client response.** It does not. `fetch` inside a Server Component is a normal HTTP call. The response headers are accessible via `res.headers`, but they don't auto-merge into the page's HTTP response. The page's HTTP response is determined by the route's own headers / middleware `NextResponse.next({headers})`.

**Recommendation:** Replace the `/api/auth/session` indirection with the simplest correct pattern — do the rotation **directly in the layout** (server-side) using `backendFetch`:

```ts
// in (admin)/layout.tsx — do NOT round-trip through /api/auth/session
const jar = await cookies();
const rt = jar.get(REFRESH_COOKIE)?.value;
if (!rt) redirect("/login");

const refreshRes = await backendFetch("/api/v1/auth/refresh", {
  method: "POST",
  body: JSON.stringify({ refreshToken: rt }),
});
if (!refreshRes.ok) redirect("/login");
const tokens = (await refreshRes.json()) as TokenResponse;

const meRes = await backendFetch("/api/v1/users/me", {
  headers: { authorization: `Bearer ${tokens.accessToken}` },
});
if (!meRes.ok) throw new Error(`me failed ${meRes.status}`);
const user = (await meRes.json()) as UserProfileDto;
if (user.role !== "CONTENT_ADMIN") return <ForbiddenState user={user} />;
return <AdminShell user={user} initialAccessToken={tokens.accessToken} expiresIn={tokens.expiresIn}>{children}</AdminShell>;
```

Then `AdminShell` accepts a prop `initialAccessToken` and on mount does `authStore.setAccessToken(initialAccessToken, expiresIn)`. That way the rotated `accessToken` reaches the client through RSC payload (it's already safe to expose — it's a Bearer token meant for the client) and **the refresh-token rotation issue is sidestepped** because the new `refreshToken` is *also* in `tokens` and needs to land in the cookie.

**The catch:** the new `refreshToken` still needs to reach the browser cookie. Next's recommended way is a `Route Handler`/`Server Action`/middleware that can `Set-Cookie`, not a Server Component. The clean options:

1. **Move the rotation to middleware** (`middleware.ts`): on every protected-path request, call backend `/auth/refresh`, then `NextResponse.next({ headers: { 'Set-Cookie': buildRefreshCookie(newToken, ttl) } })` and forward `x-access-token` to the page via a request header the layout reads. This is the standard NextAuth-style "middleware refreshes token" pattern. Refresh still happens in middleware where `Set-Cookie` can be emitted.

2. **Keep rotation in `/api/auth/session` but trigger it from the browser**, not the layout. After login, redirect target is `/dashboard`. The layout shouldn't call session itself; instead an `AuthRehydrate` client component inside `AdminShell` calls `fetch("/api/auth/session")` once on mount. That `fetch` is browser-originated, so `Set-Cookie` works normally. Until that fetch resolves, render a skeleton. The role check needs a different gate — use the `useQuery` for `/users/me` after rehydration: a 403 → render `ForbiddenState`. The middleware presence check + backend role check remain authoritative.

3. **Hybrid (recommended)**: split responsibilities —
   - Layout does NOT call `/auth/refresh`. It only checks `dv_refresh` presence and renders `AdminShell` with no `user` initially.
   - `AdminShell` mounts a `useBootstrapSession` hook that calls `POST /api/auth/refresh` (browser-originated → cookie rotation works) then `apiFetch<UserProfileDto>("/users/me")`, and only renders children when `role === 'CONTENT_ADMIN'`. While pending, show skeleton. On `!CONTENT_ADMIN`, render `ForbiddenState`. On 401-after-refresh, redirect to `/login`.
   - `authStore.setAccessToken` is populated by the refresh response before any children mount, so all subsequent `apiFetch` calls have a token.
   - The bonus: `refreshSession()` (currently dead code) becomes the bootstrap.

This is what the existing code almost does — it just runs the rotation on the wrong side of the HTTP boundary. The fix is small (move the rotate+me logic into a client-side bootstrap inside `AdminShell`, keep the layout thin) and restores the security model.

**Files to change:**
- `src/app/(admin)/layout.tsx` — drop the `/api/auth/session` internal call; keep cookie-presence + ForbiddenState for `!CONTENT_ADMIN` after a one-shot `/users/me` call OR push role check into client bootstrap.
- `src/components/admin-shell.tsx` — add a `useBootstrapSession` gate.
- Optionally delete `/api/auth/session/route.ts` if no longer needed, or keep it for rehydration (but trigger from the client).

### P0-2 — `refreshSession()` exported but never called — dead code; reload-token-rehydration does not exist

`src/features/auth/use-auth.ts:50` — `export async function refreshSession()`. Nothing imports it. The reload-rehydration path is supposed to be "(admin)/layout.tsx calls /api/auth/session" but per P0-1 that's broken. If the layout is fixed per recommendation #2/#3, `refreshSession` is the natural bootstrap; otherwise this is dead code that lints clean but does nothing.

This is not independent of P0-1 — it's a symptom of the same broken rehydration path. Track as part of the P0 fix.

## High (P1)

### P1-1 — No CSRF protection on `POST /api/auth/*` BFF routes

The refresh cookie is `SameSite=Lax`, which blocks cross-site POSTs in modern browsers — but only for top-level navigations it does send cookies. `SameSite=Lax` permits the cookie on top-level GET cross-site, but POSTs do not include the cookie. That's still the right mitigation today, but the runbook itself calls this out as "hardening is a follow-up" (`docs/admin-runbook.md:88`).

For a state-changing endpoint like `/api/auth/logout` (and `login`, `refresh`), consider adding a same-origin check (`Origin`/`Referer` host match) or a double-submit token if any future route becomes more sensitive. Not blocking — `SameSite=Lax` is the documented choice — but worth flagging since the refresh token is high-value.

### P1-2 — `/api/proxy/[...path]` lacks any rate limiting or request-size cap

`src/app/api/proxy/[...path]/route.ts` streams `await req.arrayBuffer()` with no size cap. A logged-in admin could POST a multi-GB body through the proxy and strain both the Next server and the backend. Mitigations: add `export const maxDuration`/`bodySizeLimit` per Next 15 conventions, or check `content-length` header before buffering. Low probability (admins are trusted) but cheap to bound.

### P1-3 — `authStore` has a TOCTOU on `getAccessToken` during refresh

`src/lib/api-client.ts:30` — `getAccessToken` reads module state; if a refresh is in-flight via `tryRefresh`, concurrent queries may all see `null` token and each trigger a 401 → all converge on `tryRefresh` (which single-flights correctly). That's fine. But `getAccessToken`'s `-15_000` skew uses `expiresAt - 15_000` — if `expiresIn` is small (e.g. test stubs returning `expiresIn: 5`), the token is always considered expired, the first `apiFetch` always 401s, and the user-visible behavior is "every call needs a refresh". The MSW fixtures use `expiresIn: 900` so this doesn't bite in tests, but it's brittle if a test ever sets a small `expiresIn`. Document or guard.

### P1-4 — `safeNext` allows arbitrary same-origin paths, including `/api/proxy/...`

`src/features/auth/schemas.ts:18-25` — the regex `^\/[a-zA-Z0-9\-_\/]*$` allows `next=/api/proxy/admin/users` or `next=/api/auth/logout`. After a successful login, `window.location.assign(safeNext(...))` could bounce the browser onto a JSON endpoint or trigger a logout GET (which doesn't exist — `/api/auth/logout` only accepts POST, so that specific one is safe). Still, allowing the redirect to land on `/api/*` paths is unnecessary. Tighten the allowlist to known admin prefixes:

```ts
const NEXT_PATH_RE = /^\/(dashboard|events|lessons|templates|assets|versions)(\/[a-zA-Z0-9\-_\/]*)?$/;
```

This is defense-in-depth — not exploitable today (the worst case is landing on a JSON response), but it removes a class of future issues cheaply.

### P1-5 — Layout's `useQuery` for `me` runs even after ForbiddenState is rendered server-side

Looking again at `dashboard-page.tsx` — it's mounted under `(admin)/layout.tsx`, which already gates by role. So `me.data` is only ever rendered for CONTENT_ADMIN. But the `me` query still fires unconditionally — not a bug, just redundant: the layout already fetched `/users/me` server-side. Consider seeding the TanStack Query cache with `initialData` from the layout's fetch (via `AdminShell` prop drilling) — saves one round-trip and prevents the flicker where the skeleton renders before the cached `me` resolves.

This is a UX nicety, not correctness.

## Medium (P2)

### P2-1 — `session/route.ts` duplicates `refresh/route.ts` — DRY

`session/route.ts` and `refresh/route.ts` share ~30 lines of identical rotate-then-set-cookie logic. Extract a small helper in `src/lib/server/` (e.g. `rotateRefreshAndBuild(cookieJar): Promise<{tokens, setCookie}>`), or — better — fold `/api/auth/session` into `/api/auth/refresh` by making `refresh` also return `user` (one round-trip instead of two for the bootstrap). Cleaner API and removes the duplication.

### P2-2 — `EventsTable` does not pass `sort` even though backend supports it

`src/features/events/events-table.tsx:29` — `apiFetch<PageResponse<AdminEventSummary>>("/admin/events?size=20")`. The backend `AdminEventController` also whitelists `updatedAt` (verified earlier via grep). Not required by AC, but the dashboard's "recent lessons" card already relies on `sort=updatedAt,desc` — passing `sort=updatedAt,desc` on `/events` would make the ordering consistent and predictable.

### P2-3 — `apiFetch` uses `as T` / `body as T` without narrowing

`src/lib/api-client.ts:40-44` — `res.json()` is `any`, then `body as T`. The plan explicitly says "no `as` without a comment." Not a type-safety bug (callers declare `T`), but you could add a comment or use zod schemas for the few DTOs that need runtime guarantees (`UserProfileDto`, `PageResponse`).

### P2-4 — Confirm dialog lacks an `Escape`-to-close customization and has no `autoFocus` target

`src/components/confirm-dialog.tsx` — Radix Dialog defaults handle Escape, but the primary action button isn't focused by default; a keyboard user has to Tab through Cancel → Confirm. Minor; Radix defaults are mostly fine.

### P2-5 — `RecentLessonsCard` shows `Chưa xuất bản` text instead of using `StatusChip` consistently

`src/features/dashboard/recent-lessons-card.tsx:52` — the chip for status is rendered via `<StatusChip>`, but the "Phiên bản hiện tại" is hand-rolled text. Fine, but inconsistent with `LessonsTable` which shows `v#rowVersion` when `currentVersionId` is set. Minor display nit — not blocking.

## Low (P3)

- `src/lib/server/backend.ts` doesn't set a timeout — if backend hangs, BFF route hangs. Next 15 has default `maxDuration` per route; a `AbortSignal.timeout(15_000)` on `fetch` would bound it.
- `src/app/api/auth/login/route.ts:34` — `JSON.parse(text)` will throw on malformed upstream JSON; not wrapped. Real backends won't do this; acceptable.
- `middleware.ts` matcher is route-by-route literal — adding a new top-level admin route requires updating the matcher. Document or use a single `/(admin-*)` matcher.
- `admin-shell.tsx` avatar `charAt(0).toUpperCase()` — non-BMP first characters (rare in Vietnamese names) could render oddly. Edge case.

## Edge cases scouted

- **Refresh-token rotation race:** if two RSC navigations fire concurrently, both will try to rotate the same `dv_refresh` and the second will get 401 + family revoke. With the current broken forwarding this never happens (the cookie is stale anyway), but after fixing P0-1 keep this in mind — recommend the rotation happen at most once per request via middleware, OR rely on the client-side single-flight `tryRefresh` in `api-client.ts`.
- **Cookie `Path=/` is broader than the original plan** (which said `Path=/api/auth`). The current choice is documented in `refresh-cookie.ts:9-14` and is required for middleware to see the cookie on every route — but it also means the refresh token is sent to *every* BFF route, including `/api/proxy/*`. That's fine (it's only read by `readRefreshToken` in auth routes), but if you ever add another route that does `cookies().toString()` and forwards it upstream, you'd leak. The proxy already strips incoming `Cookie` headers correctly.
- **Open-redirect `next=//evil.com`** correctly rejected by both the regex (`/` then `e` isn't allowed by `\/` again — wait, actually `//evil.com` *starts* with `//` and the regex `[a-zA-Z0-9\-_\/]` DOES include `/`, so `//evil.com` would match the regex). But the second check `raw.startsWith("//")` catches it. So `//evil.com` → `/dashboard`. Good — belt-and-suspenders.
- **`next=/\\evil`** — backslash not in regex → rejected. Good.
- **`next=/login?next=/login` recursion** — `?` not allowed in `next`, so can't chain. Good.
- **Stale `eventId` in lessons list** — `AdminLessonSummary.eventId` is rendered raw (truncated UUID) which leaks no PII but is ugly. Consider joining to event title in a follow-up.

## Positive observations

- DTOs are verbatim mirrors of backend records — spot-checked all six types against their Java counterparts (`AdminLessonSummaryResponse`, `LessonTemplateResponse`, `AdminEventSummaryResponse`, `TokenResponse`, `UserProfileDto`, `PageResponse`, `ApiError`). No drift.
- No fabricated endpoints — every `apiFetch` path maps to a real backend route.
- Hop-by-hop header stripping in proxy is correct and explicitly drops `Set-Cookie` so upstream cookies can't leak to the browser.
- `SafeNext` regex correctly rejects `//`, `\\`, schemes, and special chars — the unit tests cover all the vectors (protocol-relative, backslash, JS scheme, with query/fragment).
- Honest empty states on `/assets` and `/versions` — no fake CRUD, no fabricated version list (backend only exposes per-lesson versions).
- `useLogin` uses `window.location.assign` (not `router.replace`) for post-login navigation — the comment correctly identifies that this guarantees the just-set cookie rides the next request, avoiding the middleware race.
- Tests are real MSW + node:http, not module mocks. `vitest.setup.ts` uses `onUnhandledRequest: "error"` which is the right call to catch unfaked traffic.
- Accessibility: `aria-current`, `aria-expanded`, `aria-invalid`, `role="alert"`, `aria-label` on icon buttons, semantic `scope="col"` on table headers, visible `:focus-visible` ring, color paired with icon/text on `StatusChip`.
- File sizes all under 200 lines per `development-rules.md`.
- Lint config and CI workflow are clean; workflow has `permissions: contents: read`, `concurrency`, artifact upload for traces.

## AC compliance spot-check

- AC-1 (bootstrap): pass — strict TS, ESLint, env zod validation, path aliases, lockfile pinned.
- AC-2 (real auth): pass — real `/api/v1/auth/login` via `backendFetch`, no mock.
- AC-3 (session safety): **FAIL — P0-1.** Refresh token never reaches client JS (good), cookie flags are right, but rotation is broken because `Set-Cookie` is dropped.
- AC-4 (authorization): pass with caveat — middleware presence + layout role check + backend `hasRole` is correct *when* the layout call succeeds; but the broken session call means the role check itself is part of the broken path.
- AC-5 (admin layout): pass — sidebar/header/breadcrumbs/identity/logout/collapse/mobile/error/404/403.
- AC-6 (login + dashboard): pass.
- AC-7 (design system): pass — buttons, inputs, labels, cards, chips, table, dialog, toast (sonner), empty, skeleton, page header, error, VN labels, focus ring, contrast.
- AC-8 (typed API): pass — base URL via BFF, all DTOs match, error parsing covers 400/401/403/404/409/422/5xx, `toQuery` for pagination, `qk` namespacing.
- AC-9 (module shells): pass — events/lessons wired to real APIs; assets/versions honest placeholders.
- AC-10 (tests): pass — Vitest+RTL+MSW suite + Playwright spec against `node:http` stub. Spec correctly labeled as controlled backend, not real-backend E2E.
- AC-11 (CI): pass — workflow covers lint/typecheck/test/build/e2e, does not break existing.
- AC-12 (docs+harness): pass — `.env.example` has no secrets, runbook is honest about limitations, `.harness/config.json` admin gates wired.

## Verdict

**CHANGES REQUIRED.**

P0-1 must be fixed before this task can be marked complete: the session model as implemented cannot survive a page reload — it force-logs the user out on the next client query and revokes the refresh-token family as a side effect. The fix is small (restructure where rotation happens — move it either to middleware or to a client-side bootstrap inside `AdminShell`), well-scoped, and the existing test suite + a new "reload → still authenticated" Playwright or RTL test will lock it in.

P1 items (CSRF hardening note, proxy body cap, `safeNext` allowlist tightening, redundant `me` query) are recommended follow-ups but not blocking.

P2/P3 are cleanups.

## Recommended actions (in order)

1. **Fix P0-1** — restructure session bootstrap per the recommendation above. Either:
   - Move `/auth/refresh` to `middleware.ts` and forward the new access token via request header to `(admin)/layout.tsx`, **or**
   - Move the rotation out of the layout entirely and do it client-side inside `AdminShell` on mount, so `Set-Cookie` can reach the browser. This is the simpler change.
2. While doing #1, either delete `refreshSession()` or wire it as the client-side bootstrap (don't leave dead code).
3. Add a test: reload `/dashboard` → assert user is still logged in after the first `apiFetch` (RTL+MSW is sufficient — assert MSW sees the post-refresh `Authorization` header).
4. Fix P1-4 (`safeNext` allowlist tightening) — 5-line change.
5. Optional: bound `/api/proxy` request size; document CSRF posture in runbook.
6. Re-run `npm run typecheck && npm run lint && npm run test -- --run && npm run test:e2e` then mark task complete.

## Unresolved questions

- After fixing P0-1, do you prefer middleware-driven rotation (NextAuth-style, tokens live in encrypted cookie only) or client-bootstrap-driven rotation (current architecture, smaller diff)? Both are correct; middleware scales better when more routes need auth.
- Should `/api/auth/session` route be removed entirely once the bootstrap moves, or kept as a debugging aid? Currently it has no production caller other than the broken layout path.

## Metrics

- Files reviewed: ~45 source/test/config files.
- LOC: ~1,400 in `src/` (rough count).
- Type coverage: 100% strict TS, no `any` outside of `as T` on JSON responses (P2-3).
- Test coverage: 6 test files (5 vitest + 1 playwright spec with 2 tests). All flows asserted against MSW/node:http stub, not production-path mocks.
- Lint issues: 0 reported (per handoff).
- DTO drift vs backend: none.
