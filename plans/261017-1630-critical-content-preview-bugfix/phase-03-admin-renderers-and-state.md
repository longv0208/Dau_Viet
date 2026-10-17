# Phase 03 — Admin renderers & state

## Context Links

- `dau-viet-admin/src/features/lessons/builder/activity-editors/multiple-choice-editor.tsx`
- `dau-viet-admin/src/features/lessons/preview/renderers/types.ts`
- `dau-viet-admin/src/features/lessons/preview/renderers/choice-renderers.tsx`
- `dau-viet-admin/src/features/lessons/preview/renderers/interaction-renderers.tsx`
- `dau-viet-admin/src/features/lessons/preview/renderers/assessment-renderers.tsx`
- `dau-viet-admin/src/features/lessons/preview/activity-renderer.tsx`
- `dau-viet-admin/src/features/lessons/preview/stage-view.tsx`
- `dau-viet-admin/src/features/lessons/preview/preview-page.tsx`
- `dau-viet-admin/src/features/lessons/builder/publish-readiness-card.tsx`
- `dau-viet-admin/src/features/lessons/builder/builder-page.tsx`
- `dau-viet-admin/src/features/lessons/preview/preview-renderers.test.tsx`

## Overview

- Priority: P1
- Status: pending
- Fix MC editor to write canonical `correctOptionIds`+`multiSelect`; update MATCHING/DRAG_ORDER preview renderers for new learner shape; enrich evidence renderers; remount activities on switch; invalidate stale readiness.

## Key Insights

- `multiple-choice-editor.tsx` currently writes `multiCorrect` for multi mode — must switch to `correctOptionIds` for both modes + `multiSelect:boolean` display flag. On read, treat presence of `multiCorrect` (legacy) OR `multiSelect===true` as multi mode; on write, always emit canonical shape and delete legacy key.
- `choice-renderers.tsx` reads `config.multiSelect === true` — already correct once editor writes it.
- MATCHING: projection now emits `leftItems[]`/`rightItems[]` instead of `pairs[]`. Renderer must read the two arrays and draw two independent columns — no `↔` row alignment.
- DRAG_ORDER: projection reorders `items` — renderer already reads `config.items`; no change needed beyond removing the misleading note.
- Evidence: `PreviewActivityProps` must carry `evidence[]`/`assets[]` so EVIDENCE_SELECT and VERIFICATION can resolve `visibleEvidenceIds`/`visibleSourceIds` → real titles/descriptions.
- `stage-view.tsx` `<ActivityRenderer activity={activity} />` needs `key={activity.id}` to force remount on activity switch.
- `PublishReadinessCard` receives `draft={state.dirty ? null : state.draft}` — `draft` identity changes after save but mutation data persists. Fix: pass `revision` prop (from `state.revision` in `use-builder`) and `useEffect(() => mutation.reset(), [revision])`.

## Requirements

- MC editor: `write()` always sets `config.correctOptionIds` (subset ≤1 for single, ≥1 for multi) + `config.multiSelect`; deletes `config.multiCorrect`. Read: `mode = config.multiSelect===true || config.multiCorrect != null ? "multi" : "single"`.
- MATCHING renderer: two-column grid; left column = `leftItems` in emitted order, right column = `rightItems` in emitted order; no visual pairing hints.
- DRAG_ORDER renderer: unchanged logic (reads `config.items` which is now pre-shuffled by projection); update footer note.
- `PreviewActivityProps` gains optional `evidence?: EvidenceDoc[]` and `assets?: AssetDoc[]`.
- `ActivityRenderer` accepts and forwards `evidence`/`assets` props.
- `StageView` accepts and forwards; `preview-page.tsx` extracts `evidence`/`assets` from `preview.data.content` and threads them through `StageNav`→`StageView`→`ActivityRenderer`.
- EVIDENCE_SELECT: map `visibleEvidenceIds` → evidence doc → show `title` + `source.title` + `description`; missing id → "Nguồn không còn khả dụng" fallback text.
- VERIFICATION: same for `visibleSourceIds` → show source `title`/`author` instead of "Nguồn N".
- `stage-view.tsx`: `<ActivityRenderer key={activity.id} …/>`.
- `PublishReadinessCard`: new optional prop `revision?: number`; `useEffect(() => { mutation.reset(); }, [revision])`. `builder-page.tsx` passes `revision={state.revision}`.
- Readiness card shows timestamp of last check: store `checkedAt` in component state set in `onSuccess`, display "Kiểm tra lúc HH:mm" when `data` present.

