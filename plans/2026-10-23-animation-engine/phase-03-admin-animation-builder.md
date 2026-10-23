# Phase 3 — Admin Animation Builder (Next.js)

## Context Links

- `dau-viet-admin/package.json` — vitest, Next.js 15, React 19, react-hook-form, zod, @tanstack/react-query
- `dau-viet-admin/src/components/admin-shell.tsx` — NAV_ITEMS array (line 28-37)
- `dau-viet-admin/src/lib/api-client.ts` — `apiFetch` BFF proxy pattern
- `dau-viet-admin/src/lib/dto/lesson.ts` — existing DTO patterns
- `dau-viet-admin/src/features/lessons/builder/activity-editors/read-editor.tsx` — animationKey input (to replace)
- `dau-viet-admin/src/features/assets/asset-picker-dialog.tsx` — AssetPickerDialog component
- `dau-viet-admin/src/features/lessons/builder/builder-page.tsx` — builder patterns
- `dau-viet-admin/src/features/lessons/builder/use-builder.ts` — builder hooks
- `dau-viet-admin/src/features/lessons/builder/draft-model.ts` — draft model types
- `dau-viet-admin/vitest.config.ts` — vitest configuration
- `dau-viet-admin/src/app/api/proxy/[...path]/route.ts` — BFF proxy route

## Overview

- **Priority:** P1
- **Status:** pending
- **Effort:** 5h

Build the no-code Animation Builder in `dau-viet-admin`: nav item, animation library list, template selection, scene editor (form-based, 8 sections), interactive preview, publish flow, and lesson builder integration (replace `animationKey` input with animation picker).

## Key Insights

- Admin uses BFF pattern: browser → `/api/proxy/*` → backend `/api/v1/*`. `apiFetch` handles auth + refresh.
- All admin pages live under `src/app/(admin)/` route group with `AdminShell` wrapper.
- react-hook-form + zod for form validation; @tanstack/react-query for server state.
- AssetPickerDialog already exists — reuse for asset selection in scene editor.
- Preview must render the SAME manifest interactively (canvas/SVG), not a stub. Use the manifest data to draw a simplified but functional preview.
- Vitest is the test runner (`npm test`); Playwright e2e exists but is blocked on Windows port range — skip.

## Requirements

### Functional

1. Nav item "Hoạt họa lịch sử" in `AdminShell` linking to `/animations`.
2. Screen A — Animation Library: searchable/filterable/paginated table of scenes; actions: create, duplicate, archive, publish, validate.
3. Screen B — Template Selection: shows only templates whose `renderer_code` is `RIVER_TIDE` or `JOURNEY_MAP` (and `enabled=true`).
4. Screen C — Scene Editor: form-based (NO raw JSON), 8 collapsible sections:
   - Thông tin chung (title, event, description)
   - Canvas (aspect ratio, dimensions)
   - Assets (list + AssetPickerDialog integration)
   - Objects (add/remove/edit objects table)
   - Trạng thái ban đầu (initialState form — renderer-specific fields)
   - Timeline (steps list — add/delete/reorder/duplicate)
   - Tương tác (interactions config)
   - Xuất bản (publish + validate + version history)
5. Timeline Editor: visual step list with drag handles, step cards showing title/narration/duration/easing; add step → pick easing + duration → edit targetState.
6. River Editor (RIVER_TIDE): waterLevel slider, boat progress slider, boat count, stakes table (id, x, length, visible, highlighted), decoy toggle, counterattack toggle, sequence summary toggle.
7. Journey Map Editor (JOURNEY_MAP): visual marker placement on canvas + normalized X/Y inputs, locations table (id, name, description, contextLabel), routes editor (from/to/via/explanation).
8. Preview: interactive canvas/SVG preview using same manifest data — plays steps, shows state transitions, allows interactions.
9. Publish flow: validate → show errors by path → publish → show new version.
10. Lesson builder: replace `animationKey` input in `read-editor.tsx` with animation picker (select scene → select version → select playbackMode). Keep legacy `animationKey` input visible as fallback for old snapshots.

