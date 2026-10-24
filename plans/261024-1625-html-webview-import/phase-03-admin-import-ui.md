---
title: "Phase 03 — Admin import UI (dropzone + BFF upload route)"
description: "Add BFF multipart forwarder for HTML, native drag-drop dropzone component, and 'Import HTML' entry in the library."
status: pending
priority: P1
effort: 2h
---

# Phase 03 — Admin Import UI

## Context Links

- Audit: `plans/reports/researcher-261024-1623-admin-animation-audit.md` (§1, §6, §9, §10)
- BFF precedent: `dau-viet-admin/src/app/api/upload/assets/route.ts`
- Library: `dau-viet-admin/src/features/animations/animation-library.tsx`
- Template picker (existing card-grid pattern): `dau-viet-admin/src/features/animations/template-picker.tsx`
- API client: `dau-viet-admin/src/features/animations/animation-api.ts`
- Asset upload helper (multipart `FormData` + auth): `dau-viet-admin/src/features/assets/asset-api.ts`
- Auth token: `authStore.getAccessToken()` + `coordinatedRefresh()` pattern (see `src/lib/api-client.ts`)
- Middleware: `dau-viet-admin/src/middleware.ts` — `/animations` missing from matcher (fix in this phase).
- Memory: `dau-viet-admin-bff-pitfalls` — origin from `headers()`, no double session fetch.

## Overview

- Priority: P1 — entry point for the whole feature.
- Status: pending.
- Brief: admin clicks "Tải hoạt họa HTML lên" → drag-drops `.html` → BFF forwards to backend → lands on scene editor.

## Key Insights

- Repo has NO dnd library and NO existing dropzone — use native HTML5 drag events + hidden `<input type="file">`.
- `apiFetch` posts through `/api/proxy` (2 MiB cap) — must use dedicated `/api/upload/*` route for >2 MiB (pattern set by `upload/assets/route.ts`).
- `middleware.ts` matcher lacks `/animations` — fix here (one-line) since this feature uses `/animations` heavily.
- `authStore`/`coordinatedRefresh` already abstracted — reuse via small `uploadFormData` helper (copy `uploadAsset` shape, change URL + file field).

## Requirements

### BFF route

`src/app/api/upload/html-scene/route.ts`:

```ts
POST /api/upload/html-scene
  → forwards multipart to ${BACKEND_URL}/api/v1/admin/animation-scenes/html-import
  → MAX_BODY = 16 * 1024 * 1024

PUT /api/upload/html-scene/[id]
  → forwards multipart to ${BACKEND_URL}/api/v1/admin/animation-scenes/{id}/html-draft
```

Mirror the existing route exactly:
- Forward `authorization` + `content-type` headers only.
- Validate `content-type` starts `multipart/form-data`.
- `await req.arrayBuffer()` → `413` if > `MAX_BODY`.
- Strip `set-cookie` + hop-by-hop headers from upstream response.

For the `[id]` PUT route, place at `src/app/api/upload/html-scene/[id]/route.ts`.

### Client helper

Extend `src/features/animations/animation-api.ts`:

```ts
export async function importHtmlScene(file: File, opts: { title?: string; eventId?: string })
  → POST /api/upload/html-scene (FormData: file, title?, eventId?)
export async function replaceHtmlDraft(sceneId: string, file: File, expectedRowVersion: number)
  → PUT /api/upload/html-scene/[id] (FormData: file + query param or body field expectedRowVersion)
```

Both reuse the `uploadAsset` pattern (FormData + Authorization + 401-coordinated-refresh). For `expectedRowVersion`, send as form field (server reads `@RequestParam`) — backend treats FormData fields as params.

### Dropzone component

`src/features/animations/html-import-dropzone.tsx`:

- Controlled component; props `{ onFileAccepted: (file: File) => void; disabled?: boolean }`.
- Hidden `<input type="file" accept=".html,.htm,text/html">`.
- Native handlers: `onDragOver` (preventDefault + set isDragActive), `onDragLeave`, `onDrop` (preventDefault, read `e.dataTransfer.files[0]`).
- Click area → `inputRef.current.click()`.
- Client-side pre-validation (UX only — server still authoritative):
  - Extension `.html|.htm` (case-insensitive) → error "Chỉ chấp nhận tệp .html".
  - `file.size <= 15 * 1024 * 1024` → error "Tệp vượt quá 15 MB".
