# Phase 05 — Tests (AC-10)

## Overview
- Priority: P1 · Status: pending · Effort: ~2h
- Unit/component suite (Vitest + RTL + MSW) + at least one browser-level test (Playwright) covering Login → Dashboard against a controlled stub backend.

## Coverage matrix (AC-10 map)

| AC-10 bullet | Test |
|---|---|
| Login validation | `login-form.test.tsx` — required, invalid email |
| Auth success/failure | `use-login.test.tsx`, `login-route.test.ts` — success sets cookie+token; INVALID_CREDENTIALS surfaces |
| Expired session + refresh | `auth-refresh.test.tsx` — 401 triggers `/api/auth/refresh` once (single-flight), retry succeeds; refresh fails → redirect login |
| Unauthorized / learner denied | `middleware.test.ts`, `forbidden.test.tsx` |
| Logout | `logout-route.test.ts`, `use-logout.test.tsx` — clears state, posts to backend |
| Layout & navigation | `admin-shell.test.tsx`, `breadcrumbs.test.tsx` |
| API error parsing | `api-client.test.ts` — 400/401/403/404/409/422/500 → typed error, code+traceId preserved |
| Browser-level Login→Dashboard | `tests/e2e/login.spec.ts` |

## Files to create

```
src/test/msw/handlers.ts       # default stubs — login 200, me 200, ping 200, events/lessons pages
src/test/msw/server.ts         # setupServer for node env
src/test/fixtures.ts           # TokenResponse fixture, UserProfileDto fixture, PageResponse fixtures
src/test/utils.tsx             # renderWithProviders (QueryClient + AuthProvider), mockRouter helpers
tests/e2e/login.spec.ts        # Playwright
scripts/e2e-backend-stub.mjs   # tiny node:http stub backend for Playwright — no MSW dep
```

## MSW default handlers

```ts
http.post('*/api/v1/auth/login', () => HttpResponse.json(tokenFixture)),
http.post('*/api/v1/auth/refresh', () => HttpResponse.json(tokenFixture)),
http.post('*/api/v1/auth/logout', () => new HttpResponse(null, {status:204})),
http.get('*/api/v1/users/me', () => HttpResponse.json(adminUserFixture)),
http.get('*/api/v1/admin/ping', () => HttpResponse.json({status:'ok'})),
http.get('*/api/v1/admin/events', () => HttpResponse.json(eventsPageFixture)),
http.get('*/api/v1/admin/lessons', () => HttpResponse.json(lessonsPageFixture)),
http.get('*/api/v1/admin/lesson-templates', () => HttpResponse.json(templatesFixture)),
```

Override per-test via `server.use(...)`.

## Playwright test (`tests/e2e/login.spec.ts`)

```ts
test('admin can login and reach dashboard', async ({ page }) => {
  // webServer in playwright.config.ts starts:
  //   1) scripts/e2e-backend-stub.mjs on :8081
  //   2) next dev on :3000 with BACKEND_URL=http://localhost:8081
  await page.goto('/login');
  await page.getByLabel(/email/i).fill('admin@dauviet.local');
  await page.getByLabel(/mật khẩu|password/i).fill('secret');
  await page.getByRole('button', {name:/đăng nhập/i}).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await expect(page.getByText(/xin chào/i)).toBeVisible();
});
```

**Backend stub (`e2e-backend-stub.mjs`)** — 60-line `node:http` server returning canned `TokenResponse`/`UserProfileDto`/`{status:'ok'}`; validates JSON body shape only. Clearly labeled "controlled stub, NOT the real backend" in test file header and runbook.

### Playwright availability fallback (documented honestly)

If `npx playwright install --with-deps chromium` fails on this machine (proxy/permissions):

1. Document failure in `docs/admin-runbook.md` + task evidence.
2. Replace `login.spec.ts` with `tests/integration/login-flow.test.tsx` — mounts `<LoginPage>` → `<AdminLayout>` → `<DashboardPage>` inside a `MemoryRouter`-equivalent (App Router doesn't have one; use `next-router-mock` or drive via `useRouter` jest-mock) under MSW. Label explicitly: **component-level integration test — not browser-level E2E**.
3. AC-10 then partially met; flag in evidence.

## npm scripts

```
"test":          "vitest",
"test:watch":    "vitest --watch",
"test:coverage": "vitest run --coverage",
"test:e2e":      "playwright test",
```

## Success criteria

- `npm run test -- --run` exits 0 with all unit/component tests green.
- `npm run test:e2e` passes OR honest documented fallback per above.
- Coverage report shows the AC-10 matrix cases exercised.
- No mocks in production code paths; mocks confined to `src/test/` + `tests/`.

## Risks

- `next dev` port collisions in CI — use `webServer` config in `playwright.config.ts` with `reuseExistingServer: !process.env.CI`.
- MSW + jsdom Request/Response polyfills — pin `msw@2` + `undici` polyfill via `vitest.setup.ts` if needed.
- Tests must not depend on network except the local stub backend.
