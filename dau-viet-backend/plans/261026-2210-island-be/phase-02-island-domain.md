# Phase 02 — Island domain + service (state, upgrade, placements)

**Priority:** P1 · **Status:** pending · **Depends on:** Phase 01

## Context

- Package convention: `com.dauviet.island` — mirrors `energy`/`streak` layout (`domain`, `application`, `api`, `api.dto`, `infrastructure.persistence`).
- Lock/optimistic pattern: `user_islands.row_version` + `@Version` (matches `ItemCatalog.rowVersion`, `UserEnergy`). `expectedRevision` maps to it.
- Lazy-create pattern: copy `EnergyService.recoverLocked` (`insertIgnore` → `findForUpdate` retry).
- EVENT_COMPLETED count: `UserEventProgressRepository` (collection package) — check method exists; else `SELECT count(*) FROM user_event_progress WHERE user_id=? AND milestone='EVENT_COMPLETED'`.
- Energy service is the style guide: constructor injection, `@Transactional(REQUIRED)`, ledger-first idempotency, Vietnamese javadoc explaining WHY.

## Files to create

### domain/
- `UserIsland.java` — entity `user_islands`; fields `userId,tier,rowVersion(@Version),upgradedAt,createdAt`. Methods: `static create(userId)`, `upgradeTo(tier, now)`.
- `IslandSlot.java` — entity `island_slots` (read-only catalog); fields id,code,unlockTier,x,y,z,allowedCategories(jsonb string),active.
- `IslandTierPolicy.java` — entity `island_tier_policies`; fields id,configVersion,tier,slotCount,requiredEventsCompleted,active.
- `UserIslandPlacement.java` — entity `user_island_placements`; fields id,userId,slotId,itemId,placedAt,updatedAt.
- `IslandExceptions.java` — sealed/static nested (mirror `animation/domain/AnimationExceptions.java` pattern): `SlotNotFoundException`, `SlotLockedException`, `SlotOccupiedException`, `ItemNotOwnedException`, `ItemNotPlaceableException`, `UpgradeNotEligibleException`, `StaleRevisionException` (extends `org.springframework.dao.OptimisticLockingFailureException`? — contract: expectedRevision mismatch → `STALE_ISLAND_REVISION` 409, NOT generic OPTIMISTIC_LOCK_CONFLICT; keep custom RuntimeException, map in GlobalExceptionHandler).

### infrastructure/persistence/
- `UserIslandRepository` — `findForUpdate(userId)` (`@Lock(PESSIMISTIC_WRITE)` + `@Query`), `insertIgnore(userId,tier)` native ON CONFLICT.
- `IslandSlotRepository` — `findByActiveTrueOrderByCodeAsc()`, `findById`.
- `IslandTierPolicyRepository` — `findByActiveTrue()` → list for active config_version.
- `UserIslandPlacementRepository` — `findByUserId(userId)`, `findByUserIdAndSlotId`, `existsByUserIdAndItemId`, `deleteByUserIdAndSlotId` (atomic move support), plus native `insertIgnore` not needed (service validates + unique backstop).

### application/
- `IslandService` — see contract below.

## IslandService contract

```java
// GET /me/island → aggregate: island row (lazy-create) + active tier policies
// + slots (join placement) + eligibility flag for next tier
@Transactional IslandView view(UUID userId);

// POST /me/island/upgrade {expectedRevision}
// 1. findForUpdate island (lazy-create first)
// 2. row_version != expected → StaleRevisionException
// 3. nextTier = tier+1; >3 → UpgradeNotEligible
// 4. policy = active policies[tier=nextTier]
// 5. count EVENT_COMPLETED < policy.required → UpgradeNotEligible
// 6. island.upgradeTo(nextTier) → save (row_version++)
@Transactional IslandView upgrade(UUID userId, long expectedRevision);

// PUT /me/island/placements/{slotId} {itemId, expectedRevision}
// Atomic move semantics per task:
// 1. findForUpdate island; stale check
// 2. slot = slots.findById → not found → SlotNotFound (404 NOT_FOUND)
// 3. slot.unlockTier > island.tier → SlotLockedException (403 SLOT_LOCKED)
// 4. inventory.existsByUserIdAndItemId → else ItemNotOwnedException (403 ITEM_NOT_OWNED)
// 5. item.placeable && item.category in slot.allowedCategories
//    → else ItemNotPlaceableException (422 ITEM_NOT_PLACEABLE)
// 6. existing placement at (user,slot):
//      same item → idempotent no-op but still bump revision? No — return current
//        (replay-safe: same payload = same result; still validate revision first)
//      different item → SLOT_OCCUPIED 409 per task ("move nguyên tử, SLOT_OCCUPIED
//        nếu đích có item"). Client must DELETE first then PUT.
// 7. item already placed on OTHER slot → move: delete old placement row,
//    insert new (same tx → atomic). UNIQUE(user,item) satisfied.
// 8. island.touchRevision → save
@Transactional IslandView placeItem(UUID userId, UUID slotId, UUID itemId,
                                    long expectedRevision);

// DELETE /me/island/placements/{slotId} {expectedRevision in query or body?}
// Task spec doesn't include revision for DELETE — keep it optional:
// DELETE without expectedRevision just removes if present (idempotent 204).
// If occupied by other user's item — impossible (scoped user_id).
@Transactional IslandView removePlacement(UUID userId, UUID slotId);
```