- Show inline error in Vietnamese; clear on next file select.
- States: idle / dragActive / uploading / error.

### Library integration

In `animation-library.tsx`:
- Add a card row above the `DataTable` (or extend PageHeader with secondary button) → renders `HtmlImportDropzone`.
- On `onFileAccepted`: `importHtmlScene(file)` → on success `router.push('/animations/{id}/edit')` (id from `SceneResponse`).
- On error: surface `errors[]` from 422 response (`HtmlValidationException` shape matches existing `ManifestFieldError`).

### Renderer label

`RENDERER_LABELS` map in `animation-library.tsx` + `template-picker.tsx` needs new entry:

```ts
HTML_WEBVIEW: 'Hoạt họa HTML'
```

The library list groups by template — HTML scenes will appear with this label.

### Middleware fix

Add `"/animations/:path*"` to `middleware.ts` matcher.

## Related Code Files

### Create
- `dau-viet-admin/src/app/api/upload/html-scene/route.ts` (POST)
- `dau-viet-admin/src/app/api/upload/html-scene/[id]/route.ts` (PUT)
- `dau-viet-admin/src/features/animations/html-import-dropzone.tsx`

### Modify
- `dau-viet-admin/src/features/animations/animation-api.ts` — add `importHtmlScene`, `replaceHtmlDraft`, `getHtmlDraftUrl(sceneId)` (returns `/api/proxy/admin/animation-scenes/{id}/html-draft` URL for iframe fetch).
- `dau-viet-admin/src/features/animations/animation-library.tsx` — add dropzone card + `HTML_WEBVIEW` label.
- `dau-viet-admin/src/features/animations/template-picker.tsx` — add `HTML_WEBVIEW` to `RENDERER_LABELS` (keep template-picker filtered to RIVER_TIDE/JOURNEY_MAP — HTML scenes come via dropzone, not picker; matches "no per-scene renderer code" spec).
- `dau-viet-admin/src/middleware.ts` — add `/animations/:path*`.

## Implementation Steps

1. Write `route.ts` POST forwarder (16 MiB cap) + `[id]/route.ts` PUT forwarder.
2. Extend `animation-api.ts` with `importHtmlScene` + `replaceHtmlDraft`.
3. Build `HtmlImportDropzone` component (native DnD + hidden input + client validation).
4. Wire into `AnimationLibrary` — dropzone card above table; on success route to editor.
5. Add `HTML_WEBVIEW` labels to both `RENDERER_LABELS` maps.
6. Update `middleware.ts` matcher.

## Todo

- [ ] POST forwarder route.
- [ ] PUT forwarder route.
- [ ] `importHtmlScene` + `replaceHtmlDraft` in animation-api.
- [ ] `HtmlImportDropzone` component.
- [ ] Library integration + label.
- [ ] Template picker label.
- [ ] Middleware matcher fix.
- [ ] Manual smoke: `pnpm dev`, drop a `.html` → lands on editor page.

## Success Criteria

- Drag-drop `.html` file ≤15 MB → `POST /api/upload/html-scene` → 201 → redirect to `/animations/{id}/edit`.
- Drop `.txt` or `.exe` → client-side error shown, no network call.
- Drop 20 MB `.html` → client-side error shown.
- Drop 16 MB `.html` (just over) → forwarded but backend rejects with 413/422 — error displayed.
- Non-`.html` extension forwarded → backend 422 → `errors[]` displayed.
- `/animations` route is now behind middleware cookie check (verified manually or in test).

## Risks

- `arrayBuffer()` reads whole file into memory — 16 MB is fine for BFF, but do not bump further without streaming.
- Some browsers (Safari) have flaky `dataTransfer` — keep `<input type="file">` fallback always visible.

## Security Considerations

- Client validation is advisory; backend `HtmlDocumentValidator` is authoritative.
- BFF route validates `Authorization` header presence only — real auth on backend; `dv_refresh` cookie never forwarded.
- Do NOT log file contents anywhere (name + size only).
