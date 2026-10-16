# Phase 02 — Auth BFF + typed API client (AC-2, AC-3, AC-8)

## Overview
- Priority: P1 · Status: pending · Effort: ~3h
- Implements D1/D5: Next.js Route-Handler BFF for auth (refresh token lives only in HttpOnly cookie), typed `api-client`, DTOs, query-key conventions, ApiError mapping, TanStack Query hooks for auth.

## Files to create

### BFF routes (server-side, never ship to browser)

```
src/app/api/auth/login/route.ts      POST -> backend /api/v1/auth/login, set dv_refresh cookie
src/app/api/auth/refresh/route.ts    POST -> backend /api/v1/auth/refresh, rotate cookie
src/app/api/auth/logout/route.ts     POST -> backend /api/v1/auth/logout, clear cookie
src/app/api/auth/session/route.ts    GET  -> if cookie present, refresh + return {user}
src/app/api/proxy/[...path]/route.ts ALL  -> forward to BACKEND_URL, attach Authorization from request
src/lib/server/refresh-cookie.ts     set/clear/read cookie helpers (HttpOnly, SameSite=Lax, Path=/api/auth, Max-Age=refreshExpiresIn, Secure in prod)
src/lib/server/backend.ts            server-side fetch wrapper (no retries on 4xx)
```

### Client auth + API

```
src/lib/dto/auth.ts                  TokenResponse, LoginRequest, RefreshRequest
src/lib/dto/user.ts                  UserProfileDto, UserRole enum
src/lib/dto/common.ts                PageResponse<T>, ApiError
src/lib/dto/event.ts                 AdminEventSummaryResponse, AdminEventDetail
src/lib/dto/lesson.ts                AdminLessonSummaryResponse
src/lib/dto/template.ts              LessonTemplateResponse
src/lib/api-error.ts                 class ApiClientError {status, code, message, details, traceId}
src/lib/api-client.ts                apiFetch<T>(path, init) — attaches Authorization, throws ApiClientError
src/lib/query-keys.ts                qk.* builders
src/features/auth/auth-store.ts      in-memory {accessToken, expiresAt} + listeners (no localStorage)
src/features/auth/use-auth.ts        useLogin(), useLogout(), useRefresh() TanStack mutations
src/features/auth/auth-provider.tsx  wraps app (admin segment), exposes accessToken + refresh-on-mount
src/middleware.ts                    redirect /dashboard/*, /events/*, /lessons/*, /templates/*, /assets/*, /versions/* to /login when dv_refresh missing
```

## Implementation notes

### `POST /api/auth/login` route

```ts
const res = await fetch(`${env.BACKEND_URL}/api/v1/auth/login`, {
  method: 'POST', headers: {'content-type':'application/json'},
  body: JSON.stringify({email, password}), cache: 'no-store',
});
if (!res.ok) return Response.json(await res.json(), {status: res.status});
const tokens = await res.json(); // TokenResponse
const response = Response.json({
  accessToken: tokens.accessToken,
  expiresIn: tokens.expiresIn,
});
response.headers.append('Set-Cookie', buildRefreshCookie(tokens.refreshToken, tokens.refreshExpiresIn));
return response;
```

Cookie shape: `dv_refresh=<token>; HttpOnly; Path=/api/auth; SameSite=Lax; Max-Age=<refreshExpiresIn>; Secure` (Secure only when `NODE_ENV==='production'`).

### `POST /api/auth/refresh`

Reads `dv_refresh`, calls backend `/auth/refresh`, on 200 sets the new cookie (rotation — old token is now revoked server-side) and returns `{accessToken, expiresIn}`. On 401/400, clears cookie and returns the upstream error body verbatim.

### `POST /api/auth/logout`

Reads cookie (may be absent), calls backend `/auth/logout` if present, **always** clears cookie, returns 204. Idempotent.

### `GET /api/auth/session`

Convenience for `AdminLayout` — returns `{user}` if a valid refresh cookie exists; calls `/auth/refresh` internally then `/users/me`. Used to restore session after full page reload.

### `middleware.ts`

```ts
export const config = { matcher: ['/((?!login|api|_next|favicon).*)'] };
export function middleware(req: NextRequest) {
  const has = req.cookies.has('dv_refresh');
  if (!has) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.search = `?next=${encodeURIComponent(req.nextUrl.pathname)}`;
    return NextResponse.redirect(url);
  }
}
```

This is **presence-only**; role enforcement happens in `(admin)/layout.tsx` via `/users/me`. Do not decode JWT in middleware — that's the backend's job.

### `apiFetch`

```ts
export async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const token = authStore.getAccessToken();
  const res = await fetch(`/api/proxy${path}`, {
    ...init,
    headers: { 'content-type':'application/json',
               ...(token ? { authorization: `Bearer ${token}` } : {}),
               ...init?.headers },
  });
  if (res.status === 204) return undefined as T;
  const body = await res.json().catch(() => null);
  if (!res.ok) throw ApiClientError.from(body, res.status);
  return body as T;
}
```

On 401, `AuthProvider` listens via a single-flight `refreshPromise`, calls `/api/auth/refresh`, retries once. Failure → `redirect('/login')`.

### `proxy/[...path]/route.ts`

Forwards all methods, copies `authorization` header + body, streams upstream status/headers/body, strips hop-by-hop headers. Does **not** add the refresh cookie — only the Authorization header is propagated.

## Tests (Vitest + MSW)

- `login-route.test.ts` — POST `/api/auth/login` success: assert cookie set, body has `accessToken` but not `refreshToken`.
- `refresh-route.test.ts` — cookie rotation; on upstream 401 cookie cleared.
- `logout-route.test.ts` — always clears cookie.
- `api-client.test.ts` — maps error envelope to `ApiClientError`.
- `use-login.test.tsx` — success stores access token; INVALID_CREDENTIALS surfaces Vietnamese error.

## Success criteria

- All BFF routes return correct status codes and cookie behavior under `next dev` + `curl`.
- `refreshToken` never appears in any client response body (grep test).
- Type-safe DTOs compile; `tsc --noEmit` clean.

## Risks

- Cookie `Secure` flag breaks `next dev` over `http://localhost` — conditionally omit in dev (see D1).
- `route.ts` cookies API differs across Next versions — use `cookies()` from `next/headers` for reads and `response.headers.append('Set-Cookie', ...)` for writes; avoid `cookieStore.set` on outgoing response.
- Refresh token rotation race: concurrent tabs calling `/refresh` — backend already revokes family on reuse. If it surfaces, single-flight refresh in `AuthProvider` mitigates. Document in runbook.

## Security

- CSRF: BFF routes are `POST` only, use JSON content-type, cookie `SameSite=Lax`. Login is pre-auth so CSRF risk is minimal; do not add token-based CSRF this task — note in runbook as future hardening.
- Never log `refreshToken` / `accessToken` / password.
- Backend remains the only role-authority; UI guards are UX, not security.
