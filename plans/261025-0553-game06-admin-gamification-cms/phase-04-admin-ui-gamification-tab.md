# Phase 04 — Admin UI: Gamification Tab trong Event Workspace

## Context Links

- Spec: Gamification tab ket hop Module A (policy editor) + Module B dossier linking.
- Workspace: `dau-viet-admin/src/features/events/workspace/event-workspace-page.tsx` + `event-workspace-tabs.tsx` + `types.ts` — them tab `gamification`.
- Api: `lib/api-client.ts` `apiFetch`; query keys `lib/query-keys.ts` them `qk.policies`, `qk.eventDossiers`.
- UI shared: `components/ui/{button,card,input,label,select,dialog,skeleton}`, `confirm-dialog.tsx`, `error-state.tsx`, `data-table.tsx`, `page-header.tsx`, `status-chip.tsx`, `unsaved-changes-guard.tsx`.

## Overview

- Priority: P1
- Status: pending
- Effort: 5h
- Tab moi `?tab=gamification` tai `/events/[id]` gom 3 section: (1) Completion Policy — list versions + editor DRAFT + publish; (2) Dossiers linked — list + picker + reorder + remove; (3) Reconcile trigger (optional, neu con scope).

## Key Insights

- Event workspace dung `parseEventTab` whitelist — them `"gamification"` vao union + `EVENT_WORKSPACE_TABS` + render.
- Policy editor: pick lesson tu `/admin/lessons?eventId=&status=PUBLISHED` (da co endpoint). Multi-select → list cua checkbox hoac dual-list. Don gian nhat: checklist + add/remove.
- Validate endpoint tra `errors[]` + `warnings[]` + `diff` — hien ro truoc khi admin bam publish.
- Dossier link UI dung GET `/admin/dossiers?status=PUBLISHED&q=` de pick dossier (search picker dialog).
- Reorder `displayOrder`: simple up/down buttons (khong dnd — KISS, dnd la scope creep).
- Unsaved-changes-guard hien co — dung cho form dirty state.

## Requirements

### Tab Gamification (`/events/[id]?tab=gamification`)

Layout:

```
+--------------------------------------------------------------+
| [Banner: policy PUBLISHED hien tai hoac "Chua cau hinh"]     |
+--------------------------------------------------------------+
| Section 1: Chinh sach hoan thanh su kien                     |
|  - Table: policyVersion, status, threshold, publishedAt      |
|    + so required/optional, actions [Xem] [Sua (DRAFT)]       |
|    [Publish (DRAFT)]                                          |
|  - Button: "Tao draft moi" (khi chua co draft)              |
+--------------------------------------------------------------+
| Section 2: Bo suu tap lien ket                                |
|  - Table: dossier title, canonicalCode, type, status,        |
|    displayOrder (up/down), action [Go]                        |
|  - Button: "Lien ket bo suu tap" -> dialog picker            |
+--------------------------------------------------------------+
```

### Policy Draft Editor (inline expand hoac dialog)

- Multi-select `requiredLessonIds` tu lessons PUBLISHED cua event (GET `/admin/lessons?eventId={id}&status=PUBLISHED&size=100`).
- Multi-select `optionalLessonIds` (cung nguon) — auto-exclude lessons da chon o required.
- `masteryThreshold` number input 0-100 (nullable — checkbox "Su dung nguong mastered").
- "Kiem tra" -> POST `/validate` -> hien errors/warnings inline (khong submit).
- "Luu draft" -> POST (tao moi) hoac PUT (sua draft).
- "Xuat ban" -> POST `/publish` -> confirm dialog hien `diff` tu validate response.

### Dossier Picker Dialog

- Input search `q`, filter `type`, list ket qua tu `/admin/dossiers?status=PUBLISHED`.
- Chon 1 dossier -> them vao list local (chua save).
- "Luu" -> PUT `/admin/events/{eventId}/dossiers` voi list + displayOrder = index.

### Remove link

- Confirm dialog "Go khoi su kien? Learner da mo se giu quyen." -> cap nhat list -> PUT.

## Architecture

### Files moi (admin)

