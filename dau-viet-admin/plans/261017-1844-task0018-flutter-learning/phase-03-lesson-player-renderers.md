# Phase 03 — Lesson Player + Renderer Registry + 12 Activity Renderers

## Context links

- Phase 01/02 outputs (DTOs, attempt repository, player route)
- `docs/LEARNING_ENGINE_DESIGN.md` §11 (Flutter renderer contract), §13 (semantics)
- Research report — EXACT learner config shapes per type (post TASK-0017 transforms)
- `design/MOBILE_SCREEN_DESIGN.md` (M-09..M-16), `design/UI_COMPONENT_SPEC.md`
- Existing mock screens to reuse: `lib/features/learning/presentation/{context_reader,multiple_choice_quiz,matching_board,chronological_order,hypothesis_verification,cer_conclusion}_screen.dart`
- Widgets: ParchmentCard, DongSonButton, Tactile3DCard, ShimmerProgressBar, ShakeAnimationWidget, InteractiveHistoricalMascotWidget, AsyncStateView, AmbientAtmosphereOverlay

## Overview

- Priority: P0 — loi cua task
- Status: pending
- Mot `LessonPlayerScreen` duy nhat: fetch pinned content (attempt-scoped) + `/attempts/{id}/current` → dispatch renderer theo `activity.type` qua registry. Renderers la widget data-driven nhan `(activity{instruction,config,feedback}, evidence[], assets[])` + tra answer payload qua callback. Khong hard-code eventId/lessonId.

## Key insights

- Content source: snapshot projected tra `stages[]` (activity.day? khong — stages la array theo draft shape: `{id,type,title,required,activities[],nextStageIds[]}`) + `evidence[]` embed (id,title,evidenceType,description,source{...},reliability,relevance,assetId) + `assets[]` (id,storageKey,mimeType,altText,...). Renderers resolve evidence/asset ids -> embedded docs (pattern admin `resolve-evidence.ts`).
- `/attempts/{id}/current` chi tra activity tai cursor (projected config + feedback). `SubmitActivityResponse.next.learnerConfig` tra config projected cua activity KE TIEP → player co the render next ngay khong can refetch, nhung VAN can full snapshot content cho evidence/assets embed → flow: `GET attempt content` (pinned) 1 lan + `/current` + submit-next.
- Answer payload per type (EXACT, tu handlers):
  - READ/VIEW_IMAGE: `{}` (submit acknowledgment)
  - MULTIPLE_CHOICE: `{selectedOptionIds:[id,...]}` — radio khi `!multiSelect`, checkbox khi `multiSelect:true`
  - EVIDENCE_SELECT: `{selectedEvidenceIds:[...]}` — enable submit khi >= `minRequired`
  - MATCHING: `{pairs:[{leftId,rightId}...]}` tu `leftItems[]`/`rightItems[]`; KHONG dung `config.pairs` (da bi strip)
  - DRAG_ORDER: `{orderedIds:[...]}` tu `items[]` (da shuffled server); KHONG sort lai, KHONG hien answer
  - HYPOTHESIS_CHOICE: `{hypothesisId, evidenceIds:[...]}`
  - VERIFICATION: `{revise:true}` (acknowledgment — handler doc priorOutputs)
  - REASONING_CONNECT: `{relations:[{from,to,relation}]}`
  - EXPLORE_MAP: `{markerId}` — submit tung marker; `discoveredMarkerIds` trong output
  - CER: `{claim, evidenceIds:[], reasoning}` — client validate >=20 ky tu moi field truoc khi submit (server cung bat)
  - REFLECTION_PROMPT: `{text}` hoac `{optionId}`
- Feedback display: `evaluation.feedbackCode` → lookup `activity.feedback[code]`; fallback message theo `outcome` (COMPLETED/INCORRECT/PARTIAL/IN_PROGRESS/SUPPORTED/CONTRADICTED). `exhausted:true` → hien "het luot thu".
- Khong co `isCorrect` tu client — moi dung/sai deu tu `evaluation.output/outcome`.

## Requirements

- `LessonPlayerScreen(attemptId)`: top bar (back → exit confirm, stage title, progress `completedRequired/totalRequired` qua ShimmerProgressBar, mascot, sound toggle) / content = renderer / bottom bar = Submit + Continue theo server state.
- `ActivityRenderer` typedef `Widget Function(ActivityRenderContext)`; registry `Map<String, ActivityRenderer>` theo `activity.type`; unknown type → `UnsupportedActivityView` hien type + huong dan (KHONG fake-complete, khong submit).
- Player state machine (Riverpod): `loading content+current` → `answering` → `submitting` → `feedback` (hien feedback + Continue) → next. `activityCompleted && next==null` → hien nut "Hoan thanh" → phase 04 complete.
- Renderers uu tien (must): READ, VIEW_IMAGE (asset bytes qua `/assets/{id}/content` + auth), MULTIPLE_CHOICE, EVIDENCE_SELECT, MATCHING, DRAG_ORDER, CER, REFLECTION_PROMPT. Them neu contract ro: HYPOTHESIS_CHOICE, VERIFICATION, REASONING_CONNECT, EXPLORE_MAP (marker list).
- Tai su dung toi da 6 mock screens: tach UI (option card, match board, reorder list, CER form) khoi mock data; convert sang renderer nhan config. KHONG giu answer keys (`isCorrect`, `correctRight`, `_correctOrder`) — xoa khoi mock screen khi refactor hoac giu nguyen mock screens cho USE_MOCK demo route (quyet dinh: giu mock screens nhu cu cho demo; viet renderers moi data-driven — tranh pha demo).
- Optional activity trong stage: hien thi neu cursor tro; submit khong doi cursor (server xu ly) — UI khong can phan biet.
- Tap/select fallback cho drag (ReorderableListView co san + up/down buttons cho accessibility).