## Architecture

```
preview.data.content { stages, evidence[], assets[] }
       │
  PreviewPage ──► StageNav (unchanged)
              └─► StageView { stage, evidence, assets }
                    └─► ActivityRenderer key={act.id} { activity, evidence, assets }
                          └─► EvidenceSelectView | VerificationView | …
                                evidence.map[id] → title/source/description
```

## Related Code Files

Modify:
- `multiple-choice-editor.tsx` — canonical write shape.
- `renderers/types.ts` — extend `PreviewActivityProps`.
- `renderers/interaction-renderers.tsx` — `MatchingActivityView` two-column; `EvidenceSelectActivityView` evidence docs; `DragOrderActivityView` note text.
- `renderers/assessment-renderers.tsx` — `VerificationActivityView` source docs.
- `activity-renderer.tsx` — accept + forward `evidence`/`assets`.
- `stage-view.tsx` — `key={activity.id}` + forward evidence/assets props.
- `preview-page.tsx` — extract evidence/assets from content; pass to `StageView`.
- `publish-readiness-card.tsx` — `revision` prop + `useEffect` reset + `checkedAt` display.
- `builder-page.tsx` — pass `revision={state.revision}` to `PublishReadinessCard`.
- `preview-renderers.test.tsx` — new/updated vitest cases.

Create: none. Delete: none.

## Implementation Steps

1. `renderers/types.ts`: add `evidence?: EvidenceDoc[]; assets?: AssetDoc[]` to `PreviewActivityProps`. Define minimal `EvidenceDoc`/`AssetDoc` interfaces here (or import from a shared `preview-types.ts` if one exists — keep it in `types.ts` to avoid new files).
2. `multiple-choice-editor.tsx`:
   - `mode` read: `const mode = config.multiSelect === true || (config.multiCorrect != null) ? "multi" : "single"`.
   - `correctSet`: `mode === "single" ? new Set(singleIds ?? []) : new Set(singleIds ?? multiIds ?? [])` — multi now also reads `correctOptionIds`.
   - `write()`: always `cfg.correctOptionIds = m === "single" ? correct.slice(0,1) : correct; cfg.multiSelect = m === "multi"; delete cfg.multiCorrect;`
3. `activity-renderer.tsx`: add `evidence`/`assets` props to `ActivityRenderer` signature; forward to each renderer that takes `PreviewActivityProps` (all of them — pass unconditionally, renderers use optionally).
4. `stage-view.tsx`: `<ActivityRenderer key={activity.id} activity={activity} evidence={evidence} assets={assets} />`; add `evidence`/`assets` to `StageView` props.
5. `preview-page.tsx`: after `parseDraft`, also extract `const evidence = preview.data?.content?.evidence ?? []` and `const assets = preview.data?.content?.assets ?? []`; pass to `<StageView stage={stage} evidence={evidence} assets={assets} …/>`. Note: `content` is `LearnerLessonContent.content` (ObjectNode → plain JS object after JSON serialization); access via `(preview.data.content as Record<string, unknown>).evidence`.
6. `MatchingActivityView` rewrite:
   - `const leftItems = readItems(activity.config?.leftItems)` / `const rightItems = readItems(activity.config?.rightItems)`.
   - Render `<div className="grid grid-cols-2 gap-3">` — left column `leftItems`, right column `rightItems`, each as labelled bordered boxes. No row pairing.
   - Fallback: if `leftItems` empty, show "Chưa có cặp nối nào."
7. `DragOrderActivityView`: change footer note to "Xem trước — thứ tự đúng không được hiển thị." (already correct, keep as-is or slight tweak).
8. `EvidenceSelectActivityView`:
   - Accept `evidence` from props; build `Map<id, EvidenceDoc>`.
   - For each `visibleEvidenceIds` entry: look up doc → render `doc.title` + `doc.source?.title` + `doc.description` (truncate); fallback "Nguồn không còn khả dụng" when missing.
   - Keep checkbox interaction.
