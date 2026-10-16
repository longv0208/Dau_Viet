# Phase 03 — Design system + AdminShell (AC-5, AC-7)

## Overview
- Priority: P1 · Status: pending · Effort: ~2.5h
- Vietnamese-labeled design system: semantic tokens, accessible primitives, admin shell (sidebar/header/breadcrumbs) per `design/ADMIN_SCREEN_DESIGN.md` §3 and `design/UI_COMPONENT_SPEC.md` §4.

## Files to create

### Design tokens & theme

```
src/app/globals.css                # tailwind base + CSS vars from ART_DIRECTION
tailwind.config.ts                 # (from P01) mapped color/radius/spacing tokens
src/styles/tokens.css              # CSS vars — see below
```

Tokens (semantic, NOT raw hex in components):

```css
--color-brand:        #A51F18;  /* brand.red.700 — CTA, primary */
--color-brand-press:  #751B19;  /* brand.red.900 */
--color-surface:      #FFFBF4;  /* surface.cream — page bg */
--color-surface-alt:  #FFF1D5;  /* surface.parchment — cards */
--color-ink:          #30251F;
--color-ink-muted:    #685F56;
--color-border:       #E7E0D6;  /* derive, muted wood */
--color-error:        #B3261E;
--color-success:      #64824C;
--color-warning:      #E7B451;  /* heritage.gold.500 — used with dark text only */
--radius-sm/md/lg/xl: 8/12/16/24px;
```

Focus ring: `--ring: var(--color-brand)` + `outline: 2px solid` — visible keyboard focus required by AC-7.

### Reusable components (`src/components/`)

```
admin-shell.tsx          A-C01 — sidebar + header + main slot
sidebar.tsx              desktop sticky sidebar, collapsible (collapsed: icons only, persisted via cookie or in-memory — pick in-memory for KISS)
sidebar-mobile.tsx       <md: Sheet (drawer) trigger from header
top-header.tsx           breadcrumbs, status chip, user menu (displayName, role badge, Đăng xuất)
breadcrumbs.tsx          derive from pathname segments; explicit crumb map for known routes
page-header.tsx          A-C02 — title + optional breadcrumb + actions slot
data-table.tsx           A-C03 minimal — table + skeleton rows + empty/error slots; sorting optional client-side
status-chip.tsx          A-C04 — DRAFT/PUBLISHED/ARCHIVED chip variants
empty-state.tsx          "Chưa có dữ liệu" + optional CTA slot
error-state.tsx          "Có lỗi xảy ra" + retry CTA + optional traceId display
forbidden-state.tsx      "Bạn không có quyền truy cập" + back to dashboard
confirm-dialog.tsx       AlertDialog wrapper — title/description/confirmLabel (Vietnamese defaults)
skeleton.tsx             # re-export of shadcn
toast.tsx                # sonner setup + helper `toast.error(err)` that pulls message from ApiClientError
```

### Sidebar nav items (Vietnamese labels, lucide icons)

```
/dashboard    Tổng quan          LayoutDashboard
/events       Sự kiện            Calendar
/lessons      Bài học            BookOpen
/templates    Mẫu bài học        LayoutTemplate
/assets       Thư viện media     Image
/versions     Phiên bản          History (coming soon — see P04)
```

### Accessibility checklist (per component)

- Buttons/links: min 44×44 touch target.
- Status chip: text + icon (not color only).
- Sidebar collapse: keyboard focusable, `aria-expanded`, `aria-label`.
- Mobile nav: `Sheet` opens with hamburger, focus trap, Escape closes.
- Toasts: `aria-live="polite"`.
- Form fields: `Label` + `aria-invalid` + `aria-describedby` → error message id.
- All Vietnamese UI text — no English labels visible to admin users.

## Steps

1. Wire tokens in `tailwind.config.ts` (Phase 01): `colors: { brand, surface, ink, error, ... }` referencing CSS vars via `hsl(var(--color-...))` or hex → keep it simple: CSS vars hold hex, Tailwind `colors` reference `var(--*)`.
2. Build `AdminShell` layout — see `app/(admin)/layout.tsx` in Phase 04 (uses AdminShell + role guard).
3. `data-table.tsx` — minimal generic: `columns: ColumnDef[]`-lite (hand-rolled, NOT `@tanstack/react-table` — YAGNI for this task; plain `<table>` with `thead/tbody`, `loading`, `empty`, `error` props).

## Tests

- `admin-shell.test.tsx` — renders sidebar items, highlights active route (`usePathname` mocked).
- `status-chip.test.tsx` — variants render correct label+color.
- `data-table.test.tsx` — renders fixture rows, empty state.
- `confirm-dialog.test.tsx` — opens, confirm/cancel callbacks fire.
- `breadcrumbs.test.tsx` — maps `/events/abc` → `Sự kiện / abc`.

## Success criteria

- Visual check at `:3000` — sidebar collapses, mobile drawer opens at `<md` viewport.
- All components in `src/components/` ≤ 200 lines.
- Focus-visible ring on all interactive elements (manual verify).
- AC-7 checklist from `UI_COMPONENT_SPEC` §7 satisfied for the components built this task.

## Risks

- Don't over-build: skip `UploadDropzone`, `LearnerPreviewFrame`, `PublishChecklist`, `RuleEditor`, `StageOutline`, `ActivityTypePicker`, `ActivityConfigEditor`, `EvidenceSourceEditor`, `AssetLibraryPicker`, `VersionHistory`, `UnsavedChangesGuard`, `InlineErrorSummary`, `EventEditorForm`, `LessonMetadataForm`, `TemplatePicker`, `ReviewComments` — those belong to the Lesson Builder task, not this foundation.
- Vietnamese diacritics in Be Vietnam Pro — verify full glyph coverage at runtime (manual check on `đ`, `ữ`, `ệ`).
