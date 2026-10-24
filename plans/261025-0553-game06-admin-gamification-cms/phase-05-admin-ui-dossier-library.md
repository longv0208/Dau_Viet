# Phase 05 — Admin UI: Dossier Library + Editor

## Context Links

- Spec: Module B — trang `/dossiers` + editor.
- Patterns tham chieu: `src/app/(admin)/evidence/page.tsx` + `evidence-table.tsx` + `evidence-form-sections.tsx`, `src/app/(admin)/items/page.tsx` + `item-detail.tsx`.
- Sidebar: `src/components/admin-shell.tsx` — them NAV_ITEMS entry.
- AssetPickerDialog: `src/features/assets/asset-picker-dialog.tsx` (da co — reuse).
- DTO dung chung tu Phase 04 (`lib/dto/gamification.ts`).

## Overview

- Priority: P1
- Status: pending
- Effort: 4h
- Trang `/dossiers` (library): table + filter type/status + search + pagination + column event count/version/updatedAt + action "Tao bo suu tap".
- Trang `/dossiers/[id]` (editor): form tung field — canonicalCode (immutable sau create), dossierType, title, summary, description, source{title,author,citation,url,reliability}, assetId (Asset Picker), status chip + version history list + linked events list. Button "Xuat ban" (validate + publish), "Luu", "Luu tru" (archive).

## Key Insights

- `canonicalCode` immutable sau create — field read-only tren edit, chi editable tren `/dossiers/new`. Frontend hien cung nhung disable.
- Dossier PUBLISHED + da co thay doi khong publish -> badge "Co thay doi chua publish" — backend expose qua `latestPublishedVersion` vs `dossierVersion` hien tai trong detail.
- Source la structured — tung Input, KHONG textarea JSON.
- Version history: table don gian (version, publishedAt, status) tu `versions[]` trong detail.
- Linked events: GET `/admin/events/{eventId}/dossiers` tu phia dossier khong co san — can endpoint `GET /admin/dossiers/{id}` tra `events: [{eventId, eventTitle, displayOrder}]` (Phase 02 da bao gom).

## Requirements

### `/dossiers` page

- PageHeader "Bo suu tap lich su" + button "Tao bo suu tap".
- Filters: type (`PERSON|LOCATION|ARTIFACT|CONTEXT`), status (`DRAFT|PUBLISHED|ARCHIVED`), `q` search.
- DataTable columns: Title (link detail), Canonical code, Type, Status chip, So event, Version, UpdatedAt, Actions.
- Pagination.

### `/dossiers/new` page

- Form create: canonicalCode (slug validate client `^[a-z0-9][a-z0-9-]{1,119}$`), dossierType select, title, summary textarea, description textarea, source fields (title*, author, citation, url, reliability select HIGH/MEDIUM/LOW/UNASSESSED), assetId picker.
- Submit -> POST `/admin/dossiers` -> redirect `/dossiers/{id}`.
- 409 conflict -> error "Ma canonical da ton tai".

### `/dossiers/[id]` page

- Card "Thong tin": canonicalCode (read), dossierType select, title, summary, description.
- Card "Nguon tham khao": source fields.
- Card "Hinh anh": AssetPicker + preview.
- Card "Cac su kien lien ket": table `eventTitle + displayOrder` (read-only o day — sua o Event workspace).
- Card "Lich su phien ban": table `version, publishedAt`.
- Action bar: status chip + "Luu" + "Xuat ban" + "Luu tru" + (PUBLISHED -> show "Draft changes" neu `dossierVersion > max(published)`).

## Architecture

### Files moi

| File | Muc dich |
|------|----------|
| `src/app/(admin)/dossiers/page.tsx` | Library list. |
| `src/app/(admin)/dossiers/new/page.tsx` | Create form. |
| `src/app/(admin)/dossiers/[id]/page.tsx` | Editor. |
| `src/features/dossiers/dossiers-table.tsx` | Filter + DataTable. |
| `src/features/dossiers/dossier-create-form.tsx` | Form create. |
| `src/features/dossiers/dossier-detail.tsx` | Editor + actions. |
| `src/features/dossiers/dossier-source-fields.tsx` | Source fieldset (reused create + edit). |
| `src/features/dossiers/dossier-versions-table.tsx` | List versions. |
| `src/features/dossiers/dossier-events-card.tsx` | Linked events. |

### Files sua

- `src/components/admin-shell.tsx` — them `{ href: "/dossiers", label: "Bo suu tap lich su", icon: BookMarked }` vao `NAV_ITEMS` (import `BookMarked` tu lucide-react).
- `src/lib/query-keys.ts` — da them `qk.dossiers` o Phase 04.

## Implementation Steps

1. `dossiers-table.tsx` — filter + DataTable + pagination.
2. `dossier-create-form.tsx` — Zod schema + fields.
3. `dossier-source-fields.tsx` — fieldset.
4. `dossier-detail.tsx` — load `qk.dossiers.detail(id)`, form update, publish/archive mutations.
5. `dossier-versions-table.tsx` + `dossier-events-card.tsx`.
6. Pages: list + new + detail.
7. Sidebar update.
8. Typecheck + vitest co ban.

## Todo List

- [ ] `dossiers-table.tsx`.
- [ ] `dossier-source-fields.tsx`.
- [ ] `dossier-create-form.tsx` + `/dossiers/new` page.
- [ ] `dossier-detail.tsx` + `/dossiers/[id]` page.
- [ ] `dossier-versions-table.tsx` + `dossier-events-card.tsx`.
- [ ] `/dossiers` page.
- [ ] Sidebar entry.
- [ ] typecheck + vitest.

## Success Criteria

- `/dossiers` hien table + filters hoat dong.
- Create dossier thanh cong -> redirect detail.
- Edit + publish -> `dossierVersion` tang + row moi trong versions.
- Archive -> status chip ARCHIVED, khong mat data.
- Duplicate canonicalCode -> 409 hien ro.

## Risk Assessment

- **Table render size**: dossier nhieu -> pagination co san.
- **Form dirty warning**: dung `UnsavedChangesGuard` (co san).

## Security Considerations

- Admin only. Khong log canonical_code hay source vao console.
- Zod validate truoc khi gui — backend van la authority.

## Next Steps

- Phase 04 dossier picker dung `/admin/dossiers?status=PUBLISHED`.
- Phase 08 them vitest cho table + form.
