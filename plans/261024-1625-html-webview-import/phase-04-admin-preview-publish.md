---
title: "Phase 04 — Admin HTML scene editor (preview + publish)"
description: "Render HtmlSceneEditor when rendererCode==HTML_WEBVIEW: title/event/file info, sandboxed iframe preview, replace-file, publish."
status: pending
priority: P1
effort: 2h
---

# Phase 04 — Admin HTML Scene Editor

## Context Links

- Audit: `plans/reports/researcher-261024-1623-admin-animation-audit.md` (§2, §3, §4, §5)
- Scene editor: `dau-viet-admin/src/features/animations/scene-editor.tsx`
- Editor hook: `dau-viet-admin/src/features/animations/use-scene-editor.ts`
- Publish UI: `dau-viet-admin/src/features/animations/scene-editor/publish-section.tsx`
- Preview precedent: `dau-viet-admin/src/features/animations/scene-editor/scene-preview.tsx` (DOM/SVG re-implementation — do NOT reuse for HTML; use iframe).
- Picker: `dau-viet-admin/src/features/lessons/builder/activity-editors/animation-picker.tsx` (no changes needed if it lists PUBLISHED scenes — verify it shows renderer label).
- Existing file upload pattern: `dau-viet-admin/src/features/assets/asset-picker-dialog.tsx`

## Overview

- Priority: P1.
- Status: pending.
- Brief: when `rendererCode === 'HTML_WEBVIEW'`, render a simplified editor (title, event, file info, sandboxed preview, replace, publish) instead of the manifest sections.

## Key Insights

- The existing `use-scene-editor.ts` handles `title`, `eventId`, `dirty`, `save.mutate` → `updateScene` PATCH. Reuse it unchanged — HTML scenes only edit title + eventId via PATCH (draft_json is auto-generated, not user-edited).
- `ScenePreview` is a full TS reimplementation — for HTML we do NOT want parity (the HTML itself IS the source of truth). Use `<iframe sandbox="allow-scripts">` + `srcDoc` (or `src` to blob URL fetched from `GET /admin/animation-scenes/{id}/html-draft`).
- `sandbox="allow-scripts"` — scripts run (needed for animations), but NO `allow-same-origin` → no DOM access to parent, no cookies, no forms, no popups, no top-navigation.
- Blob URL approach: `fetch('/api/proxy/admin/animation-scenes/{id}/html-draft')` → `blob()` → `URL.createObjectURL` → `iframe.src = blobUrl`. This keeps raw bytes out of admin origin and lets iframe load independently. Alternative `srcDoc` requires serializing 15 MB into DOM attribute — blob URL is cleaner.
- `PublishSection` is reusable as-is (it calls `validateScene` + `publishScene` on the scene id — works for HTML since backend handles it).
- `AnimationPicker` filters `status: 'PUBLISHED'` — HTML scenes appear automatically once published; ensure `RENDERER_LABELS['HTML_WEBVIEW']` shows so admin can identify.

## Requirements

### `HtmlSceneEditor` component

`src/features/animations/scene-editor/html-scene-editor.tsx` — props `{sceneId, scene, manifest, onDirty}`:

Sections (collapsible `Section` components reused):
1. **General**: title input + event select (reuse `GeneralSection` internals — extract `EventSelect` if needed, or replicate minimal field set).
2. **File info**: name, size (KB/MB), sha256 (first 12 chars), `draft`/`published` status chip.
3. **Preview**: iframe + viewport toggle buttons (`Mobile 390`, `Desktop`, `16:9`, `4:3`) + reload button.
   - iframe `sandbox="allow-scripts"`, `src` = blob URL created once per file revision.
   - Show loading spinner while fetching draft HTML.
4. **Replace file**: small inline `HtmlImportDropzone` (compact mode) → `replaceHtmlDraft` → refresh iframe + bump `rowVersion`.
5. **Publish**: reuse `PublishSection` (validate → publish → archive).
6. **Versions**: link to `/animations/{id}/versions`.

Hide (do not render) for HTML scenes:
- `CanvasSection`, `AssetsSection`, `ObjectsSection`, `RiverStakesEditor`, `JourneyMapEditor`, `TimelineSection`, `InteractionsSection`, `CameraSection`, `TracksSection`, `EffectsSection`, `AudioSection`, `EnvironmentSection`, `SourcesSection`, `InitialState`.

### `use-scene-editor.ts` adjustments

- No structural changes — `manifest` will be the minimal HTML draft_json. The hook's `dirty` flag tracks title/event changes only.
- Add helper `isHtmlScene = scene.rendererCode === 'HTML_WEBVIEW'` exported from hook or from `animation-types.ts`.

### Scene editor dispatch

In `scene-editor.tsx` near top of render:

