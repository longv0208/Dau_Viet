# Phase 07 — Vitest Coverage

## Context links
- Tất cả phases trước
- `src/test/msw/server.ts`
- `src/features/lessons/lessons-table.test.tsx` (nếu có — check)
- `src/features/evidence/evidence-table.test.tsx`
- `src/features/events/map-locations-section.test.tsx`
- `src/features/animations/animation-types.test.ts`

## Overview
- **Priority**: P1
- **Status**: pending
- **Effort**: 2h
- Vitest + React Testing Library coverage cho các component mới + helper + refactor. KHÔNG Playwright. Backend không đổi → không cần backend tests.

## Key insights
- Test setup đã sẵn: `src/test/msw/server.ts` (MSW), `*.test.tsx` pattern đã dùng.
- Cần cover: `parseReturnTo`/`withReturnTo`, `LessonsTable` lockedEventId, `EvidenceTable` lockedEventId, `AnimationLibrary` lockedEventId, `EventWorkspaceTabs`, `EventWorkspacePage` tab switching, `Breadcrumbs` UUID title lookup, `BackLink`, `EventInfoTab`, `EventOverviewTab` stats + checklist.
- MSW handlers cần thêm: `/admin/lessons?eventId=`, `/admin/evidences?eventId=`, `/admin/animation-scenes?eventId=`, `/admin/animation-scenes/html-import?eventId=`.

## Requirements
- Unit tests cho `return-to.ts`:
  - `parseReturnTo` accepts valid paths, rejects external/javascript/missing UUID/invalid tab.
  - `withReturnTo` appends `?return=` vs `&return=` correctly + encodes.
- Component tests:
  - `EventWorkspaceTabs`: 4 tabs render, active state đúng, link đúng `?tab=`.
  - `EventWorkspacePage`: render default `overview`, switch theo `?tab=`.
  - `LessonsTable` với `lockedEventId`: hide event dropdown + column; query gọi `eventId=`.
  - `EvidenceTable` + `AnimationLibrary`: tương tự.
  - `EvidenceForm` với `presetEventId`: select disabled, defaultValue đúng.
  - `BackLink`: render khi `?return=` hợp lệ, không render khi không có/không hợp lệ.
  - `Breadcrumbs`: render `<event title>` khi fetch success, fallback "Chi tiết" khi 404.
  - `EventOverviewTab`: render stats + checklist khi có data, hero empty khi tất cả = 0.
  - `EventInfoTab`: render `EventForm` + `MapLocationsSection`.
- MSW handlers mới cho các query `?eventId=`.

## Architecture
- Test file convention: `<component>.test.tsx` cạnh component.
- Helper tests: `src/lib/return-to.test.ts`.
- Mock `useSearchParams` từ `next/navigation` cho các tests dùng `?tab=`/`?return=`.
- MSW: mở rộng `src/test/msw/server.ts` handlers — add eventId-aware handlers (return filtered `PageResponse`).

## Related code files

**Modify**
- `src/test/msw/server.ts` — add handlers `eventId` filter cho lessons/evidences/animation-scenes; mock `/admin/events/{id}` trả detail.
- `src/features/lessons/lessons-table.tsx` — đảm bảo component testable (đã có).
- `src/features/evidence/evidence-table.tsx` — idem.
- `src/features/animations/animation-library.tsx` — idem.

**Create**
- `src/lib/return-to.test.ts`
- `src/features/events/workspace/event-workspace-tabs.test.tsx`
- `src/features/events/workspace/event-workspace-page.test.tsx`
- `src/features/events/workspace/event-overview-tab.test.tsx`
- `src/features/events/workspace/event-info-tab.test.tsx`
- `src/features/events/workspace/workspace-checklist.test.tsx`
- `src/components/back-link.test.tsx`
- `src/components/breadcrumbs.test.tsx` (nếu chưa có — check)
- `src/features/lessons/lessons-table.test.tsx` (nếu chưa có)
- `src/features/animations/animation-library.test.tsx` (nếu chưa có)

**Delete**
- (none)

## Implementation steps
1. Viết `return-to.test.ts` — table-driven cases (accept/reject).
2. Setup MSW handlers mới cho `eventId` queries (trả `PageResponse` filtered).
3. Mock `next/navigation.useSearchParams` — tạo helper `mockSearchParams({ tab, return, ... })`.
4. Viết component tests theo danh sách.
5. Run `pnpm --filter dau-viet-admin test` (hoặc `npm test` — check package.json) → ensure pass.
6. Coverage: `vitest run --coverage` → đạt ≥85% trên các file mới.

## Todo list
- [ ] `return-to.test.ts` (≥15 cases)
- [ ] MSW handlers `?eventId=` cho 3 endpoints
- [ ] `mockSearchParams` helper
- [ ] `EventWorkspaceTabs` tests
- [ ] `EventWorkspacePage` tests (tab switching)
- [ ] `LessonsTable` lockedEventId tests
- [ ] `EvidenceTable` + `AnimationLibrary` lockedEventId tests
- [ ] `EvidenceForm` presetEventId tests
- [ ] `BackLink` tests
- [ ] `Breadcrumbs` UUID lookup tests
- [ ] `EventOverviewTab` stats + empty tests
- [ ] `EventInfoTab` compose test
- [ ] `WorkspaceChecklist` tests
- [ ] Full suite pass + coverage ≥85% trên files mới

## Success criteria
- `pnpm test` pass 100%.
- Coverage trên `src/lib/return-to.ts` ≥95%; trên components mới ≥85%.
- Không còn console warnings trong test run.
- MSW handlers tái sử dụng được cho tests tương lai.

## Risk assessment
- **R-01**: `useSearchParams` mocking — Next.js App Router requires wrapping in `<Suspense>`; test phải render trong Suspense boundary.
- **R-02**: `Breadcrumbs` fetch title async → test cần `await waitFor` + MSW resolve.
- **R-03**: `EventWorkspacePage` có nhiều query con → test cần nhiều MSW handlers; có thể split test theo tab.
- **R-04**: Vitest JSDOM không support `IntersectionObserver`/`matchMedia` — nếu `AssetsLibrary` dùng → mock.

## Security considerations
- Tests assert `parseReturnTo` reject `javascript:`, `data:`, `//evil.com`, paths ngoài whitelist.
- Assert `withReturnTo` encodeURIComponent.

## Next steps
- Handoff: implementation team chạy `vitest` sau mỗi phase; phase 07 chỉ viết test, không thêm feature.
