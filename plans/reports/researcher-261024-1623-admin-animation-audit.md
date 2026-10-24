# Admin Animation Scene Management UI — Audit

Scope: `dau-viet-admin/` (Next.js App Router + TanStack Query + Tailwind + Vitest/MSW).

## 1. Animation Library page
- Route: `src/app/(admin)/animations/page.tsx` — `PageHeader` "+ Tạo hoạt họa mới" → `/animations/new`.
- List component: `src/features/animations/animation-library.tsx` — `AnimationLibrary`. `DataTable` columns: title (link → `/animations/[id]/edit`), `Kiểu cảnh` (templateById → `RENDERER_LABELS[rendererCode]`, fallback template.name), status (`StatusChip`), `Phiên bản` (`v{currentVersionNo}` link → `/animations/[id]/versions`), actions: Soạn / Nhân bản / Lưu trữ.
- Filters: text `q`, `status` (DRAFT/PUBLISHED/ARCHIVED), page size 20.
- Create entry points: header button → `/animations/new`.
- Template picker: `src/features/animations/template-picker.tsx` — `TemplatePicker`. Lists `animationApi.listTemplates({enabled:true, size:100})` filtered client-side to `RENDERER_CODES` (`RIVER_TIDE`, `JOURNEY_MAP`). Two-card grid; select → title input → `createScene({templateId, title, draftJson: JSON.stringify(emptyManifest(rendererCode, rendererVersion))})` → router.push `/animations/{id}/edit`.
- Render-code display: `RENDERER_LABELS` constant in both files (RIVER_TIDE "Sông & thủy triều", JOURNEY_MAP "Hành trình bản đồ").

## 2. Scene editor
- Routes: `src/app/(admin)/animations/[id]/edit/page.tsx` → `SceneEditor` (`src/features/animations/scene-editor.tsx`); `src/app/(admin)/animations/[id]/versions/page.tsx` → `SceneVersionsTable`.
- Editor state: `src/features/animations/use-scene-editor.ts` — `useSceneEditor(sceneId)`. Holds local `manifest`, `title`, `eventId`, `dirty`. `save.mutate` → `updateScene` PATCH `{title, eventId, clearEvent, draftJson, expectedRowVersion}` (optimistic lock → 409 conflict banner). No autosave; `beforeunload` warn on dirty.
- Sections (in render order, all collapsible `<Section>`):
  - `GeneralSection` (title, eventId select from `/admin/events`, learningObjective, disclaimer)
  - `CanvasSection` (aspectRatio select)
  - `AssetsSection` (manifest.assets rows + `AssetPickerDialog`)
  - `ObjectsSection` (manifest.objects rows)
  - Renderer-conditional section: `isRiver` ? `RiverStakesEditor` : `JourneyMapEditor` (both in `renderer-editors.tsx`; JourneyMapEditor has click-to-place SVG canvas)
  - `TimelineSection` (steps CRUD/reorder/duplicate; per-step fields incl. effects checklist `EffectsChecklist`, `allowedInteractions` checkboxes, per-step `targetState` via `RiverStateFields` / `MapStateFields`)
  - `InteractionsSection` (manifest.interactions + nested `PredictionEditor` when PREDICTION enabled)
  - v2 cinematic sections (always rendered, internally gated on `manifest.camera`/etc.): `CameraSection`, `TracksSection`, `EffectsSection`, `AudioSection`; `EnvironmentSection` only when `isRiver`. `patchV2` auto-bumps `schemaVersion`→2 on first v2 key.
  - "Trạng thái ban đầu" Section: `RiverStateFields` or `MapStateFields` on `initialState`
  - `SourcesSection` (`sourceReferences[]`)
  - `PublishSection` (validate → publish, archive)
- Event picker: `GeneralSection` fetches `/admin/events?size=100` into a `<Select>` — no dedicated picker component; plain Select of `events.content`.

## 3. Preview
- `src/features/animations/scene-editor/scene-preview.tsx` — `ScenePreview({manifest})`. Live DOM/SVG reimplementation (NOT iframe, NOT Flutter). rAF playback state machine (idle/playing/paused/finished); `RiverPreview` + `MapPreview` render `<svg>` scenes; `ProceduralGlyph` SVG glyphs for STAKE/BOAT/DECOY/MARKER/LOCATION/LABEL/WATER types; `ManifestImage` loads object/background assets via `useAssetObjectUrl('/api/v1/admin/assets/{id}/content')` → BFF.
- Cinematic evaluator: `src/features/animations/preview/cinematic-eval.ts` — pure-TS port declared as PARITY CONTRACT with Flutter `cinematic_state.dart` (camera, tracks, effects, `lerpSceneState`).
- No iframe/embed of the Flutter app. No web code path to the actual Flutter `CustomPainter`.

## 4. Publish flow UI
- `src/features/animations/scene-editor/publish-section.tsx` — `PublishSection`. Buttons: `Kiểm tra cảnh` (validateScene POST), `Xuất bản phiên bản mới` (publish → re-validate then `publishScene(id, rowVersion)`; rowVersion pulled fresh from query cache `qk.animationScenes.detail(id)`), `Lưu trữ cảnh` (when status=PUBLISHED). Inline `SceneFieldError[]` list (path/code/message). Success → "Đã xuất bản phiên bản v{versionNo}" + link → `/animations/{id}/versions`.
- Versions list: `src/features/animations/scene-versions.tsx` — `SceneVersionsTable({sceneId})`. Columns: v{versionNo}, `{rendererCode} v{rendererVersion}`, `publishedAt` locale, `manifestChecksum` first 12 chars.
- Version display in library: column "Phiên bản" `v{currentVersionNo}` link → versions page.