### Non-functional

- Vietnamese labels throughout, no jargon.
- Preview renders in <100ms for typical manifest (50 objects, 10 steps).
- Form auto-saves draft on blur/interval (following existing builder patterns).
- Accessible: labels, ARIA roles, keyboard navigation.

## Architecture

```
src/app/(admin)/animations/
├── page.tsx                          # Screen A: Animation Library
├── new/page.tsx                      # Screen B: Template Selection
├── [id]/edit/page.tsx                # Screen C: Scene Editor
└── [id]/versions/page.tsx            # Version history

src/features/animations/
├── animation-api.ts                  # apiFetch wrappers for animation endpoints
├── animation-types.ts                # TypeScript types mirroring manifest DTOs
├── animation-library.tsx             # Screen A component
├── template-picker.tsx               # Screen B component
├── scene-editor/
│   ├── scene-editor.tsx              # Screen C root
│   ├── general-section.tsx           # title, event, description
│   ├── canvas-section.tsx            # aspect ratio, dimensions
│   ├── assets-section.tsx            # asset list + picker
│   ├── objects-section.tsx           # objects table
│   ├── initial-state-section.tsx     # renderer-specific initial state
│   ├── timeline-section.tsx          # steps editor
│   ├── interactions-section.tsx      # interactions config
│   ├── publish-section.tsx           # validate + publish buttons
│   ├── river-editor.tsx              # RIVER_TIDE initialState + step targetState editor
│   ├── journey-map-editor.tsx        # JOURNEY_MAP initialState + step targetState editor
│   ├── timeline-step-card.tsx        # single step card
│   └── scene-preview.tsx             # interactive canvas/SVG preview
├── animation-preview/
│   ├── preview-canvas.tsx            # SVG/canvas rendering
│   ├── preview-controls.tsx          # play/pause/step navigation
│   ├── river-preview.tsx             # river scene preview
│   └── map-preview.tsx               # map scene preview
└── use-scene-editor.ts               # editor state hook

src/features/lessons/builder/activity-editors/
└── animation-picker.tsx              # scene + version + playbackMode selector
    (replaces animationKey input in read-editor.tsx)
```

## Related Code Files

### Create

| File | Purpose |
|------|---------|
| `dau-viet-admin/src/app/(admin)/animations/page.tsx` | Library page |
| `dau-viet-admin/src/app/(admin)/animations/new/page.tsx` | Template selection |
| `dau-viet-admin/src/app/(admin)/animations/[id]/edit/page.tsx` | Scene editor |
| `dau-viet-admin/src/app/(admin)/animations/[id]/versions/page.tsx` | Versions |
| `dau-viet-admin/src/features/animations/animation-api.ts` | API client functions |
| `dau-viet-admin/src/features/animations/animation-types.ts` | TypeScript types |
| `dau-viet-admin/src/features/animations/animation-library.tsx` | Library table |
| `dau-viet-admin/src/features/animations/template-picker.tsx` | Template cards |
| `dau-viet-admin/src/features/animations/scene-editor/scene-editor.tsx` | Editor root |
| `dau-viet-admin/src/features/animations/scene-editor/general-section.tsx` | General info |
| `dau-viet-admin/src/features/animations/scene-editor/canvas-section.tsx` | Canvas config |
| `dau-viet-admin/src/features/animations/scene-editor/assets-section.tsx` | Assets + picker |
| `dau-viet-admin/src/features/animations/scene-editor/objects-section.tsx` | Objects table |
| `dau-viet-admin/src/features/animations/scene-editor/initial-state-section.tsx` | Initial state |
| `dau-viet-admin/src/features/animations/scene-editor/timeline-section.tsx` | Timeline editor |
| `dau-viet-admin/src/features/animations/scene-editor/interactions-section.tsx` | Interactions |
| `dau-viet-admin/src/features/animations/scene-editor/publish-section.tsx` | Publish actions |
| `dau-viet-admin/src/features/animations/scene-editor/river-editor.tsx` | River-specific editor |
| `dau-viet-admin/src/features/animations/scene-editor/journey-map-editor.tsx` | Map-specific editor |
| `dau-viet-admin/src/features/animations/scene-editor/timeline-step-card.tsx` | Step card |
| `dau-viet-admin/src/features/animations/scene-editor/scene-preview.tsx` | Preview panel |
| `dau-viet-admin/src/features/animations/animation-preview/preview-canvas.tsx` | SVG canvas |
| `dau-viet-admin/src/features/animations/animation-preview/preview-controls.tsx` | Playback controls |
| `dau-viet-admin/src/features/animations/animation-preview/river-preview.tsx` | River preview |
| `dau-viet-admin/src/features/animations/animation-preview/map-preview.tsx` | Map preview |
| `dau-viet-admin/src/features/animations/use-scene-editor.ts` | Editor hook |
| `dau-viet-admin/src/features/lessons/builder/activity-editors/animation-picker.tsx` | Scene picker |
| `dau-viet-admin/src/features/animations/animation-api.test.ts` | API tests |
| `dau-viet-admin/src/features/animations/scene-editor/timeline-section.test.tsx` | Timeline tests |
| `dau-viet-admin/src/features/animations/animation-preview/river-preview.test.tsx` | Preview tests |

