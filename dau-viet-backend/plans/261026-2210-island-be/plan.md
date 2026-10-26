---
title: "ISLAND-BE-01 — Heritage Island backend (island state, wallet core, shop)"
description: "Backend Dao Di San: island tiers/slots/placements, wallet core (HISTORY_POINTS), shop purchases idempotent + transactional."
status: pending
priority: P1
effort: 14h
branch: main
tags: [gamification, island, wallet, shop, flyway, spring-boot]
created: 2026-10-26
---

# ISLAND-BE-01 — Heritage Island Backend

## Scope

Implement server-side Heritage Island per `docs/GAMIFICATION_BUSINESS_RULES.md` +
`docs/GAMIFICATION_TECHNICAL_CONTRACT.md` (sections 2.3, 5, 6, 9, 11). Backend only — no Flutter,
no admin CMS, no commit/push.

## Key locked decisions (from contract + task brief)

- One soft currency `HISTORY_POINTS`; wallet = `wallet_accounts` + `wallet_transactions` (contract §2.3). `reward_transactions` stays append-only credit ledger; no negative rows there.
- Bridge: lazy per-user migration of `reward_transactions(reward_type='HISTORY_POINTS')` into `wallet_transactions` with `cause_key='BRIDGE:'||reward_transactions.id` — idempotent by UNIQUE cause_key. No mass backfill (YAGNI; GAME-08 owns global reconcile later).
- Tier thresholds in versioned config table `island_tier_policies` (not hard-coded, not file config — task says "bang config co version").
- Placement concurrency: `user_islands.row_version` optimistic lock via `expectedRevision`; UNIQUE(user_id,slot_id) + UNIQUE(user_id,item_id) as DB backstop.
- Purchase atomicity: idempotency_records (operation `SHOP_PURCHASE`) -> lock wallet row (PESSIMISTIC_WRITE) -> read price server-side -> debit -> insertIgnore user_inventory `SHOP_PURCHASE` -> ledger -> commit. Lock order: `wallet_accounts` before `user_inventory`/`user_islands`; never `user_energy` here.
- Shop sells only `item_type='DECOR'` rows present in `island_shop_items` with `active=true` and `price_points` non-null. No badges/dossiers/EXP/energy refill in this task.
- `GET /me/wallet` ships with this task (task says "reuse GAME-07 if exists" — it does not; implement minimal read).

## Phases

| Phase | File | Status | Effort |
|---|---|---|---|
| 01 | [phase-01-v32-migration.md](phase-01-v32-migration.md) — V32 schema + seeds | pending | 2.5h |
| 02 | [phase-02-island-domain.md](phase-02-island-domain.md) — island domain/repos/service | pending | 2.5h |
| 03 | [phase-03-wallet-core.md](phase-03-wallet-core.md) — wallet domain/repos/service + bridge | pending | 2h |
| 04 | [phase-04-shop-purchase.md](phase-04-shop-purchase.md) — shop service + purchase flow | pending | 2h |
| 05 | [phase-05-api-errors.md](phase-05-api-errors.md) — controllers/DTOs/ErrorCode/GlobalExceptionHandler | pending | 1.5h |
| 06 | [phase-06-tests-docs.md](phase-06-tests-docs.md) — ITs + unit tests + clearAuthoringTables + API_SPEC | pending | 3h |
| 07 | [phase-07-verify.md](phase-07-verify.md) — mvn verify + report | pending | 0.5h |

## Dependencies

- Phase 01 blocks all (schema). Phases 02/03 independent of each other, both need 01. Phase 04 needs 01+03 (+reads 02's placement uniqueness for `ITEM_ALREADY_OWNED` semantics — only inventory check, no island dep). Phase 05 needs 02+03+04. Phase 06 needs 05. Phase 07 needs 06.
- Mirror file `dau-viet-db/db/migration/V32__*.sql` must be byte-identical copy (repo convention: two mirrored migration dirs; drift detected: `dau-viet-db` is missing V22–V28 — executor should copy V32 into BOTH dirs and NOT try to backfill the older missing files; flag drift in final report).

## New tables (V32)

`island_tier_policies`, `island_slots`, `user_islands`, `user_island_placements`,
`island_shop_items`, `wallet_accounts`, `wallet_transactions`.
Plus `ALTER TABLE item_catalog` (item_type CHECK + `placeable`/`render_key` cols) and
`ALTER TABLE user_inventory` (acquisition_source CHECK += `SHOP_PURCHASE`).

## Error codes (new in ErrorCode enum)

`INSUFFICIENT_FUNDS` 409, `ITEM_NOT_OWNED` 403, `ITEM_ALREADY_OWNED` 409,
`ITEM_NOT_PLACEABLE` 422, `SLOT_LOCKED` 403, `SLOT_OCCUPIED` 409,
`ISLAND_UPGRADE_NOT_ELIGIBLE` 422, `STALE_ISLAND_REVISION` 409,
`ITEM_NOT_FOR_SALE` 422, `FEATURE_DISABLED` 503. Reuse `IDEMPOTENCY_CONFLICT` 409, `NOT_FOUND` 404.

## Risks / decisions needing user confirmation

1. **Tier thresholds**: T1=4 slots free, T2=8 slots at 2 EVENT_COMPLETED, T3=12 slots at 4 — seeded in `island_tier_policies` v1. Confirm numbers match product intent.
2. **Wallet scope**: bridge is lazy per-user (only HISTORY_POINTS credits mirrored; EXP stays out of wallet — correct per contract since EXP is non-spendable). `GET /me/wallet` returns balance/earned/spent + recent ledger. GAME-07 later adds `/me/gamification/summary` and refill endpoint — not in scope.
3. **`island_shop_items` separate table** (price/min_level/active) vs extending `item_catalog` with price columns: chose separate — catalog is content, shop is commerce policy; matches "catalog khong phai shop" separation and keeps catalog CHECK constraints clean. Confirm.
4. **DECOR items get `category='DECOR'`, `item_type='DECOR'`**: requires ALTER of `chk_item_type`. Alternative `item_type='HISTORICAL_REPLICA'` + category DECOR rejected — type drives placeable semantics.
5. **expectedRevision on PUT placements uses `user_islands.row_version`** (not per-placement version): single-writer island state, simpler client contract. Two-device edit -> second write gets 409 STALE_ISLAND_REVISION, reloads, retries. Confirm acceptable.
6. **dau-viet-db mirror drift**: V22–V28 missing from `dau-viet-db/db/migration`. Plan copies only V32 there; drift reported, not silently fixed (out of scope, might be intentional split).

## Out of scope

- Energy refill endpoint, `/me/gamification/summary`, level thresholds, premium shop (Kim Cuong), admin CMS for shop/slots, Flutter.
