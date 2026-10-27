# Phase 03 — Wallet core (HISTORY_POINTS): account + ledger + bridge

**Priority:** P1 · **Status:** pending · **Depends on:** Phase 01 · **Blocks:** Phase 04

## Context

- Contract §2.3/§6 is the spec — copy table semantics verbatim; service mirrors `EnergyService` structure (lock → ledger-first insertIgnore → mutate balance → save; reconcile on stored cause).
- Scope deliberately minimal (YAGNI): balance read, lazy bridge credit, transactional debit. NO refill endpoint, NO summary endpoint, NO EXP in wallet.
- `reward_transactions` untouched — bridge reads it, never writes.

## Files to create (package `com.dauviet.wallet`)

### domain/
- `WalletAccount.java` — entity `wallet_accounts`, composite PK `(user_id, currency)` → `@IdClass` or `@EmbeddedId`. Simpler: `@Id` on surrogate? Table PK is composite — use `@IdClass(WalletAccountId.class)` with two `@Id` fields (standard JPA, `ddl-auto=validate` OK). Or pragmatically: keep `user_id` sole `@Id` since currency has CHECK `='HISTORY_POINTS'` — NO: PK is composite, map it faithfully with `@IdClass`. Fields: userId, currency, balance, rowVersion(@Version), createdAt. Methods: `credit(amount)`, `debit(amount)` (throws `InsufficientFundsException` if balance<amount — service checks first anyway).
- `WalletTransaction.java` — entity `wallet_transactions`; constants `DIR_CREDIT/DIR_DEBIT`, `REASON_BRIDGE_CREDIT/SHOP_PURCHASE/ADMIN_ADJUST`.
- `InsufficientFundsException.java` — RuntimeException, carries `balance`, `required`.

### infrastructure/persistence/
- `WalletAccountRepository`:
  - `findForUpdate(userId, currency)` — `@Lock(PESSIMISTIC_WRITE)`
  - `insertIgnore(userId, currency)` native `ON CONFLICT DO NOTHING`
- `WalletTransactionRepository`:
  - `insertIgnore(...)` native with all columns, `ON CONFLICT (cause_key) DO NOTHING` returns int
  - `findStoredByCauseKey(userId, causeKey)` → `StoredCause(balanceAfter, createdAt)` (copy EnergyTransactionRepository.StoredCause pattern)
  - `findByUserIdOrderByCreatedAtDesc(userId, pageable)` for GET /me/wallet ledger
  - `sumByDirection(userId, direction)` → earned/spent totals

### application/
- `WalletService`:

```java
// Central: lock account (lazy-create) → bridge pending credits → return row.
// Bridge = mirror reward_transactions HISTORY_POINTS credits not yet in
// wallet ledger. Idempotent: cause_key='BRIDGE:'+rewardTxId UNIQUE;
// set-based single pass, then one aggregate UPDATE on balance instead of
// per-row save (performance, still atomic inside lock):
private WalletAccount lockedAndBridged(UUID userId) {
    // 1. insertIgnore account (0 balance) then findForUpdate — EnergyService pattern
    // 2. bridge: SELECT r.id, SUM? No — per-row insert with cause_key:
    //    INSERT INTO wallet_transactions (..., cause_key, source_ref, balance_after, ...)
    //    SELECT gen_random_uuid(), r.user_id,'HISTORY_POINTS','CREDIT',r.amount,
    //           'BRIDGE_CREDIT','BRIDGE:'||r.id, r.id::text, 0, NULL, r.created_at
    //      FROM reward_transactions r
    //     WHERE r.user_id=? AND r.reward_type='HISTORY_POINTS'
    //       AND NOT EXISTS (SELECT 1 FROM wallet_transactions w
    //                        WHERE w.cause_key='BRIDGE:'||r.id)
    //    -- balance_after fixed below in one pass
    // Then recompute balance = SUM(credit)-SUM(debit) once and UPDATE
    // wallet_accounts, then backfill balance_after for new rows? balance_after
    // must be accurate per-row for audit (contract). Two options:
    //  a) Java loop: fetch unbridged reward txs ORDER BY created_at, insert each
    //     with running balance — simple, N small (≤ lessons completed count).
    //  b) SQL window function: balance_after = running SUM over created_at.
    // Prefer (b): single statement, still deterministic:
    //    WITH new_rows AS (
    //      SELECT r.id, r.amount, r.created_at,
    //             SUM(r.amount) OVER (ORDER BY r.created_at, r.id) AS run
    //        FROM reward_transactions r
    //       WHERE r.user_id=:u AND r.reward_type='HISTORY_POINTS'
    //         AND NOT EXISTS (...)
    //    ) INSERT ... SELECT ..., :currentBalance + run, ...
    // Then UPDATE wallet_accounts SET balance = balance + SUM(new credits).
    // Edge: interleaved DEBIT rows already committed while bridging later
    // credits — running total must be balance_at_time = existing ledger
    // state replayed... KISS decision: bridge ONLY runs when account is
    // fresh (created now) OR when called before any debit. Since wallet is
    // new in V32 and debit only via shop purchase (same service), ordering:
    // every mutation path calls lockedAndBridged FIRST → credits always
    // bridged before debits exist → running-total formula stays correct.
    // Document invariant in javadoc: "bridge-before-any-debit, enforced by
    // calling this on every entry point under the account row lock".
}

@Transactional WalletView view(UUID userId);          // GET /me/wallet
@Transactional long balanceOf(UUID userId);           // internal use

// Debit for purchases — called by ShopService inside purchase tx:
// 1. lockedAndBridged
// 2. balance < amount → InsufficientFundsException
// 3. ledger insertIgnore FIRST (cause_key from purchase op) — if 0, reconcile
//    balance from stored cause and return 0 (idempotent retry path)
// 4. account.debit(amount); save; return amount
@Transactional(propagation=REQUIRED)
long debit(UUID userId, long amount, String causeKey, String reason,
           String referenceJson);
```