| File | Muc dich |
|------|----------|
| `src/lib/dto/gamification.ts` | DTO `AdminCompletionPolicy`, `AdminPolicyUpsertRequest`, `AdminPolicyValidation`, `AdminDossierSummary`, `AdminEventDossierLink`, `AdminDossierUpsert`. |
| `src/features/events/workspace/event-gamification-tab.tsx` | Root tab component. |
| `src/features/events/workspace/gamification/policy-list.tsx` | Table cac version policy. |
| `src/features/events/workspace/gamification/policy-editor.tsx` | Draft form. |
| `src/features/events/workspace/gamification/policy-publish-dialog.tsx` | Confirm + diff preview. |
| `src/features/events/workspace/gamification/dossier-link-table.tsx` | Linked dossiers + reorder/remove. |
| `src/features/events/workspace/gamification/dossier-picker-dialog.tsx` | Search + chon dossier PUBLISHED. |

### Files sua (admin)

| File | Sua |
|------|-----|
| `src/features/events/workspace/types.ts` | them `"gamification"` vao union + `EVENT_WORKSPACE_TABS` + `parseEventTab`. |
| `src/features/events/workspace/event-workspace-page.tsx` | render `<EventGamificationTab event={event}/>` cho tab `gamification`. |
| `src/lib/query-keys.ts` | them `qk.policies.list(eventId)`, `qk.eventDossiers(eventId)`, `qk.dossiers.list(params)`, `qk.dossiers.detail(id)`. |

### Query keys moi

```ts
policies: {
  list: (eventId: string) => ["policies", "list", eventId] as const,
},
eventDossiers: (eventId: string) => ["event-dossiers", eventId] as const,
dossiers: {
  list: (params?: { page?: number; size?: number; type?: string; status?: string; q?: string }) =>
    ["dossiers", "list", params ?? {}] as const,
  detail: (id: string) => ["dossiers", "detail", id] as const,
},
```

## Implementation Steps

1. `lib/dto/gamification.ts` — DTO mirror `AdminCompletionPolicyDtos` + `AdminDossierDtos`.
2. `lib/query-keys.ts` — them keys.
3. `types.ts` — them tab.
4. `event-gamification-tab.tsx` — root, fetch `policies.list` + `eventDossiers`, render 2 section.
5. `policy-list.tsx` — DataTable: version/status/threshold/counts/publishedAt; row actions.
6. `policy-editor.tsx` — form: 2 multi-select (required/optional) + threshold + validate + save/publish buttons.
7. `policy-publish-dialog.tsx` — show diff (required +/- optional +/- threshold cu/moi), warnings, confirm.
8. `dossier-link-table.tsx` — list + reorder + remove (confirm).
9. `dossier-picker-dialog.tsx` — search dialog, chon dossier.
10. `event-workspace-page.tsx` — wire tab.
11. Typecheck + test UI (`npm run typecheck`, `npm run test`).

## Todo List

- [ ] `lib/dto/gamification.ts`.
- [ ] `query-keys.ts` update.
- [ ] Tab types + wiring.
- [ ] `event-gamification-tab.tsx`.
- [ ] `policy-list.tsx` + `policy-editor.tsx` + `policy-publish-dialog.tsx`.
- [ ] `dossier-link-table.tsx` + `dossier-picker-dialog.tsx`.
- [ ] typecheck pass; vitest co ban (hien thi tab, editor renders, publish confirm dialog).

## Success Criteria

- `/events/[id]?tab=gamification` render 2 section.
- Tao DRAFT moi tu PUBLISHED hien tai (copy values) + luu + publish -> backend tra version moi, list refresh.
- Validate hien errors ro rang; publish bi chan khi `valid=false`.
- Link/unlink dossier + reorder luu qua PUT; UI giu da sau F5.
- Khong crash khi event khong co lesson PUBLISHED (empty picker).

## Risk Assessment

- **Lesson picker data size**: event co nhieu lesson -> pagination trong picker (page size 100 hien tai; neu can them search input — chap nhan MVP).
- **Stale policy list**: invalidation sau save/publish — dung `qc.invalidateQueries(qk.policies.list(eventId))`.
- **Two draft editors cung luc**: rely backend — PUT draft khong ton tai tra 404 -> hien error + reload.

## Security Considerations

- Endpoint admin — `apiFetch` attach JWT tu dong (cookie + Authorization header qua BFF).
- Khong gui PII trong request; chi lesson/dossier ids.
- Khong render stack trace.

## Next Steps

- Phase 05 tuong tu cho dossier detail page.
- Phase 06 cho rule builder.