9. `VerificationActivityView`: same pattern for `visibleSourceIds` → `doc.source?.title` + `doc.title`.
10. `publish-readiness-card.tsx`:
    - Add `revision?: number` to `Props`.
    - `useEffect(() => { mutation.reset(); setCheckedAt(null); }, [revision])` — import `useEffect`.
    - `const [checkedAt, setCheckedAt] = useState<Date | null>(null)`; set in `onSuccess` callback of `useMutation` options (`onSuccess: () => setCheckedAt(new Date())`).
    - Render `{checkedAt && <p className="text-[11px] text-ink-muted">Kiểm tra lúc {checkedAt.toLocaleTimeString("vi-VN")}</p>}` below the readiness banner.
11. `builder-page.tsx`: `<PublishReadinessCard lessonId={lesson.id} draft={state.dirty ? null : state.draft} revision={state.revision} onJump={…} />`.
12. Tests — `preview-renderers.test.tsx`:
    - `MC multiSelect=true renders checkboxes` — config `{question, options, correctOptionIds:["o1","o2"], multiSelect:true}` → `input[type=checkbox]` count = options.
    - `MC multiSelect=false renders radios`.
    - `MATCHING renders two independent columns` — config `{leftItems:[{id,label}…], rightItems:[…]}` → both labels visible; assert no `↔` between specific rows.
    - `DRAG_ORDER renders items in given order` — config `{items:[shuffled]}` → DOM order matches `config.items` order.
    - `EVIDENCE_SELECT resolves evidence docs` — pass `evidence=[{id,title,source:{title}}]`; `visibleEvidenceIds=[id]` → `doc.title` visible.
    - `EVIDENCE_SELECT missing id shows fallback` — unknown id → "Nguồn không còn khả dụng".
    - `VERIFICATION resolves source docs` — same pattern.
    - `remount: activity switch resets state` — render `StageView` with two activities same type; pick an option in activity A; switch to B; assert no option checked.
    - `PublishReadinessCard resets on revision change` — render card with `revision=1`, trigger mutation mock, rerender with `revision=2` → data cleared.

## Todo List

- [ ] `types.ts` extended with `EvidenceDoc`/`AssetDoc` + optional props
- [ ] MC editor canonical write (`correctOptionIds` + `multiSelect`, delete `multiCorrect`)
- [ ] `ActivityRenderer` + `StageView` + `preview-page` thread evidence/assets
- [ ] `key={activity.id}` on `ActivityRenderer`
- [ ] MATCHING renderer two-column rewrite
- [ ] EvidenceSelect + Verification renderers resolve docs
- [ ] `PublishReadinessCard` revision reset + `checkedAt`
- [ ] `builder-page.tsx` passes `revision`
- [ ] Vitest: all new cases pass; `npx vitest run` green

## Success Criteria

- `npx tsc --noEmit` clean; `npm run lint` clean; `npx vitest run` all pass.
- MC editor writes `correctOptionIds`+`multiSelect`; legacy `multiCorrect` configs still readable.
- MATCHING preview shows two independent columns; no pairing hint.
- Evidence renderers show real titles; missing ids show graceful fallback.
- Activity switch resets interactive state (remount).
- Readiness clears when draft revision changes.

## Risk Assessment

- `preview.data.content` is typed as `ObjectNode` in Java but arrives as plain JSON in TS — cast carefully; `evidence`/`assets` may be absent in fallback path → default to `[]`.
- `PublishReadinessCard` is also used on the publish page (`/lessons/[id]/publish`) — check that usage doesn't break; `revision` prop is optional so omitting it there is fine (no reset needed on that page).
- `use-builder.ts` `state.revision` — confirm it's exported and incremented on every draft mutation (verified: lines 85–228, `revision: state.revision + 1` on every action).

## Security Considerations

- Renderers must never read `correctPairs`, `expectedOrder`, `correctOptionIds`, `multiCorrect` — they are absent from projection anyway, but add no new reads.
- `evidence[]`/`assets[]` docs are admin-visible; no learner-only data added.

## Next Steps

- Phase 04 updates e2e stub to mirror new projection + embed evidence in preview endpoint.