### Modify

| File | Change |
|------|--------|
| `dau-viet-admin/src/components/admin-shell.tsx` | Add "Hoạt họa lịch sử" nav item |
| `dau-viet-admin/src/features/lessons/builder/activity-editors/read-editor.tsx` | Replace animationKey input with AnimationPicker; keep legacy key as collapsible fallback |
| `dau-viet-admin/src/lib/dto/lesson.ts` | Add animation-related types if needed |
| `dau-viet-admin/src/lib/query-keys.ts` | Add animation query keys |

## Implementation Steps

### Step 1: Navigation + Route scaffold

Add to `NAV_ITEMS` in `admin-shell.tsx`:
```typescript
{ href: "/animations", label: "Hoạt họa lịch sử", icon: Film },
```
Import `Film` from lucide-react.

Create the 4 page files under `src/app/(admin)/animations/` — thin wrappers importing feature components.

### Step 2: TypeScript types (`animation-types.ts`)

```typescript
// Mirror backend manifest schema — single source for form + preview
export interface AnimationTemplateDto {
  id: string; code: string; name: string;
  rendererCode: string; schemaVersion: number;
  capabilitiesJson: Record<string, unknown>;
  defaultConfigJson: Record<string, unknown>;
  thumbnailAssetId?: string; enabled: boolean;
}

export interface AnimationSceneDto {
  id: string; templateId: string; eventId?: string;
  title: string; draftJson: AnimationManifest; status: string;
  currentVersionId?: string; rowVersion: number;
}

export interface AnimationManifest {
  schemaVersion: number; rendererCode: string; rendererVersion: number;
  title: string; learningObjective?: string;
  canvas: { aspectRatio: number; width: number; height: number };
  assets: { id: string; assetId: string; role: string }[];
  objects: AnimationObject[];
  initialState: Record<string, unknown>;
  steps: AnimationStep[];
  interactions?: Record<string, unknown>;
  narration?: string;
  sourceReferences?: string[];
  disclaimer?: string;
}

export interface AnimationObject {
  id: string; type: string;
  position: { x: number; y: number };
  scale: number; rotation: number; visible: boolean; layer: number;
}

export interface AnimationStep {
  id: string; title: string; narration?: string; hint?: string;
  durationMs: number; targetState: Record<string, unknown>;
  easing: string; effects: string[];
  interactions?: Record<string, unknown>;
}
```

### Step 3: API client (`animation-api.ts`)

NOTE — verified against implemented `AdminAnimationSceneController` (2026-10-23):
- No separate `PUT /{id}/draft` endpoint — draft updates go through `PATCH /{id}` with `SceneUpdateRequest.draftJson` (one payload can carry title/eventId/draftJson/expectedRowVersion).
- `validate` response shape is `{ready: boolean, errors: {path, code, message}[]}` (no `warnings` field).
- Version list is `List<SceneVersionSummary>` (NOT paginated).
- `SceneResponse.draftJson` is a String (server serializes the JSON column) — client should `JSON.parse` it.

