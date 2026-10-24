# Phase 06 — Admin UI: Rule Builder V2 + Rule History + Reconcile Panel

## Context Links

- Spec: Module C + Reconciliation UI.
- Item detail hien tai: `src/features/items/item-detail.tsx` — replace Card "Dieu kien mo khoa" (v1 form) bang Rule Builder.
- Backend endpoints tu Phase 03: `POST /admin/items/{id}/rule/validate`, `GET /admin/items/{id}/rule/history`; PUT `/admin/items/{id}/rule` hien co (V1+V2 deu qua day).
- AST contract: leaf | `{all:[…]}` | `{any:[…]}`, depth ≤2. 11 leaf types — xem `ItemCondition.LeafType`.
- Scope tu `AdminItemResponse.scope` (Phase 03).
- Reconcile panel: `reward-backfill-button.tsx` da co — relocate vao Gamification tab hoac giu o `/items` (spec de mo: "trong Gamification tab hoac trang rieng"). De xuat: giu o `/items` (da tot) + bo sung batchSize field + hien `usersScanned`, `batches`.

## Overview

- Priority: P1
- Status: pending
- Effort: 6h
- Rule Builder 2-panel: trai = condition library (group by category), phai = AST editor (root ALL/ANY + leaf rows). Save = PUT `/admin/items/{id}/rule` voi `condition` (JsonNode). Rule History table. Reconcile panel nang cap.

## Key Insights

- Root `ALL`/`ANY` + leaf rows -> chi depth 2 — KISS: chi render 1 root operator + array children (khong nested groups). Pure function `formToAst(state)` -> JsonNode + `astToForm(json)` -> state.
- Scope badge tu `AdminItemResponse.scope`: `UNRESOLVED` -> banner "Can cau hinh event"; `EVENT_SCOPED` -> banner "Item gan su kien"; `GLOBAL` -> hien nhe.
- `LEVEL_AT_LEAST` disabled trong picker (tooltip "Chua ho tro — GAME-07").
- `SPECIFIC_EVIDENCE_SET`: chon event truoc -> load `/admin/evidences?eventId=&status=APPROVED` -> multiselect chi evidence cua event do.
- `LESSON_COMPLETED`/`LESSON_MASTERED`: chon lesson tu `/admin/lessons?status=PUBLISHED` (khong loc event — leaf lesson-scoped, khong bat buoc event).
- `EVENT_COMPLETED`/`EVENT_MASTERED`: chon event tu `/admin/events?status=PUBLISHED`; hien policy status inline (load `qk.policies.list(eventId)` cho event duoc chon — optional, chi hien khi co).
- `EVENT_EVIDENCE_COUNT`: event + threshold.
- `COLLECTION_COUNT`/`LESSON_COUNT`/`TOTAL_EVENTS_*`: threshold input; warning khi scope=EVENT_SCOPED.

### State shape (form)

```ts
type BuilderState = {
  root: "all" | "any";
  children: LeafForm[];  // depth-1 chi
};
type LeafForm = {
  localId: string;  // crypto.randomUUID()
  type: LeafType | null;
  eventId?: string;
  lessonId?: string;
  evidenceIds?: string[];
  threshold?: number;
  level?: number;
};
```

### formToAst (pure, testable)

```ts
function formToAst(state: BuilderState): JsonNode {
  const leaves = state.children.map(leafToJson).filter(nonNull);
  if (leaves.length === 1) return leaves[0];      // single leaf — khong wrap
  return { [state.root]: leaves };                // { all: [...] } hoac { any: [...] }
}
```

## Requirements

### Rule Builder UI

```
+-------------------------------------------+--------------------------------+
| Condition Library                         | Rule Tree                      |
|  — Bai hoc                                |   Root: [ALL | ANY v]         |
|    • LESSON_COMPLETED                     |   +-------------------------+  |
|    • LESSON_MASTERED                      |   | Leaf 1 [type][params]  |  |
|    • LESSON_COUNT                         |   |  [x]                   |  |
|  — Su kien                                |   +-------------------------+  |
|    • EVENT_COMPLETED                      |   | Leaf 2 ...             |  |
|    • EVENT_MASTERED                       |   +-------------------------+  |
|    • EVENT_EVIDENCE_COUNT                 |   [+ Them tu thu vien]        |
|  — Bang chung                             |                                 |
|    • SPECIFIC_EVIDENCE_SET                |   [Validation messages]         |
|  — Thanh tuu tong                         |   [Kiem tra] [Luu dieu kien]    |
|    • TOTAL_EVENTS_COMPLETED               |                                 |
|    • TOTAL_EVENTS_MASTERED                |                                 |
|  — Chua ho tro                            |                                 |
|    • LEVEL_AT_LEAST (disabled)            |                                 |
+-------------------------------------------+--------------------------------+
```

- Click item trong library -> append leaf vao `children` voi `localId`.
- Moi leaf row: type badge + dynamic fields + remove button + reorder (up/down).
- Mieu ta tieng Viet tu nhien duoi moi leaf (render tu leaf params — e.g. "Hoan thanh bai 'X'" ).
- "Kiem tra" -> POST `/rule/validate` -> hien errors/warnings + `acceptsRule` inline.
- "Luu dieu kien" -> PUT `/admin/items/{id}/rule` body `{ruleType:"RULE_V2", condition, active:true}`.

