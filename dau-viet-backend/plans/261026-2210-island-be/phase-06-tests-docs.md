# Phase 06 — Integration tests + unit tests + cleanup + docs

**Priority:** P1 · **Status:** pending · **Depends on:** Phase 05

## Context

- IT base: `AbstractPostgresIT` (shared postgres:16-alpine, `@ServiceConnection`, Flyway on, `ddl-auto=validate` — first boot validates ALL entities vs V32).
- Fixture: `AttemptItFixture.token/users/jwt/newEvent/newTemplate/newEvidence/draftTwoStage/publishLesson/startAttempt` — reuse for user+JWT; island/shop ITs mostly need `token()` + direct `JdbcTemplate` inserts (wallet credits via `reward_transactions` insert, inventory grant via insert, event progress rows via insert).
- MockMvc JWT pattern: `.header("Authorization", token)`.
- File location convention: `src/test/java/com/dauviet/{island,shop,wallet}/` new dirs.

## Files to modify

- `src/test/java/com/dauviet/AbstractPostgresIT.java` — add to `clearAuthoringTables`, BEFORE `delete from users`-adjacent section and after dependent tables. Correct FK order (children first):
  ```java
  jdbc.update("delete from user_island_placements");
  jdbc.update("delete from user_islands");
  jdbc.update("delete from wallet_transactions");
  jdbc.update("delete from wallet_accounts");
  jdbc.update("delete from island_shop_items");
  jdbc.update("delete from island_slots");
  jdbc.update("delete from island_tier_policies");
  ```
  Order within method: placements/islands after `user_inventory` delete is fine (placement FK→item_catalog only, not user_inventory). wallet_* anywhere before `users` delete (users deleted in caller ITs, not here — this method doesn't delete users; it clears tables that FK INTO users/attempts so callers can). Put the block near the streak section with a comment `// V32: island+wallet tables`.
  BUT: `island_shop_items`/`island_slots`/`island_tier_policies` are SEEDED config — deleting them in clearAuthoringTables breaks island tests that rely on seeds when another test ran cleanup first! Decision: clear ONLY user-scoped tables (`user_island_placements`, `user_islands`, `wallet_transactions`, `wallet_accounts`). Config tables (slots/policies/shop items/DECOR catalog) are migration seeds — leave them; if an IT mutates them, that IT restores. Matches how `item_catalog` (V12 seed) is handled today (not in clear list). Verify: `user_inventory` IS cleared — decor ownership rows get cleaned. Good.

## Test files to create

### `src/test/java/com/dauviet/island/IslandApiIT.java`
Covers task test matrix (island half):
1. **new user gets tier1 + 4 slots** — GET /me/island on fresh user → tier=1, 4 unlocked slots (T1_S1..S4), 8 locked, revision=0? (lazy-create → row_version starts 0; assert `revision` field present).
2. **no default items** — `slots[].placed` all null.
3. **place unowned item → 403 ITEM_NOT_OWNED** (insert slot exists; don't grant inventory).
4. **place to locked slot → 403 SLOT_LOCKED** (user tier1 → T2_S5).
5. **place then GET persists** — grant decor item via `insert into user_inventory` (acquisition_source='SHOP_PURCHASE' now allowed), PUT → GET shows placed with code/renderKey.
6. **move item slot→slot atomic** — place on S1, PUT same item to S2 → moved (S1 empty, S2 has item), no duplicate (UNIQUE(user,item)).
7. **PUT different item to occupied slot → 409 SLOT_OCCUPIED**.
8. **same item same slot re-PUT → idempotent 200**.
9. **one item one slot** — covered by 6 (assert count rows=1 in `user_island_placements` via jdbc).
10. **two users isolated** — userA places; userB GET own island → empty; userB PUT to own slot unaffected.
11. **cannot view/edit others' island** — endpoints are `/me/*` only (no userId param) → implicit; test that userA's placements don't leak into userB response.
12. **two devices same slot concurrent** — sequential MockMvc (true concurrency optional; existing `LearnerAttemptConcurrencyIT` uses threads — reuse pattern if present): two PUTs different items, same slot → one wins, other gets 409 (SLOT_OCCUPIED or STALE). Simpler deterministic test: second PUT with stale expectedRevision → 409 STALE_ISLAND_REVISION.
13. **stale revision rejected** — PUT with expectedRevision=0 after one successful mutation bumped it → 409 STALE_ISLAND_REVISION.
14. **DELETE removes placement** — then re-place works.
15. **non-placeable item → 422 ITEM_NOT_PLACEABLE** — grant a COMMEMORATIVE_BADGE item (seed exists: HUY_HIEU_*), try place.

### `src/test/java/com/dauviet/island/IslandUpgradeIT.java`
16. **upgrade by event count** — insert `user_event_progress` rows directly (`EVENT_COMPLETED` x2) → POST upgrade {expectedRevision:0} → tier=2, 8 slots unlocked. Then x4 rows → tier=3.
17. **insufficient events → 422 ISLAND_UPGRADE_NOT_ELIGIBLE** (details required/completed).
18. **policy change doesn't demote** — user tier2; `update island_tier_policies set required_events_completed=99 where tier=2` (or insert new config_version inactive/active swap) → GET island still tier=2; eligibility for next tier recomputes with new policy.
19. **revision required** — POST upgrade with wrong expectedRevision → 409.

### `src/test/java/com/dauviet/wallet/WalletIT.java` (or fold into ShopIT)
20. **bridge on first view** — insert 2 `reward_transactions` HISTORY_POINTS credits (+50 each, distinct cause_key) → GET /me/wallet → balance=100, earned=100, 2 BRIDGE_CREDIT rows in `wallet_transactions` (jdbc assert), `source_ref` set.
21. **bridge idempotent across reads** — second GET → same balance, still 2 rows (no dup despite ON CONFLICT).
22. **debit insufficient → no side effects**.

### `src/test/java/com/dauviet/shop/ShopPurchaseIT.java`
23. **GET /shop/items** — 4 SKUs listed, DECOR_CAU_KIEU `purchasable=false` (price null), prices correct, `owned=false`.
24. **purchase success** — seed wallet (insert wallet_accounts + tx OR rely on bridge from reward credit), POST with Idempotency-Key → 200, balance reduced, inventory row `SHOP_PURCHASE`, DEBIT ledger row.
25. **purchase insufficient funds → 409 INSUFFICIENT_FUNDS**, no inventory/ledger changes (jdbc counts).
26. **repurchase owned → 409 ITEM_ALREADY_OWNED** (different key).
27. **same key same body retry → same response, no double debit** (count DEBIT rows=1, balance unchanged).
28. **same key different itemId → 409 IDEMPOTENCY_CONFLICT**.
29. **non-shop item → 422 ITEM_NOT_FOR_SALE** (use HUY_HIEU item id).
30. **price-null item → 422 ITEM_NOT_FOR_SALE**.
31. **atomic rollback** — force failure after debit? Hard to inject mid-tx; approximate: purchase item that exists in shop but insertIgnore returns 0 due to concurrent grant — simulate by granting item between? Skip artificial fault injection; cover via 26 (owned check) + trust tx semantics. Alternatively test that INSUFFICIENT leaves zero wallet_transactions rows — proves rollback atomicity for the failing path. Acceptable.
32. **shop never sells achievements** — try buying dossier/lesson UUID → 422/404; assert HUY_HIEU codes absent from /shop/items list.
33. **FEATURE_DISABLED** — `@TestPropertySource(properties="dauviet.shop.enabled=false")` on separate class → 503.

### `src/test/java/com/dauviet/island/InventoryEnrichmentIT.java` (fold into IslandApiIT if small)
34. **GET /me/inventory** shows `placeable=true` for DECOR item, `placedSlotId` populated after placement, null fields for non-decor.

### Unit tests (src/test/java, plain JUnit — check existing unit test pattern; repo may be IT-only → if no unit test infra exists, cover logic via ITs only and note deviation. Grep `src/test/java` for non-IT tests first.)
- WalletService bridge ordering logic — skip if no unit infra; IT coverage sufficient per "IT PostgreSQL/Testcontainers + unit (trong task)" — task says tests required; ITs cover all listed cases. Add unit tests only where repo already has them (`reward/application/*Test` — check).

### Migration smoke
- Flyway fresh DB: covered — every IT boots fresh container.
- "Flyway có data": Testcontainers always migrates from empty — the CHECK-alter path on populated data: simulate by IT that inserts inventory rows (sources already-valid values) — V32 runs before any test data anyway. To test alter-on-existing-rows, would need pre-V32 snapshot — impractical; note as residual risk, rely on superset-CHECK reasoning (adding enum values never invalidates existing rows).

## Docs updates

- `docs/API_SPEC.md` — add rows to learner table:
  | GET | `/me/island` | island view | **implemented ISLAND-BE-01** |
  | POST | `/me/island/upgrade` | {expectedRevision} | implemented |
  | PUT/DELETE | `/me/island/placements/{slotId}` | placement write | implemented |
  | GET | `/shop/items` | shop catalog | implemented |
  | POST | `/me/shop/purchases` | Idempotency-Key required | implemented |
  | GET | `/me/wallet` (+ `/transactions`) | wallet view/ledger | implemented |
  Add error codes to the error section if a table exists (grep file for error-code table; it has HTTP table §1 — add the new codes in relevant endpoint notes + a short "Island/Shop error codes" bullet list).
- `docs/DATABASE_DESIGN.md` — append V32 tables to the table list (check format, keep concise).
- `docs/GAMIFICATION_GAP_REPORT.md` — only if it has a task checklist mentioning ISLAND/wallet; check + mark implemented.
- `docs/project-changelog.md` — add entry: ISLAND-BE-01 backend.
- NO edits to business-rules/technical-contract docs (they're the spec source, not changelogs).

## Todo

- [ ] Update `clearAuthoringTables` (4 user-scoped tables only)
- [ ] Write 4-5 IT classes covering numbered cases
- [ ] Check for existing unit-test pattern; add unit tests if infra exists
- [ ] Update API_SPEC.md, DATABASE_DESIGN.md, project-changelog.md
- [ ] Run `.\mvnw.cmd -B -ntp verify` — ALL green (existing + new)

## Success criteria

- Every numbered scenario above passes; zero new warnings on error mapping (each error code exercised ≥1 IT).
- `mvn verify` green end-to-end.

## Risks

- Shared Postgres container + seeded config tables: an IT deleting `island_slots` corrupts later tests in same JVM — rule: ITs never delete/UPDATE seed tables except `island_tier_policies` in the demote test — and that test restores rows in `@AfterEach` (delete+reinsert or save original).
- MockMvc concurrency tests are flaky — prefer sequential stale-revision determinism; if doing real threads, reuse `LearnerAttemptConcurrencyIT` ExecutorService pattern.
- JWT token helper creates user via repository (not SQL) — wallet/island lazy-create relies on `users` FK — fine.