```typescript
export const animationApi = {
  // Templates
  listTemplates: (params) => apiFetch<PageResponse<AnimationTemplateDto>>(`/admin/animation-templates${toQuery(params)}`),
  getTemplate: (id) => apiFetch<AnimationTemplateDto>(`/admin/animation-templates/${id}`),

  // Scenes
  listScenes: (params) => apiFetch<PageResponse<SceneSummaryResponse>>(`/admin/animation-scenes${toQuery(params)}`),
  getScene: (id) => apiFetch<SceneResponse>(`/admin/animation-scenes/${id}`),
  createScene: (data) => apiFetch<SceneResponse>('/admin/animation-scenes', { method: 'POST', body: JSON.stringify(data) }),
  updateScene: (id, data /* {title?, eventId?, clearEvent?, draftJson?, expectedRowVersion?} */) =>
    apiFetch<SceneResponse>(`/admin/animation-scenes/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  // draftJson updates ride on PATCH — set clearEvent:true to unlink event
  duplicate: (id) => apiFetch<SceneResponse>(`/admin/animation-scenes/${id}/duplicate`, { method: 'POST' }),
  validate: (id) => apiFetch<{ready: boolean; errors: {path: string; code: string; message: string}[]}>(`/admin/animation-scenes/${id}/validate`, { method: 'POST' }),
  publish: (id, expectedRowVersion) => apiFetch<PublishResponse>(`/admin/animation-scenes/${id}/publish`, { method: 'POST', body: JSON.stringify({ expectedRowVersion }) }),
  archive: (id) => apiFetch<SceneResponse>(`/admin/animation-scenes/${id}/archive`, { method: 'POST' }),
  listVersions: (id) => apiFetch<SceneVersionSummary[]>(`/admin/animation-scenes/${id}/versions`),
  getVersion: (id, versionId) => apiFetch<SceneVersionDetail>(`/admin/animation-scenes/${id}/versions/${versionId}`),
};
```

### Step 4: Screen A — Animation Library

Table with columns: Title, Template (renderer badge), Event, Status, Version, Updated, Actions (dropdown: Edit, Duplicate, Archive, Publish, Versions, Validate).

Filters: search input (title), template dropdown, status dropdown, event dropdown. Pagination at bottom.

Use existing `DataTable`, `StatusChip`, `PageHeader` components.

### Step 5: Screen B — Template Selection

Grid of template cards: name, description, renderer badge, thumbnail (if any). Only `enabled=true` and `rendererCode ∈ {RIVER_TIDE, JOURNEY_MAP}`.

On select → navigate to `/animations/new?templateId={id}` → create form → POST → redirect to edit.

### Step 6: Screen C — Scene Editor root

`use-scene-editor.ts` hook:
```typescript
export function useSceneEditor(sceneId: string) {
  // Load scene via useQuery
  // Local draft state (AnimationManifest)
  // Auto-save debounce → PUT /draft
  // dirty tracking → unsaved-changes-guard
  // optimistic lock: track rowVersion, send expectedRowVersion
}
```

Collapsible sections using existing patterns (accordion or card-based).

### Step 7: Section components

- **GeneralSection**: title input, event select (from events API), description textarea.
- **CanvasSection**: aspect ratio select (16/10, 16/9, 4/3, 1/1), width/height number inputs.
- **AssetsSection**: list of `{id, assetId, role}` rows; each has AssetPickerDialog trigger + role input + remove button. "Add asset" button.
- **ObjectsSection**: table of objects — id, type (dropdown from whitelist), x/y sliders, scale, rotation, visible toggle, layer number. Add/remove rows.
- **InitialStateSection**: delegates to `RiverEditor` or `JourneyMapEditor` based on `manifest.rendererCode`.
- **TimelineSection**: ordered list of `TimelineStepCard`. Each card: title, narration textarea, hint input, durationMs number, easing dropdown, effects checkboxes, targetState (delegates to renderer-specific editor). Add step button, duplicate button, delete button, reorder via up/down buttons (or drag if feasible).
- **InteractionsSection**: key-value editor for interactions JSON.
- **PublishSection**: "Validate" button → shows errors/warnings; "Publish" button → validates then publishes; version list link.

### Step 8: River Editor

```tsx
// RIVER_TIDE initialState editor
<Slider label="Mực nước" value={initialState.waterLevel} min={0} max={1} step={0.01} />
<Slider label="Tiến độ thuyền" value={initialState.boatProgress} min={0} max={1} step={0.01} />
<NumberInput label="Số thuyền" value={initialState.boatCount} min={1} max={10} />
<StakesTable stakes={initialState.stakes} onChange={...} />
  // Table: id (auto), x slider, length slider, visible checkbox, highlighted checkbox