### Rule History

- Card "Lich su phien ban" — table `revision, ruleType, active, createdAt, grantCount, condition (JSON preview)` + "Xem AST" dialog.

### Reconcile Panel (nang cap reward-backfill-button)

- Them input `batchSize` (default 200) — POST `/admin/rewards/reconcile-unlocks?batchSize=`.
- Ket qua hien `itemsGranted`, `usersScanned`, `batches` (resp da tra).
- ConfirmDialog truoc khi chay.
- Nut disable khi pending; result card hien so that.

## Architecture

### Files moi

| File | Muc dich |
|------|----------|
| `src/features/items/rule-builder/rule-builder.tsx` | Root 2-panel. |
| `src/features/items/rule-builder/condition-library.tsx` | Panel trai. |
| `src/features/items/rule-builder/rule-tree.tsx` | Panel phai (root + leaf rows). |
| `src/features/items/rule-builder/leaf-row.tsx` | 1 leaf editor. |
| `src/features/items/rule-builder/leaf-fields/*.tsx` | Field editors per leaf type. |
| `src/features/items/rule-builder/rule-ast.ts` | `formToAst` + `astToForm` + `describeLeaf` (pure, co test). |
| `src/features/items/rule-builder/rule-ast.test.ts` | Vitest unit tests. |
| `src/features/items/rule-builder/scope-banner.tsx` | Banner scope. |
| `src/features/items/rule-history-table.tsx` | Lich su rule. |
| `src/features/items/reconcile-panel.tsx` | Nang cap cua `reward-backfill-button` (keep old file or extract). |

### Files sua

| File | Sua |
|------|-----|
| `src/features/items/item-detail.tsx` | Thay `Card "Dieu kien mo khoa"` cu bang `<RuleBuilder item={item}/>` + `<RuleHistoryTable itemId={id}/>` + `<ScopeBanner scope={item.scope}/>`. |
| `src/lib/dto/item.ts` | Them `condition` (JsonNode), `ruleVersion`, `revision`, `ruleMetadata`, `scope`, `grantCount` vao `AdminItemRule` + `AdminItem`. |
| `src/lib/dto/gamification.ts` | Them `AdminRuleValidation`, `AdminRuleHistoryEntry`. |
| `src/lib/query-keys.ts` | `qk.items.ruleHistory(id)`, `qk.items.ruleValidate` (mutation khong can key). |
| `src/app/(admin)/items/page.tsx` | Thay `<RewardBackfillButton/>` bang `<ReconcilePanel/>` (hoac rename file cu — giu file neu no van dung). |

## Implementation Steps

1. `rule-ast.ts` — types + pure functions.
2. `rule-ast.test.ts` — Vitest: form->Ast cho tung leaf type, ast->form roundtrip, depth<=2 enforcement, leaf validation.
3. `condition-library.tsx` — list items grouped.
4. `leaf-row.tsx` — dynamic editor per type (dung sub components).
5. `rule-tree.tsx` — root selector + rows + reorder.
6. `rule-builder.tsx` — ket noi library + tree + validate + save.
7. `scope-banner.tsx` — doc `item.scope`.
8. `rule-history-table.tsx`.
9. `reconcile-panel.tsx` — replace `reward-backfill-button`.
10. Update `item-detail.tsx`.
11. Typecheck + vitest.

## Todo List

- [ ] `rule-ast.ts` + tests.
- [ ] `condition-library.tsx`.
- [ ] `leaf-row.tsx` + leaf field editors.
- [ ] `rule-tree.tsx`.
- [ ] `rule-builder.tsx`.
- [ ] `scope-banner.tsx`.
- [ ] `rule-history-table.tsx`.
- [ ] `reconcile-panel.tsx` (batchSize input + result card).
- [ ] Update `item-detail.tsx`.
- [ ] Update `lib/dto/item.ts` + `gamification.ts` + `query-keys.ts`.
- [ ] typecheck + vitest pass.

## Success Criteria

- Rule Builder render 2 panel; them/xoa/sua leaf duoc.
- `formToAst` tra AST hop le; `astToForm` parse lai dung conditionJson tu server.
- Save goi PUT `/admin/items/{id}/rule` voi `condition` JSON.
- Validate endpoint tra errors -> hien inline; `acceptsRule=false` -> warning.
- Scope banner hien dung; LEVEL_AT_LEAST disabled.
- History list desc revision, danh dau `active`.
- Reconcile panel co confirm + hien `itemsGranted/usersScanned/batches`.

## Risk Assessment

- **Form->Ast complexity**: pure function de test; giu depth=2.
- **Evidence picker data**: event co nhieu evidence -> search + page trong picker (neu qua nhieu; mac dinh 100/page).
- **Stale form sau save**: reset tu `conditionJson` tra ve (server canonical).
- **`scope` khong co o backend cu**: neu Phase 03 chua chay xong, fallback `undefined` -> banner an.

## Security Considerations

- Khong render stack trace; chi `toUserMessage(err)`.
- Khong autosave — admin phai bam "Luu".
- Reconcile chi chay khi admin confirm; khong auto.

## Next Steps

- Phase 07 backend ITs; Phase 08 vitest + docs.
