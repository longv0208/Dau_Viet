# Phase 03 — Backend: Item Rule Validate/History + Reconcile Admin Surface

## Context Links

- Spec: Module C + Reconciliation & Audit UI.
- `AdminItemService.setRule` (`reward/application/AdminItemService.java`) da co: pessimistic lock tren `item_catalog`, deactivate rule cu + flush, insert rule moi, `revision = maxRevision+1`, scopeResolver guard, `conditionParser.parse` + `conditionValidator.validate` cho V2.
- `ItemUnlockRule` append-only — rule cu `active=false` van con trong bang (revision, createdAt, conditionJson). Khong can schema moi.
- `ItemConditionParser` + `ItemConditionValidator` + `ItemRuleScopeResolver` da san sang reuse.
- `ItemRuleScopeResolver.scopeOf(itemId)` tra UNRESOLVED/EVENT_SCOPED/GLOBAL — UI can field nay.
- `AdminRewardController` da co `POST /admin/rewards/reconcile-unlocks` + `/backfill` — chi can expose o UI (khong can backend moi cho reconcile).

## Overview

- Priority: P1
- Status: pending
- Effort: 3h
- Them: POST `/admin/items/{itemId}/rule/validate` (dry-run khong ghi DB) + GET `/admin/items/{itemId}/rule/history` (list cac revision) + tra `scope` trong `AdminItemResponse` (extension).

## Key Insights

- `ItemRuleException` = 400 (da map san qua handler global?). CONFIRM handler — kiem tra `CommonExceptionHandler` / `GlobalExceptionHandler`.
- `findByItemIdOrderByCreatedAtAsc` da co — history chi can map sang DTO.
- `AdminItemResponse.Rule` record hien co `id, ruleType, lessonId, threshold, active, ruleVersion, conditionJson, ruleMetadata` — them `revision` + `createdAt` + `grants` (COUNT user_inventory.unlock_rule_id = r.id hoac unlock_rule_version = revision — CONFIRM cot).
- `AdminRuleRequest` chap nhan `condition` (JsonNode) — validate endpoint parse + validate khong save.
- Scope tra ve: them `ItemScope scope` vao `AdminItemResponse` (top-level) de UI hien "Needs Configuration" / "Event-scoped" / "Global".

## Requirements

- POST `/api/v1/admin/items/{itemId}/rule/validate` — body `{ruleType?, lessonId?, threshold?, condition?}` (cung AdminRuleRequest shape). Tra `AdminRuleValidationResponse`: `{valid, errors:[{code,message,field?}], warnings:[string], normalizedCondition: JsonNode, scope:"UNRESOLVED"|"EVENT_SCOPED"|"GLOBAL", acceptsRule: bool}`. Khong ghi DB.
- GET `/api/v1/admin/items/{itemId}/rule/history` — list `item_unlock_rule` desc revision, moi row `{id, ruleType, ruleVersion, revision, conditionJson, active, createdAt, grantCount}`. Tra kèm `current` = rule dang active (neu co).
- Sua `AdminItemResponse` — them field `scope: "UNRESOLVED"|"EVENT_SCOPED"|"GLOBAL"` (de UI hien banner).
- `grantCount`: `SELECT COUNT(*) FROM user_inventory WHERE unlock_rule_id = :ruleId` — CONFIRM schema `user_inventory` (V18/V19?). Neu khong co `unlock_rule_id` cot, fallback `unlock_rule_version = revision` — KIEM TRA thuc te. Neu khong co gi, tra `null` va UI hien "—".

## Architecture

### Files moi

| File | Muc dich |
|------|----------|
| `reward/api/AdminItemRuleController.java` | `/{itemId}/rule/validate` + `/{itemId}/rule/history` tach khoi `AdminItemController` (giu file <200 dong). |
| `reward/api/dto/AdminRuleValidationResponse.java` | record. |
| `reward/api/dto/AdminRuleHistoryEntry.java` | record. |

### Files sua

| File | Sua |
|------|-----|
| `reward/application/AdminItemService.java` | them `validateRule(itemId, req)` (dry-run: parse + validate + scope check, khong save) + `ruleHistory(itemId)` (map + grantCount). |
| `reward/api/dto/AdminItemResponse.java` | them `scope` + `Rule.revision` + `Rule.createdAt` + `Rule.grantCount` (hoac tach `AdminRuleHistoryEntry`). |
| `reward/infrastructure/persistence/ItemUnlockRuleRepository.java` | them `findByItemIdOrderByRevisionDesc`. |
| `reward/infrastructure/persistence/UserInventoryRepository.java` (hoac moi) | them `countByUnlockRuleId(UUID)` hoac `countByUnlockRuleVersion(itemId, revision)` — tuy schema. |