<Toggle label="Dụ địch" value={initialState.decoyProgress > 0} />
<Toggle label="Phản công" value={initialState.counterattackProgress > 0} />
<Toggle label="Tổng kết chuỗi" value={initialState.showSequenceSummary} />
<Toggle label="Điều khiển nước" value={initialState.hasWaterControl} />
<Toggle label="Vật cản" value={initialState.obstructed} />
```

For step targetState editing: same fields but scoped to the step being edited.

### Step 9: Journey Map Editor

Visual canvas (SVG) showing schematic land area. Click on canvas → add location at normalized (x,y). Locations shown as circles with labels. Click location → select → edit in side panel (name, description, contextLabel). Drag to move (or input x/y).

Routes editor: add route → pick from/to locations → add via points (click on canvas) → explanation input.

```tsx
<MapCanvas
  locations={initialState.locations}
  routes={initialState.routes}
  onAddLocation={(pos) => addLocation(pos)}
  onSelectLocation={(id) => setSelected(id)}
  selectedId={selectedId}
/>
<LocationTable locations={...} selectedId={...} onUpdate={...} onRemove={...} />
<RoutesEditor routes={...} locations={...} onChange={...} />
```

### Step 10: Interactive Preview

`scene-preview.tsx` — right panel or bottom panel:
- `preview-canvas.tsx` renders SVG based on manifest.rendererCode
- `river-preview.tsx`: draws river bed, water rectangle, stakes (rectangles), boats (triangles), water level line. Applies step targetState via simple lerp for preview (no complex tween — just render the end state or a simple animation).
- `map-preview.tsx`: draws land blob, rivers, markers (circles with labels), routes (dashed lines). Shows marker visibility, route progress, highlights.
- `preview-controls.tsx`: play/pause/prev/next/replay — same UX as mobile player.

The preview is NOT a stub — it reads `manifest.steps[].targetState` and renders the actual scene geometry. Simplified rendering (rects/circles/paths) is acceptable as long as it reflects the real data.

### Step 11: Animation Picker for lesson builder

`animation-picker.tsx` replaces the animationKey input in `read-editor.tsx`:

```tsx
export function AnimationPicker({ activity, onChange, readOnly }: Props) {
  const scenes = useQuery(['animation-scenes'], () => animationApi.listScenes({status: 'PUBLISHED'}));
  const versions = useQuery(['animation-versions', selectedSceneId],
    () => animationApi.listVersions(selectedSceneId), {enabled: !!selectedSceneId});

  return (
    <div>
      <Select label="Hoạt họa" value={sceneId} onValueChange={setScene}>
        {scenes.map(s => <SelectItem value={s.id}>{s.title}</SelectItem>)}
      </Select>
      <Select label="Phiên bản" value={versionId} onValueChange={setVersion}>
        {versions.map(v => <SelectItem value={v.id}>v{v.versionNo}</SelectItem>)}
      </Select>
      <Select label="Chế độ phát" value={playbackMode}>
        <SelectItem value="INTERACTIVE">Tương tác</SelectItem>
        <SelectItem value="STEPPED">Từng bước</SelectItem>
        <SelectItem value="AUTO">Tự động</SelectItem>
      </Select>
      {/* Legacy animationKey — collapsible */}
      <Collapsible label="Mã cũ (legacy)">
        <Input value={animationKey} ... />
      </Collapsible>
    </div>
  );
}
```

On change: `onChange({ config: { ...config, animationSceneId, animationSceneVersionId, playbackMode } })`.

### Step 12: Tests

- `animation-api.test.ts` — mock fetch, verify endpoints called correctly.
- `timeline-section.test.tsx` — add/delete/reorder steps produces correct manifest.
- `river-preview.test.tsx` — renders SVG elements for given manifest.

## Todo List

- [ ] Nav item added to AdminShell
- [ ] Route pages created (`/animations`, `/animations/new`, `/animations/[id]/edit`, `/animations/[id]/versions`)
- [ ] `animation-types.ts` — all manifest DTO types
- [ ] `animation-api.ts` — all API functions
- [ ] `AnimationLibrary` — table + filters + pagination + actions
- [ ] `TemplatePicker` — cards for RIVER_TIDE + JOURNEY_MAP
- [ ] `SceneEditor` root + `useSceneEditor` hook
- [ ] `GeneralSection`
- [ ] `CanvasSection`
- [ ] `AssetsSection` + AssetPickerDialog integration
- [ ] `ObjectsSection` — objects table
- [ ] `InitialStateSection` → delegates to renderer editors
- [ ] `TimelineSection` — step cards + add/delete/reorder/duplicate
- [ ] `TimelineStepCard` — single step editor
- [ ] `InteractionsSection`
- [ ] `PublishSection` — validate + publish + errors display
- [ ] `RiverEditor` — waterLevel, boats, stakes, decoy, counterattack
- [ ] `JourneyMapEditor` — visual canvas + locations + routes
- [ ] `ScenePreview` + `PreviewCanvas` + `RiverPreview` + `MapPreview` + `PreviewControls`
- [ ] `AnimationPicker` for lesson builder
- [ ] `read-editor.tsx` — animationKey → AnimationPicker + legacy collapsible
- [ ] Unit tests (vitest)
- [ ] `npm test` passes; `npx tsc --noEmit` passes; `npm run lint` clean

## Success Criteria

- Navigation shows "Hoạt họa lịch sử" → `/animations` loads without errors.
- Create scene → select template → scene created → redirect to editor.
- Editor loads with manifest draft; all 8 sections render.
- Add/edit/remove objects → draft updates → auto-save works.
- Timeline: add step → set duration/easing → reorder → duplicate → delete.
- River editor: sliders update initialState → preview reflects changes.
- Map editor: click canvas → add location → routes connect locations.
- Preview: plays steps, shows transitions, allows interaction.
- Validate → shows field errors by path. Publish → creates version → success toast.
- Lesson builder: animation picker shows scenes → select version → playbackMode.
- `npm test` + `npx tsc --noEmit` + `npm run lint` all pass.

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Preview too complex to build well | Keep preview simple — SVG shapes only, no pixel-perfect match with Flutter. Sufficient for content creators to verify layout/timing. |
| Timeline editor UX too complex for 50 steps | Virtualize list if needed; cap at 50 steps (backend enforced anyway). |
| Objects section too technical for content creators | Use friendly labels: "Vật thể", "Vị trí X/Y", "Hiển thị", "Lớp". Whitelist types as Vietnamese names. |
| Race between draft auto-save and publish | Optimistic lock on expectedRowVersion → 409 shows "Đã có thay đổi, tải lại trang". |

## Security Considerations

- All API calls go through `/api/proxy` → BFF → backend (existing auth pattern). Endpoints verified against `AdminAnimationSceneController` + `AdminAnimationTemplateController` — see Step 3 for shape corrections (PATCH carries draftJson; validate response has no `warnings`; version list is non-paginated).
- Form validation client-side (zod) + server-side (backend validator) — never trust client.
- No raw JSON editing — all manifest edits go through form fields that produce whitelisted values.
- Asset picker only shows ACTIVE assets.

## Next Steps

→ Phase 4: Seed migration, versioning edge cases, security hardening, docs update.