Decision (documented): PUT with same item already on that slot = idempotent success (returns view, revision unchanged); PUT different item to occupied slot = SLOT_OCCUPIED; PUT item placed elsewhere = atomic move (task says "move nguyên tử" — interprets as move allowed, occupied-target rejected).

### IslandView DTO (api/dto)
```java
record IslandView(int tier, long revision, int slotCount,
                  Integer nextTier, Integer eventsRequiredForNext,
                  Integer eventsCompleted, boolean upgradeEligible,
                  List<SlotView> slots)
record SlotView(UUID slotId, String code, int unlockTier, boolean unlocked,
                double x, double y, double z,
                PlacedItem placed)          // null if empty
record PlacedItem(UUID itemId, String code, String name, String renderKey,
                  Instant placedAt)
```

Requests: `UpgradeRequest(long expectedRevision)`, `PlacementRequest(@NotNull UUID itemId, long expectedRevision)` — primitive long or Long? Use `Long` + `@NotNull` to force explicit send (validation error beats NPE).

## Repository wiring

- `UserEventProgressRepository` — verify existing method for counting completed events; if only `findByUserId`, add `long countByUserIdAndMilestone(UUID, String)` (query method, no migration needed). File: `collection/infrastructure/persistence/UserEventProgressRepository.java` — MODIFIED (additive).
- `UserInventoryRepository` — reuse `existsByUserIdAndItemId`.
- `ItemCatalogRepository` — `findById` + check `placeable`/`category` getters — **entity needs new fields** (`placeable`, `renderKey`) — ItemCatalog.java MODIFIED: add fields, getters, constants `TYPE_DECOR="DECOR"`, `CATEGORY_DECOR="DECOR"`.

## JPA/DDL consistency

`ddl-auto=validate` in ITs → entity mappings must match V32 exactly (column names snake_case via naming strategy, jsonb `allowed_categories` via `@JdbcTypeCode(SqlTypes.JSON)` String like `ItemCatalog.sourceMetadata`).

## Todo

- [ ] Read `AnimationExceptions.java` + `UserEventProgressRepository` for exact patterns
- [ ] Create 4 entities + exceptions file
- [ ] Create 4 repositories
- [ ] IslandService (view/upgrade/placeItem/removePlacement)
- [ ] Modify ItemCatalog (DECOR type + placeable/renderKey)
- [ ] Modify UserEventProgressRepository (count method) if absent
- [ ] Compile: `mvnw -B -ntp compile`

## Success criteria

- `mvn compile` green; entities validate against V32 DDL when first IT boots (phase 06).
- Service logic reviewable: eligibility math reads straight from `island_tier_policies` (no hardcoded 2/4 thresholds in Java).

## Risks

- `@Version` on `user_islands` + manual expectedRevision check: check BEFORE `@Version` flush — service compares entity.getRowVersion() vs expected at read time (post-lock), throws StaleRevision; `@Version` then protects against races between check and commit. Two layers, both needed.
- Lazy-create race on GET: `insertIgnore` + re-select pattern (copy EnergyService exactly).
- Placement delete+insert same tx ordering with UNIQUE(user,item): delete flush before insert — JPA action ordering may insert first → use `repository.delete()` + `flush()` explicitly, or native delete query (`@Modifying @Query delete`) which executes immediately. Prefer native delete for determinism.