## Architecture

```
features/learning/presentation/lesson_player_screen.dart    shell + state
features/learning/presentation/player/activity_view.dart    ActivityRenderContext + dispatch
features/learning/presentation/player/renderer_registry.dart
features/learning/presentation/player/renderers/
  read_renderer.dart            (tach tu context_reader)
  view_image_renderer.dart      (auth image — phase 05 cung cap AssetImage widget)
  multiple_choice_renderer.dart (tach tu quiz screen)
  evidence_select_renderer.dart
  matching_renderer.dart        (tach tu matching board)
  drag_order_renderer.dart      (tach tu chronological order)
  hypothesis_renderer.dart
  verification_renderer.dart
  reasoning_connect_renderer.dart
  explore_map_renderer.dart     (marker list don gian — neu duyet)
  cer_renderer.dart             (tach tu cer screen)
  reflection_renderer.dart
  unsupported_renderer.dart
features/learning/presentation/player/player_state.dart     (Riverpod notifier)
features/learning/presentation/player/feedback_banner.dart  outcome + feedbackCode resolve
```

Moi file <200 lines; renderer chi UI + build answer; player giu submit state.

## Related code files

Create: cac file o tren.
Modify: `lib/app/router.dart` (da add route phase 02 — gan `LessonPlayerScreen`), KHONG sua mock screens (giu cho USE_MOCK demo).

## Implementation steps

1. `ActivityRenderContext {activity, evidence, assets, stage, onAnswerChanged(Map<String,dynamic>?)}` + registry + unsupported view.
2. `LessonPlayerScreen`: load (attempt content via repo + `/current`) → build; submit → repo.submit(attemptId, activityId, answer, key) → feedback banner; Continue → render `next{activityId, activityType, learnerConfig}` (resolve evidence tu snapshot embed).
3. Renderer READ: instruction + `config.text`/`paragraphs`/`html`(render plain text neu khong co html widget — giu don gian SelectableText).
4. VIEW_IMAGE: `config.imageAssetId` → auth image widget (phase 05: `AuthenticatedAssetImage`); `config.caption`; missing → alt/fallback.
5. MCQ: options list, radio/checkbox theo `multiSelect`, submit `selectedOptionIds`; shake on INCORRECT (reuse ShakeAnimationWidget); disabled while submitting.
6. EVIDENCE_SELECT: `visibleEvidenceIds` → resolve title/description tu `evidence[]`; multi-pick; submit `selectedEvidenceIds`; count vs `minRequired`.
7. MATCHING: 2 cot `leftItems`/`rightItems`; tap chon left → tap right de ghep; unmatch tap lai; submit `pairs` full.
8. DRAG_ORDER: ReorderableListView `items[]`; submit `orderedIds` theo thu tu hien tai.
9. HYPOTHESIS_CHOICE: `hypotheses[]` radio + chon nhieu evidence (optional theo config) → `{hypothesisId, evidenceIds}`.
10. VERIFICATION: hien `visibleSourceIds` docs + nut "Kiểm chứng" → `{revise:true}`; outcome PARTIAL/CONTRADICTED → feedback + giu cursor (server tu quyet REVISE).
11. REASONING_CONNECT: nodes[] + allowedRelations[]; UI don gian: chon from→to→relation; list relations; submit `relations`.
12. EXPLORE_MAP: markers[] list → submit `{markerId}` tung cai; hien `discoveredMarkerIds` tu output.
13. CER: 3 fields (claim, evidence multi-pick tu evidence[], reasoning) → validate >=20 chars → submit.
14. REFLECTION_PROMPT: text field hoac `options[]` pick → submit.
15. Feedback banner: outcome → icon/tone; `feedback[feedbackCode]` text; `output.correct` khi co de hien dung/sai; `exhausted` note.

## Todo list

- [ ] Player shell + state + registry + unsupported view
- [ ] READ + VIEW_IMAGE renderers
- [ ] MULTIPLE_CHOICE + EVIDENCE_SELECT
- [ ] MATCHING + DRAG_ORDER (tap fallback)
- [ ] HYPOTHESIS + VERIFICATION + REASONING_CONNECT + EXPLORE_MAP
- [ ] CER + REFLECTION_PROMPT
- [ ] Feedback banner + progress bar + mascot integration
- [ ] `flutter analyze` sach, files <200 lines

## Success criteria

- Moi type trong catalog co renderer hoac unsupported state ro rang; khong type nao leak answer key (kiem tra bang mat: khong `correctOptionIds/correctPairs/expectedOrder/acceptedSequences/requiredEvidenceIds` trong UI path).
- Cursor-driven: submit xong render next.learnerConfig dung type; content pinned version (neu G1).
- Tap/select fallback hoat dong cho MATCHING/DRAG_ORDER.
- Khong `if (eventId == ...)` hay title check trong player/renderers.

## Risk assessment

- `next.learnerConfig` chi co `config` (khong `feedback`/`instruction`?) — verify bang test: response `next` chi co `{stageId,activityId,activityType,learnerConfig}` → player resolve instruction/feedback tu snapshot embed (da co full content).
- Config shapes thieu field → renderer defensive (`as` casts + fallback), snapshot corrupt → error view (khong crash).
- EXPLORE_MAP map image: neu lesson khong co map asset → chi marker list; de lai TODO cho map layer sau.

## Security considerations

- Khong bao gio hien `output.correct` lam co so "dap an" truoc submit; chi hien SAU evaluate.
- Asset fetch qua authenticated endpoint — khong cache token trong URL.

## Next steps

Phase 04 gan submit/complete/result flow + idempotency + error recovery vao player hooks da co.
