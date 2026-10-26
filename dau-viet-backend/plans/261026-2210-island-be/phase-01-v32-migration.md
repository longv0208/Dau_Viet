# Phase 01 — V32 Flyway migration: island + wallet + shop schema

**Priority:** P1 · **Status:** pending · **Blocks:** all other phases

## Context

- Latest applied: V31. Next = `V32__heritage_island_wallet_shop.sql`.
- Repo has TWO mirrored migration dirs: `dau-viet-backend/src/main/resources/db/migration/` (Flyway runtime, `classpath:db/migration`) and `dau-viet-db/db/migration/` (reference copy). Write V32 into BOTH, byte-identical. Note: `dau-viet-db` is missing V22–V28 — do not backfill; report drift.
- `dau-viet-db/db/migration/beforeEachMigrate.sql` exists — check whether it needs the new tables for dev-reset (read it first; likely dev-only wipe).
- Style: Vietnamese header comments like existing files, `gen_random_uuid()` PKs, `timestamptz`, CHECK constraints named `chk_*`, indexes `idx_*`, partial unique `ux_*`.

## Schema (create in this order)

### 1. `island_tier_policies` — versioned tier config
```sql
CREATE TABLE island_tier_policies (
    id UUID PRIMARY KEY,
    config_version INTEGER NOT NULL,
    tier INTEGER NOT NULL,
    slot_count INTEGER NOT NULL,
    required_events_completed INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_island_tier CHECK (tier BETWEEN 1 AND 3),
    CONSTRAINT chk_island_slots CHECK (slot_count > 0),
    CONSTRAINT chk_island_required CHECK (required_events_completed >= 0),
    CONSTRAINT ux_island_tier_policy UNIQUE (config_version, tier)
);
-- Partial unique: one active config_version set
CREATE UNIQUE INDEX ux_island_tier_policy_active
    ON island_tier_policies(active) WHERE active;
-- Hmm: need "one active version" — use single-row pattern instead:
-- keep ux above scoped differently: index on (config_version) WHERE active
```
Simplify: enforce single active version via `CREATE UNIQUE INDEX ux_island_tier_policy_active_version ON island_tier_policies (config_version) WHERE active;` — only one config_version may be active at a time (document that activating a new version = insert rows new version + update old `active=false`, app-managed; CHECK cannot express it — fine for V1, YAGNI).

Seed v1: `(version=1, tier=1, slots=4, required=0)`, `(1,2,8,2)`, `(1,3,12,4)`.

### 2. `island_slots` — static slot catalog (4+8=12 total)
```sql
CREATE TABLE island_slots (
    id UUID PRIMARY KEY,
    code VARCHAR(48) NOT NULL UNIQUE,          -- 'T1_S1'..'T3_S12'
    unlock_tier INTEGER NOT NULL,
    x NUMERIC(6,4) NOT NULL,                   -- normalized 0..1
    y NUMERIC(6,4) NOT NULL,
    z NUMERIC(6,4) NOT NULL DEFAULT 0,
    allowed_categories JSONB NOT NULL DEFAULT '["DECOR"]',
    active BOOLEAN NOT NULL DEFAULT true,
    CONSTRAINT chk_slot_tier CHECK (unlock_tier BETWEEN 1 AND 3),
    CONSTRAINT chk_slot_x CHECK (x BETWEEN 0 AND 1),
    CONSTRAINT chk_slot_y CHECK (y BETWEEN 0 AND 1),
    CONSTRAINT chk_slot_z CHECK (z BETWEEN 0 AND 1),
    CONSTRAINT chk_slot_categories CHECK (jsonb_typeof(allowed_categories) = 'array')
);
```
Seed 12 slots: T1_S1..S4 (unlock_tier=1), T2_S5..S8 (tier=2), T3_S9..S12 (tier=3), spread coords (executor picks plausible normalized layout — e.g. spiral/grid; exact values are cosmetic, mobile renders). `allowed_categories = '["DECOR"]'` for all in V1 — decor-only placements per task (historical replicas placeable? Task says badges not placeable; DECOR items are the placed kind. Keep `allowed_categories` column for future extension).