### Endpoint contracts

```jsonc
// POST /api/v1/admin/items/{itemId}/rule/validate
// body: { "condition": {"all":[{"type":"EVENT_COMPLETED","eventId":"..."}]},
//         "ruleType": "RULE_V2" }  // hoac V1 shape
// -> 200 AdminRuleValidationResponse
{
  "valid": false,
  "errors": [{"code":"EVENT_NOT_PUBLISHED","message":"...","field":"condition.all[0].eventId"}],
  "warnings": ["Item la event-scoped — rule global se bi chan."],
  "normalizedCondition": { /* canonical AST da parse */ },
  "scope": "EVENT_SCOPED",
  "acceptsRule": false
}

// GET /api/v1/admin/items/{itemId}/rule/history
// -> [{ id, ruleType, ruleVersion, revision, conditionJson, active, createdAt, grantCount }]
```

## Related Code Files

**Tao moi:**
- `dau-viet-backend/src/main/java/com/dauviet/reward/api/AdminItemRuleController.java`
- `dau-viet-backend/src/main/java/com/dauviet/reward/api/dto/AdminRuleValidationResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/reward/api/dto/AdminRuleHistoryEntry.java`

**Sua:**
- `AdminItemService.java` — them `validateRule` + `ruleHistory`.
- `AdminItemResponse.java` — them `scope` field.
- `ItemUnlockRuleRepository.java` — `findByItemIdOrderByRevisionDesc`.
- `UserInventoryRepository` hoac tao moi — count grants per rule (CONFIRM schema).

**Khong sua:** `AdminItemController` (PUT `/rule` cu giu nguyen — backward compat), `AdminRewardController`, `ItemConditionParser/Validator`, `ItemRuleScopeResolver`.

## Implementation Steps

1. Kiem tra `user_inventory` schema: `unlock_rule_id` / `unlock_rule_version` — `Grep` trong `V*.sql` hoac `UserInventory.java`.
2. Them repository method phu hop.
3. `AdminRuleValidationResponse` + `AdminRuleHistoryEntry` records.
4. `AdminItemService.validateRule`: build condition -> parser.parse -> conditionValidator.validate -> scopeResolver.scopeOf + acceptsRule -> tra response (khong save). Bat `ItemRuleException`/`IllegalArgumentException` -> tra `valid:false` + errors.
5. `AdminItemService.ruleHistory`: findByItemIdOrderByRevisionDesc -> map sang `AdminRuleHistoryEntry` + grantCount.
6. `AdminItemService.toResponse`: them `scope` tu scopeResolver.
7. `AdminItemRuleController` — 2 endpoint.
8. Compile + test nhanh.

## Todo List

- [ ] Xac minh `user_inventory` schema (unlock_rule_id? unlock_rule_version?).
- [ ] Viet `AdminRuleValidationResponse` + `AdminRuleHistoryEntry`.
- [ ] `AdminItemService.validateRule` + `ruleHistory`.
- [ ] `AdminItemResponse` them `scope`.
- [ ] `AdminItemRuleController` + endpoints.
- [ ] `ItemUnlockRuleRepository.findByItemIdOrderByRevisionDesc`.
- [ ] Compile pass.

## Success Criteria

- POST validate tra `valid:true` cho rule hop le; `valid:false` + `errors[]` cho rule sai.
- `acceptsRule=false` + warning khi item event-scoped ma rule global.
- GET history tra tat ca revision desc, danh dau `active=true`.
- `AdminItemResponse.scope` tra dung UNRESOLVED/EVENT_SCOPED/GLOBAL.
- Khong ghi DB trong validate; khong anh huong rule dang active.

## Risk Assessment

- **`grantCount` schema khong dung gia dinh**: doc `user_inventory` truoc khi chon cot.
- **Validate dry-run khong bat scope**: scopeResolver phai goi trong validate, khong chi trong setRule.
- **Perf**: history list co the dai — pagination neu >50 revision (YAGNI: chua can, chi limit 100 hard-coded).

## Security Considerations

- `/api/v1/admin/**` -> CONTENT_ADMIN.
- Validate KHONG ghi DB — an toan.
- Khong tra `ruleMetadata` raw ra UI (co the chua audit internals — CONFIRM).

## Next Steps

- Phase 06 UI dung cac endpoint nay.
- IT o Phase 07.