```tsx
if (scene.rendererCode === 'HTML_WEBVIEW') {
  return <HtmlSceneEditor sceneId={id} scene={scene} manifest={manifest} onDirty={setDirty} />;
}
// ... existing manifest-driven editor
```

### `useHtmlDraft` hook (new, small)

```ts
function useHtmlDraft(sceneId: string, enabled: boolean): { blobUrl: string | null; loading; error; reload(); }
```

- `useEffect` on `[sceneId, reloadKey]`: `fetch('/api/proxy/admin/animation-scenes/{sceneId}/html-draft', {headers: {Authorization: Bearer}})` → `res.blob()` → `URL.createObjectURL`.
- Cleanup `URL.revokeObjectURL` on unmount/reload.
- Use `apiFetch` (already handles auth/refresh) but with `responseType: 'blob'` — check `apiFetch` signature; if it forces JSON, use `fetch` + `authStore.getAccessToken()` + `coordinatedRefresh()` manually (same pattern as `uploadAsset`).

### AnimationPicker verification

- `animation-picker.tsx` already lists `status:'PUBLISHED'` and groups by template — no code change expected.
- Add `HTML_WEBVIEW` to `RENDERER_LABELS` map (file `animation-picker.tsx` or shared `animation-types.ts` — pick one canonical location; the audit shows `RENDERER_LABELS` duplicated in `animation-library.tsx` + `template-picker.tsx`, suggest extracting to `animation-types.ts` but only if it doesn't break existing imports — keep as duplication if extraction is risky for this phase).

## Related Code Files

### Create
- `dau-viet-admin/src/features/animations/scene-editor/html-scene-editor.tsx`
- `dau-viet-admin/src/features/animations/scene-editor/use-html-draft.ts` (small hook file)

### Modify
- `dau-viet-admin/src/features/animations/scene-editor.tsx` — dispatch to `HtmlSceneEditor`.
- `dau-viet-admin/src/features/animations/use-scene-editor.ts` — expose `rendererCode` cleanly (likely already on `scene` object — verify).
- `dau-viet-admin/src/features/animations/animation-types.ts` — if `RENDERER_LABELS` lives here, add `HTML_WEBVIEW` once; else add to both files.
- `dau-viet-admin/src/features/lessons/builder/activity-editors/animation-picker.tsx` — confirm `RENDERER_LABELS` includes `HTML_WEBVIEW` (or share).

## Implementation Steps

1. Write `useHtmlDraft` hook (fetch blob, manage URL lifecycle, expose reload).
2. Write `HtmlSceneEditor` — layout + sections + iframe + replace + publish.
3. Dispatch in `scene-editor.tsx`.
4. Add `HTML_WEBVIEW` to `RENDERER_LABELS` (all locations).
5. Verify `AnimationPicker` shows published HTML scenes (no code change if list is generic).
6. Manual smoke: upload → editor shows iframe → publish → picker shows scene.

## Todo

- [ ] `useHtmlDraft` hook.
- [ ] `HtmlSceneEditor` component.
- [ ] Dispatch in scene-editor.
- [ ] `RENDERER_LABELS` updated everywhere.
- [ ] `HtmlImportDropzone` reused in compact mode.
- [ ] Publish flow works end-to-end for HTML scenes.
- [ ] `AnimationPicker` shows HTML scene with correct label.

## Success Criteria

- `/animations/{id}/edit` for an HTML scene renders title input, event select, file info (name/size/sha256), iframe preview, replace dropzone, and PublishSection.
- iframe has `sandbox="allow-scripts"` attribute and NO `allow-same-origin`.
- Viewport toggles resize the iframe (390px mobile / 100% desktop / 16:9 / 4:3).
- Reload button refetches draft HTML (new blob URL).
- Replace file → dropzone → `PUT /{id}/html-draft` → iframe refreshes with new bytes.
- `PublishSection` "Xuất bản phiên bản mới" produces version (visible at `/animations/{id}/versions`).
- Lesson Builder `AnimationPicker` lists the published HTML scene under label "Hoạt họa HTML".

## Risks

- `URL.createObjectURL` on 15 MB blob — modern browsers handle; ensure revoke on cleanup to prevent memory leak.
- iframe sandbox blocks `localStorage`/`cookies` — animations that need persistence will not work; document in HTML_ANIMATION_GUIDE (Phase 07).
- `allow-scripts` + blob URL is safe because blob inherits OPAQUE origin (no parent DOM/cookies).

## Security Considerations

- NO `allow-same-origin` — critical: prevents script accessing admin cookies/storage.
- Blob URL is same-origin but iframe sandbox still treats it as opaque origin (no `allow-same-origin`).
- Admin preview ONLY accessible to `CONTENT_ADMIN` role via `/api/v1/admin/animation-scenes/{id}/html-draft`.