### 3. `user_islands`
```sql
CREATE TABLE user_islands (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    tier INTEGER NOT NULL DEFAULT 1,
    row_version BIGINT NOT NULL DEFAULT 0,     -- @Version optimistic lock
    upgraded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_island_tier CHECK (tier BETWEEN 1 AND 3)
);
```
Lazy-create on first GET/POST (like `user_energy` insertIgnore pattern).

### 4. `user_island_placements`
```sql
CREATE TABLE user_island_placements (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    slot_id UUID NOT NULL REFERENCES island_slots(id),
    item_id UUID NOT NULL REFERENCES item_catalog(id),
    placed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_placement_user_slot UNIQUE (user_id, slot_id),
    CONSTRAINT ux_placement_user_item UNIQUE (user_id, item_id)
);
CREATE INDEX idx_placement_user ON user_island_placements(user_id);
```
Ownership validated in service (item must be in `user_inventory`), not FK — user_inventory PK is `id`, not (user,item); keep FK to `item_catalog` only.

### 5. `island_shop_items`
```sql
CREATE TABLE island_shop_items (
    item_id UUID PRIMARY KEY REFERENCES item_catalog(id),
    price_points BIGINT,
    min_account_level INTEGER NOT NULL DEFAULT 1,
    active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_shop_price CHECK (price_points IS NULL OR price_points > 0),
    CONSTRAINT chk_shop_level CHECK (min_account_level >= 1)
);
```
`price_points NULL` = "not for sale yet" (display-only listing when `active=true`? — no: keep semantics simple: `active=false` → not listed; `active=true` + `price NULL` → listed but `purchasable=false`. Per task: `DECOR_CAU_KIEU` seeded `active=false` OR price NULL — pick `active=true, price_points=NULL` to exercise the `ITEM_NOT_FOR_SALE` path vs hidden. **Decision: seed Cau Kieu `active=true, price_points=NULL`** so GET /shop/items shows "coming soon"; update task interpretation in API_SPEC accordingly. If reviewer prefers fully hidden, flip active=false — document choice in migration comment.)

### 6. `wallet_accounts` + `wallet_transactions` (contract §2.3 verbatim)
```sql
CREATE TABLE wallet_accounts (
    user_id UUID NOT NULL REFERENCES users(id),
    currency VARCHAR(24) NOT NULL DEFAULT 'HISTORY_POINTS',
    balance BIGINT NOT NULL DEFAULT 0,
    row_version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_wallet_accounts PRIMARY KEY (user_id, currency),
    CONSTRAINT chk_wallet_currency CHECK (currency = 'HISTORY_POINTS'),
    CONSTRAINT chk_wallet_balance CHECK (balance >= 0)
);

CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    currency VARCHAR(24) NOT NULL DEFAULT 'HISTORY_POINTS',
    direction VARCHAR(8) NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(48) NOT NULL,
    cause_key VARCHAR(220) NOT NULL,
    source_ref VARCHAR(120),
    balance_after BIGINT NOT NULL,
    reference_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_wallet_tx_direction CHECK (direction IN ('CREDIT','DEBIT')),
    CONSTRAINT chk_wallet_tx_amount CHECK (amount > 0),
    CONSTRAINT chk_wallet_tx_reason CHECK (reason IN (
        'BRIDGE_CREDIT','SHOP_PURCHASE','ADMIN_ADJUST')),
    CONSTRAINT chk_wallet_tx_balance CHECK (balance_after >= 0),
    CONSTRAINT chk_wallet_tx_ref CHECK (reference_json IS NULL
        OR jsonb_typeof(reference_json) = 'object'),
    CONSTRAINT ux_wallet_tx_cause UNIQUE (cause_key)
);
CREATE INDEX idx_wallet_tx_user_created
    ON wallet_transactions(user_id, created_at DESC);
```
`cause_key VARCHAR(220)`: `BRIDGE:<reward_tx_uuid>` (~43), `SHOP_PURCHASE:<uuid>`, headroom for future.

### 7. ALTER `item_catalog`
```sql
ALTER TABLE item_catalog DROP CONSTRAINT chk_item_type;
ALTER TABLE item_catalog ADD CONSTRAINT chk_item_type CHECK (item_type IN (
    'HISTORICAL_REPLICA','DIGITAL_EDITION','COMMEMORATIVE_BADGE','DECOR'));
ALTER TABLE item_catalog ADD COLUMN placeable BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE item_catalog ADD COLUMN render_key VARCHAR(80);
```

