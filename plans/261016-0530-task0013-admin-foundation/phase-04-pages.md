# Phase 04 — Pages: Login, Dashboard, module shells (AC-4, AC-5, AC-6, AC-9)

## Overview
- Priority: P1 · Status: pending · Effort: ~2.5h
- Implements A-01 Login + A-02 Dashboard + module entry shells (`/events`, `/lessons`, `/templates`, `/assets`, `/versions`) + role-based access UX.

## Files to create

```
src/app/(auth)/login/page.tsx                 A-01 — centered card on cream bg
src/app/(auth)/layout.tsx                     minimal — no AdminShell here
src/app/(admin)/layout.tsx                    AdminShell + role guard
src/app/(admin)/dashboard/page.tsx            A-02
src/app/(admin)/events/page.tsx               shell — DataTable wired to real list
src/app/(admin)/lessons/page.tsx              shell — DataTable wired
src/app/(admin)/templates/page.tsx            shell — read-only DataTable
src/app/(admin)/assets/page.tsx               honest coming-soon
src/app/(admin)/versions/page.tsx             honest "choose lesson" empty state
src/app/(admin)/error.tsx                     error boundary
src/app/(admin)/not-found.tsx                 404
src/app/(admin)/forbidden.tsx                 403 page
src/features/auth/login-form.tsx              RHF + zod
src/features/auth/schemas.ts                  loginSchema {email, password}
src/features/dashboard/dashboard-page.tsx     welcome, ping status, quick nav, recent drafts
src/features/dashboard/admin-ping-card.tsx
src/features/events/events-table.tsx
src/features/lessons/lessons-table.tsx
src/features/templates/templates-table.tsx
```

## Implementation notes

### `(admin)/layout.tsx` — server component

```tsx
export default async function AdminLayout({children}) {
  // If dv_refresh cookie missing, middleware already redirected.
  // Verify role via BFF: refresh access token then /users/me.
  const res = await fetch(`${origin}/api/auth/session`, {headers: {cookie: cookies().toString()}, cache:'no-store'});
  if (res.status === 401) redirect('/login');
  if (!res.ok) throw new Error('session fetch failed');
  const {user} = await res.json();
  if (user.role !== 'CONTENT_ADMIN') return <ForbiddenState user={user} />;
  return <AdminShell user={user}>{children}</AdminShell>;
}
```

Learner-JWT case → `ForbiddenState` (not redirect to login — they ARE logged in, just not admin). Backend `/api/v1/admin/**` still enforces `hasRole('CONTENT_ADMIN')` server-side; this layout is UX only.

### A-01 Login page

- Centered card on `--color-surface` bg.
- Title: "Đăng nhập quản trị" / subtitle "Dấu Việt CMS".
- Form: `email` + `password`, RHF+Zod. Vietnamese error messages: "Email không hợp lệ", "Vui lòng nhập mật khẩu".
- Submit → `POST /api/auth/login` via `useLogin` mutation. On 401 `INVALID_CREDENTIALS` show "Email hoặc mật khẩu không đúng". On network error show "Không thể kết nối máy chủ".
- `?next=` param: same-origin path starting `/` and not `//` — else `/dashboard`.
- Button disabled while pending, label "Đang đăng nhập...".

### A-02 Dashboard

- `PageHeader` "Tổng quan" + breadcrumb.
- Welcome card: "Xin chào, {displayName}" + role badge `Quản trị nội dung`.
- `AdminPingCard` — `useQuery(qk.admin.ping)` → `GET /api/proxy/admin/ping`; renders "Backend: Hoạt động" (green) or "Backend: Lỗi" + `traceId`.
- Quick-nav grid: cards linking to each module route with icon + one-line description.
- "Bài học gần đây" — `useQuery(qk.lessons.list({size:5}))`; if `sort=updatedAt,desc` supported, use it; else default order. Render `AdminLessonSummaryResponse` rows: title + status chip + `currentVersionId ? 'v…' : '—'`. Empty → "Chưa có bài học nào".
- **No fabricated metrics.** Only data the API actually returns.

### Module shells

- `/events`: `useQuery(qk.events.list({page,size:20}))` → `PageResponse<AdminEventSummaryResponse>` → DataTable columns: `Tiêu đề` `Thời kỳ` `Năm` `Trạng thái` `Tags`. Page size selector optional. Empty state "Chưa có sự kiện nào". Header button "Tạo sự kiện" → `disabled` with tooltip "Sắp ra mắt" — do NOT wire POST this task.
- `/lessons`: same pattern — columns `Tiêu đề` `Sự kiện` `Trạng thái` `Phiên bản hiện tại`. Header "Tạo bài học" disabled.
- `/templates`: columns `Tên mẫu` `Mã` `Mô tả`. Read-only.
- `/assets`: card "Thư viện media — Sắp ra mắt" + description of planned capability.
- `/versions`: empty state "Chọn một bài học để xem lịch sử phiên bản" + link to `/lessons`. Backend exposes versions per-lesson only — honest UX, no fake list.

### Error boundaries

- `(admin)/error.tsx`: catches render errors in segment — shows `ErrorState` with "Thử lại".
- `(admin)/not-found.tsx`: "Không tìm thấy trang" + back to dashboard.
- `(admin)/forbidden.tsx`: re-exported as `forbidden-state` component used by layout.

## Tests

- `login-form.test.tsx` — invalid input shows errors; submit disabled while pending.
- `login-page.test.tsx` — successful submit navigates to `next` (mock `useRouter`).
- `dashboard-page.test.tsx` — renders welcome, ping card, quick nav.
- `events-page.test.tsx` — MSW returns 2 events → renders rows; MSW 500 → error state; empty → empty state.
- `forbidden.test.tsx` — learner `user.role='LEARNER'` renders forbidden.
- `middleware.test.ts` — protected path without cookie → redirect; `/login` always allowed; `next=` validation.

## Success criteria

- Manual smoke: backend running with seeded admin → login → dashboard shows real ping → reload stays logged in → logout returns to login.
- Learner account → sees forbidden page.
- All AC-4, AC-5, AC-6, AC-9 checkable via tests + manual run.

## Risks

- Sort key on `/admin/lessons` unverified — read `AdminLessonController` and adapt; honest fallback documented in runbook.
- `next=` open-redirect guard must be tested for `//evil.com`, `\\evil.com`, `/\evil`, `javascript:`.
- Reload mid-session: `AuthProvider` calls `/api/auth/refresh` in `useEffect` — loading state must not flash content.

## Security

- `?next=` — strict allowlist regex `^\/[a-zA-Z0-9\-_\/]*$`, reject `//`, `\\`, schemes.
- Do not display `accessToken` or `refreshToken` anywhere.
- Logout button in user menu calls `useLogout` → `POST /api/auth/logout` → `redirect('/login')`.