`WalletView` DTO: `record WalletView(String currency, long balance, long earned, long spent, Instant serverTime)` + separate paged `WalletTxView` list endpoint support (earned/spent via `sumByDirection`; balance from account row — consistency guaranteed under lock for writes; reads readOnly=true no lock needed, bridge still runs on write paths only... careful: read-only view must ALSO show bridged balance — run `lockedAndBridged` in `@Transactional` (not readOnly) on GET too, since bridging IS a write. First GET creates+bridges. Acceptable.)

## Files to modify

- `reward/infrastructure/persistence/RewardTransactionRepository.java` — verify it has `findByUserIdAndRewardType` or add `List<RewardTransaction> findByUserIdAndRewardTypeOrderByCreatedAtAsc(UUID, String)` if missing (check file first; native bridge query may not even need entity method — the bridge INSERT..SELECT lives in `WalletTransactionRepository` as native query; only need reward TYPE constant `RewardTransaction.TYPE_HISTORY_POINTS` which exists).

## Key contract points

- NEVER insert into `reward_transactions` (POINT-09, CHECK amount>0).
- `currency` always `'HISTORY_POINTS'` V1 — service constant `WalletService.CURRENCY`.
- Lock order discipline: `wallet_accounts` is the FIRST lock in purchase flow (before `user_inventory` insert, before any island row). Document: `learner_attempts` → `user_energy` → `wallet_accounts` → `user_inventory`/`user_islands` global order (§5 contract fixed order; purchase only touches the last three — keep wallet first).
- Ledger-first debit: `insertIgnore` returns 0 → cause already committed → reconcile (set balance=stored.balance_after) → return 0. Prevents double-debit on any retry path, same as EnergyService FIX 1.
- Reason set: V1 uses `BRIDGE_CREDIT`, `SHOP_PURCHASE`. `ADMIN_ADJUST` reserved (CHECK allows, no service path — YAGNI but keeps schema forward-compatible).

## Todo

- [ ] Read `EnergyTransactionRepository` for StoredCause/insertIgnore signature shape
- [ ] Create domain entities + exception
- [ ] Create repositories (bridge native query)
- [ ] WalletService (view/balanceOf/debit/lockedAndBridged)
- [ ] `mvnw compile` green; entity validation deferred to IT boot

## Success criteria

- Fresh user: view → balance 0, earned=spent=0, one account row, zero wallet txs.
- User with 2 HISTORY_POINTS reward credits (e.g. 50+50): first view → balance=100, earned=100, 2 `BRIDGE_CREDIT` rows, `source_ref` = reward tx ids.
- Debit 30 with balance 100 → balance 70, DEBIT row balance_after=70. Same cause_key retry → return 0, balance stays 70.
- Debit 30 with balance 20 → `InsufficientFundsException`, no ledger row, no balance change (all-or-nothing).

## Risks

- Bridge correctness under concurrency: two simultaneous first-requests → both `insertIgnore` account, winner row lock serializes; loser's `findForUpdate` waits, then bridges sees causes already present → no-op. Safe by design.
- `@IdClass` composite key boilerplate vs single-column PK: keep composite — matches contract schema; Hibernate supports cleanly.
- Reconcile path (`cause exists but row balance_after stale`) — mirrors EnergyService; keep same semantics for consistency.

## Security

- All methods take `userId` from service callers (JWT-derived at controller); no user-supplied amount/cause_key without validation upstream.