### 8. ALTER `user_inventory`
```sql
ALTER TABLE user_inventory DROP CONSTRAINT chk_inventory_source;
ALTER TABLE user_inventory ADD CONSTRAINT chk_inventory_source CHECK (
    acquisition_source IN ('LESSON_COMPLETED','COLLECTION_COUNT',
        'LESSON_COUNT','ADMIN_GRANT','SHOP_PURCHASE'));
```
Verify against ACTUAL latest constraint: V24/V25 altered rule tables — re-grep `chk_inventory_source` / whether constraint name survived. If name differs, use `ALTER TABLE user_inventory DROP CONSTRAINT IF EXISTS chk_inventory_source` style fallback? Flyway runs raw SQL — executor must check `pg_constraint` name in V12 (it is `chk_inventory_source`, confirmed reading V12). Still, `DROP CONSTRAINT` not `IF EXISTS` — deterministic.

### 9. Seed DECOR catalog + shop SKU
```sql
INSERT INTO item_catalog (id, code, name, description, category, item_type,
                          rarity, placeable, render_key, active)
VALUES
 (gen_random_uuid(),'DECOR_CAY_DA','Cay da','Cay da co thu...','DECOR','DECOR','COMMON',true,'decor_cay_da',true),
 (... 'DECOR_NHA_TRANH', 200 ...),
 (... 'DECOR_HO_SEN', 300 ...),
 (... 'DECOR_CAU_KIEU', ...);
INSERT INTO island_shop_items (item_id, price_points, min_account_level, active, sort_order)
SELECT id,
  CASE code WHEN 'DECOR_CAY_DA' THEN 100
            WHEN 'DECOR_NHA_TRANH' THEN 200
            WHEN 'DECOR_HO_SEN' THEN 300
            ELSE NULL END,
  1, true, ...
FROM item_catalog WHERE code LIKE 'DECOR_%';
```
Deterministic UUIDs optional (V22 used fixed `d7c1...` UUIDs for dossiers — same trick OK for reproducible ITs; prefer fixed UUIDs `d7d0...` range to avoid collision with V22 `d7c0/d7c1`).

## Files

**Create:**
- `src/main/resources/db/migration/V32__heritage_island_wallet_shop.sql`
- `dau-viet-db/db/migration/V32__heritage_island_wallet_shop.sql` (identical copy)

**Modify:** none (never edit applied migrations).

## Key contract points

- No data mutation of existing tables (only CHECK re-add + additive columns).
- `chk_wallet_balance`/`chk_wallet_tx_*` are the DB backstops — service enforces first.
- All inserts `ON CONFLICT DO NOTHING` where re-runnable; seeds deterministic.

## Todo

- [ ] Read `dau-viet-db/db/migration/beforeEachMigrate.sql`; extend if it truncates per-table lists
- [ ] Write V32 SQL (both dirs)
- [ ] Verify `chk_inventory_source` name from V12 before ALTER
- [ ] Sanity: `mvnw -B -ntp -DskipTests compile flyway:migrate` not needed — ITs run Flyway; optionally spin a throwaway PG via Testcontainers smoke in Phase 06

## Success criteria

- Fresh DB: `mvnw verify` boots schema with `jakarta ddl-auto=validate` later when entities land (Phase 02-04 will validate). For this phase: migration SQL parses (review), constraints named, seed counts: 3 tier rows, 12 slots, 4 shop items, 4 DECOR catalog rows.
- Non-empty DB: CHECK-alter statements don't touch existing rows (`item_type`/`acquisition_source` supersets — always valid).

## Risks

- **Mirror drift**: `dau-viet-db` missing V22–V28 → copying V32 alone makes its sequence 1-21,29,30,31,32+gap. Flag in report; do NOT backfill (scope).
- **`allowed_categories` vs `placeable`/`category`**: slot allows `["DECOR"]`; item has `placeable` + `category='DECOR'`. Service checks BOTH (belt & suspenders per task: "khong dat huy hieu khong placeable").
- If `beforeEachMigrate.sql` truncates tables for dev reset, add new tables or dev-reset breaks.

## Security

None new — DDL only. Shop/decor seed content uses neutral educational wording (no fake provenance — reuse V12 style notes in descriptions).
