# Phase 04 — Shop service + purchase flow (idempotent, transactional)

**Priority:** P1 · **Status:** pending · **Depends on:** Phases 01, 03

## Context

- Package `com.dauviet.shop`. Reads `island_shop_items` + `item_catalog`; writes via `WalletService.debit` + `UserInventoryRepository.insertIgnoreV2`.
- Idempotency: reuse `IdempotencyService.execute` (learning package) with operation `"SHOP_PURCHASE"`; `Idempotency-Key` header REQUIRED for `POST /me/shop/purchases` (task: "JWT + Idempotency-Key → ..."). Decide: missing key → 400 VALIDATION_ERROR (contract §11: "bat buoc" for mutating purchases) — enforce `required=true` on header, consistent with submit semantics.
- Feature flag: `dauviet.shop.enabled` property (default true; when false → `FeatureDisabledException` → 503 FEATURE_DISABLED). Mirrors `dauviet.energy.enabled` pattern (`EnergyProperties`), needed for the FEATURE_DISABLED error code in task spec.

## Files to create

### domain/
- `IslandShopItem.java` — entity `island_shop_items`: itemId(@Id), pricePoints(Long, nullable), minAccountLevel, active, sortOrder.
- `ShopExceptions.java` — nested: `ItemNotForSaleException`, `ItemAlreadyOwnedException`, `FeatureDisabledException`. (`InsufficientFundsException` lives in wallet domain — reuse.)

### infrastructure/persistence/
- `IslandShopItemRepository` — `findByActiveTrueOrderBySortOrderAsc()`, `findByItemIdAndActiveTrue(itemId)` (fetch join catalog? separate ItemCatalogRepository call is fine — small catalog).

### application/
- `ShopService`:

```java
// GET /shop/items — public catalog (authenticated learner):
// join active shop rows + catalog; purchasable = price!=null && !owned
// owned via inventory.existsByUserIdAndItemId per item (N≤ dozens, fine)
// or one query: inventory.findByUserId... collect itemIds set. Prefer set.
@Transactional(readOnly=true) List<ShopItemView> catalog(UUID userId);

// POST /me/shop/purchases — wrapped by idempotency in controller OR service?
// Put idempotency INSIDE service method for symmetry with LearnerAttemptService
// (which calls idempotency.execute inside @Transactional methods):
@Transactional
public PurchaseView purchase(UUID userId, UUID itemId, String idemKey) {
    if (!props.enabled()) throw new FeatureDisabledException();
    return idempotency.execute(userId, "SHOP_PURCHASE", idemKey,
        itemId.toString(),                       // payload fingerprint
        () -> doPurchase(userId, itemId), PurchaseView.class);
}

private PurchaseView doPurchase(UUID userId, UUID itemId) {
    // 1. shop row: findByItemIdAndActiveTrue → absent → ItemNotForSale(422)
    //    (404 vs 422: task lists ITEM_NOT_FOR_SALE; for-sale check covers both
    //    "not in shop" and "price NULL" — one code per task spec. Confirm: use
    //    ITEM_NOT_FOR_SALE for both, details.reason differentiates.)
    // 2. price null → ItemNotForSale (reason='not_priced')
    // 3. eligibility: user level >= min_account_level — LEVEL SOURCE?
    //    No level service exists yet (GAME-07). Compute from reward_transactions
    //    EXP sum vs level thresholds? Thresholds are config file per contract
    //    §2.6 — but no levels impl exists. DECISION: V1 all SKUs
    //    min_account_level=1 and every user ≥1 → check is a no-op
    //    implemented as `levelOf(userId)>=min` where levelOf returns 1
    //    (placeholder documented; GAME-07 swaps in real calc). DO NOT build
    //    a level system here (YAGNI). Add `// ISLAND-BE-01: real level from
    //    GAME-07` comment. min_account_level column exists for forward-compat.
    // 4. inventory.existsByUserIdAndItemId → ItemAlreadyOwned (409)
    // 5. walletService.debit(userId, price, "SHOP_PURCHASE:"+purchaseTxId,
    //    "SHOP_PURCHASE", refJson{itemId, itemCode})
    //    purchaseTxId = UUID derived how? Deterministic from idem scope:
    //    cause_key uniqueness already covers retry. Use
    //    'SHOP_PURCHASE:' + userId + ':' + itemId + ':' + idemKey — stable
    //    for the idempotency scope, unique per purchase attempt.
    //    Actually simpler & safe: 'SHOP_PURCHASE:'+idemKey is enough given
    //    (user,operation,key) idempotency claim already precedes; include
    //    itemId for forensic clarity: "SHOP_PURCHASE:"+idemKey+":"+itemId.
    //    220-char cause_key col fits.
    // 6. inventory.insertIgnoreV2(userId, itemId, 'SHOP_PURCHASE', null, null,
    //    null, null, null, causeKey) — returns 0? Means concurrent grant
    //    slipped between step 4 and 6 → ItemAlreadyOwned... BUT wallet already
    //    debited → must NOT silently swallow: throw ItemAlreadyOwned →
    //    tx rolls back INCLUDING the wallet debit ledger row + account save.
    //    Correct: exception after ledger insert rolls everything back
    //    (same tx). The stored-cause reconcile path in debit isn't hit
    //    because ledger row never commits.
    // 7. Build PurchaseView {itemId, code, name, pricePaid, balanceAfter,
    //    purchasedAt, serverTime}
}
```

Purchase response DTO: `record PurchaseView(UUID purchaseId? — no separate purchase table; omit, or echo causeKey? Keep: record PurchaseView(UUID itemId,String code,long pricePaid,long balanceAfter,Instant purchasedAt))` — replay returns identical stored JSON.

`ShopItemView`: `(UUID itemId, String code, String name, String description, String renderKey, Long pricePoints, boolean purchasable, boolean owned, Integer minAccountLevel)`.

## Files to modify

- `UserInventoryItem` / `UserInventoryRepository` — insertIgnoreV2 signature already accepts all needed params (acquisitionSource='SHOP_PURCHASE', nulls for rule/lesson/event, causeKey). Check `ux_user_inventory_cause_key` partial index exists (V24) so duplicate cause → 0 rows. Verify: if the partial unique on cause_key doesn't exist, two different items same cause could both insert — add index in V32? Read V24 first; if missing, add `CREATE UNIQUE INDEX ux_user_inventory_cause_key ON user_inventory(cause_key) WHERE cause_key IS NOT NULL` to V32 (update phase-01 todo).
- `EnergyProperties`-style props: create `ShopProperties` (`@ConfigurationProperties("dauviet.shop")` enabled flag) or just `@Value("${dauviet.shop.enabled:true}")` — pick `@Value`, simpler (YAGNI; energy needed the record for 5+ fields).

## Key contract points

- Price ALWAYS from `island_shop_items.price_points` server-side; client sends only `itemId`.
- Atomicity: wallet debit + inventory insert + idempotency record + response — one tx. InsufficientFunds → whole tx rolls back, idempotency claim also rolls back (IdempotencyRecord.claim saved in same tx → retry with same key reclaims fresh — correct per IdempotencyService design).
- Idempotency-Key same + different itemId → `IDEMPOTENCY_CONFLICT` 409 (fingerprint includes itemId).
- No ownership → no placement; shop never places on island (placement is separate endpoint per task).
- Forbidden items: shop table only references DECOR items by seed; service does NOT re-check item_type — catalog could list non-DECOR if admin adds later... defense-in-depth: check `item.itemType=='DECOR'` too → ItemNotForSale reason 'not_decor'. Cheap guard, keeps "shop không bán huy hiệu" invariant even if shop row misconfigured.

## Todo

- [ ] Read V24 for `ux_user_inventory_cause_key`; add to V32 if absent
- [ ] Create domain entity + exceptions
- [ ] Create repository
- [ ] ShopService (catalog + purchase + doPurchase)
- [ ] `mvnw compile`

## Success criteria

- Buy DECOR_CAY_DA with balance ≥100: 200 response shape, balance decreases by exactly price, inventory has item with `acquisition_source='SHOP_PURCHASE'`, wallet has DEBIT row cause `SHOP_PURCHASE:...`.
- Retry same Idempotency-Key + same body → identical response, no second DEBIT, no second ownership.
- Same key + different itemId → 409 IDEMPOTENCY_CONFLICT.
- Insufficient balance → INSUFFICIENT_FUNDS 409, zero side effects.
- Item already owned (e.g. buy twice with different keys) → 409 ITEM_ALREADY_OWNED, no debit.
- Non-shop item UUID → 422 ITEM_NOT_FOR_SALE. Cau Kieu (price NULL) → 422 ITEM_NOT_FOR_SALE.
- Feature flag off → 503 FEATURE_DISABLED.

## Risks

- Idempotency + failure interaction: failed purchase (insufficient) must NOT store a replayable failure response — IdempotencyService stores response only on executor success; exception → record stays claimed→rollback → clean. Verify no catch-and-wrap in service swallows the exception into a stored 200.
- Level placeholder: document clearly; if min_account_level>1 rows appear later before GAME-07, purchases would incorrectly pass. Mitigate: `levelOf` throws `FeatureDisabledException`? No — simpler: assert `min_account_level<=1` → if shop row has >1, treat as ItemNotForSale reason 'level_unavailable'. Safe gate, honest behavior.