## 5. AnimationPicker (lesson builder)
- File: `src/features/lessons/builder/activity-editors/animation-picker.tsx` — `AnimationPicker({config, readOnly, onConfigChange})`. Used only by `read-editor.tsx` for READ activities.
- Lists `animationApi.listScenes({status:'PUBLISHED', size:50, q})` filtered client-side to `currentVersionId != null`; auto-fetches currently-selected scene by id (could be outside page).
- Writes to activity.config: `animationSceneId`, `animationSceneVersionId` (pins `currentVersionId`), `playbackMode` (AUTO|STEPPED|INTERACTIVE). Selecting empty deletes all three; selecting a scene deletes legacy `animationKey`. Legacy `animationKey` text input behind a collapsible for backward compat.
- Lesson payload: keys sit on `config` (part of activity JSON), not a separate field.

## 6. API client layer
- `src/lib/api-client.ts` — `apiFetch(path, init)` posts to `/api/proxy{path}` with Bearer from `authStore.getAccessToken()` + `coordinatedRefresh()` on 401. `toQuery` builds querystring.
- BFF: `src/app/api/proxy/[...path]/route.ts` — generic forwarder to `${BACKEND_URL}/api/v1/{path}`; strips hop-by-hop headers; 2 MiB body cap.
- Auth: refresh-token `dv_refresh` httpOnly cookie (never forwarded); access token in memory. `src/middleware.ts` only checks `dv_refresh` cookie presence for protected paths.
- Multipart precedent: `src/app/api/upload/assets/route.ts` — dedicated POST forwarder for multipart to `/api/v1/admin/assets` (12 MB cap, validates `multipart/form-data`); client helper `uploadAsset(file, altText)` in `src/features/assets/asset-api.ts` (uses `FormData`, single-flight refresh identical to apiFetch). Image types only (PNG/JPEG/WebP ≤10 MB). Audio upload not yet implemented (audio asset role exists in manifest schema but `validateAssetFile` rejects audio MIME).
- Scene API endpoints (in `src/features/animations/animation-api.ts`): GET/POST/PATCH `/admin/animation-scenes`, POST `/{id}/duplicate|validate|publish|archive`, GET `/admin/animation-templates`, GET `/{id}/versions[/{versionId}]`.

## 7. Duplicate-scene UI
- `AnimationLibrary` row action `Nhân bản` → `animationApi.duplicateScene(id)` (POST `/{id}/duplicate`) → `router.push('/animations/{newId}/edit')`.
- `TimelineSection` has per-step `Nhân bản` (`Copy` icon) — duplicates a step in-memory, not the scene.

## 8. Tests
- Config: `vitest.config.ts` (jsdom, globals, alias `@`→src, setup `vitest.setup.ts` boots MSW server `onUnhandledRequest:'error'`); `playwright.config.ts` exists separately.
- MSW fixtures/handlers: `src/test/msw/handlers.ts` — `/api/proxy/admin/animation-scenes` + `/:id`; `src/test/fixtures.ts` — `animationScenesPageFixture`.
- Scene-related tests:
  - `src/features/animations/animation-types.test.ts` — `emptyManifest`, `parseDraft` purity tests.
  - `src/features/animations/scene-preview.test.tsx` — `ScenePreview` render + full rAF playback state machine (mocked `requestAnimationFrame`/`performance.now`; single-loop invariant).
  - `src/features/animations/preview/cinematic-eval.test.ts` — evaluator math.
  - `src/features/lessons/builder/activity-editors/animation-picker.test.tsx` — list/pin/legacy-key flows via MSW.
- No tests for `animation-library`, `template-picker`, `scene-editor`, `publish-section`, `scene-versions`, `use-scene-editor`, `timeline-section`, `cinematic-sections`, `renderer-editors`.

## 9. Drag-and-drop / file-upload components
- File upload: `<input type="file" hidden>` triggered by button — `src/features/assets/assets-library.tsx` and `src/features/assets/asset-picker-dialog.tsx`. No drag-and-drop anywhere (no dnd-kit, no react-dropzone, no HTML5 DnD handlers found via grep).
- Reorder UX: arrow Up/Down buttons in `TimelineSection` (`ArrowUp`/`ArrowDown` lucide icons) — no dnd.

## 10. next.config / CSP / middleware
- `next.config.mjs` — only `reactStrictMode: true`. No CSP, no `headers()`, no `images` config.
- No `X-Frame-Options`, `frame-ancestors`, or CSP anywhere in the repo (grep negative). No iframe usage anywhere.
- `src/middleware.ts` — presence-only `dv_refresh` cookie guard; matcher: `/dashboard|/events|/lessons|/templates|/assets|/versions`. **Note: `/animations` is NOT in the matcher** — anim routes are reachable without the cookie (API calls will still 401 → /login via apiFetch, but pages aren't gate-checked at edge).
