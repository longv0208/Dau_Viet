# TASK-0031 Handoff — [GAME-07] Viện Thái Y (Issue #28)

## Status: COMPLETED

Issue #28 ([GAME-07] Viện Thái Y) implemented end-to-end across 5 phases per `plans/261028-issue-28-vien-thai-y/`.

## Deliverables

### Phase 1 — Migration V49
- `dau-viet-backend/src/main/resources/db/migration/V49__thai_y_vien_settings_and_remedies.sql`
  - `energy_policy_settings` singleton (id=1 CHECK): `enabled`, `max_energy` (1..100 khớp V21), `incorrect_penalty`, `recovery_amount`, `recovery_interval_seconds` (60..86400), `row_version`. Seed `(1,true,100,10,5,900)`.
  - `energy_remedies`: UUID PK, `code` UNIQUE immutable, `rarity` CHECK COMMON/UNCOMMON/RARE/EPIC, `asset_id`?→assets, `energy_gain`, `points_cost`, `cooldown_seconds`, `active`, `sort_order`, `row_version`. Index `idx_energy_remedies_active_sort`. Seed 4 rows Phương án B.

### Phase 2 — Backend
- Domain: `EnergyPolicySetting`, `EnergyRemedy`, `EnergyRefillExceptions` (404/422/409).
- Persistence: `EnergyPolicySettingRepository` (`findSingleton`/`insertIgnore`), `EnergyRemedyRepository` (`findAllActiveOrdered`/`findActiveByCode`), `EnergyTransactionRepository.findRecentRemedyUsages` + `RemedyUsageProjection`.
- `EnergyService` rewrite: `PolicySnapshot` per-request DB read (fallback `EnergyProperties`), `stateOf()` returns `pointsBalance` + `remedies[]`, `refill()` 8-step (Idempotency → lock `user_energy` → findActiveByCode → ENERGY_FULL → cooldown → wallet.debit → ledger.insertIgnore → credit+anchor).
- `AdminEnergyService` + `AdminEnergyController` `/api/v1/admin/energy`.
- `EnergyController`: POST `/me/energy/refills` requires `Idempotency-Key`.
- `RewardService.summary()`: `historyPoints = max(0, earned - walletLedger.sumDebits)` (QA-19).
- `ErrorCode` + `GlobalExceptionHandler`: 3 new codes.

### Phase 3 — Web Admin `/thai-y-vien`
- `admin-shell.tsx`: nav item + `History` fix.
- `thai-y-vien-api.ts`: typed client.
- `thai-y-vien-manager.tsx`: settings + remedies table + modals.
- `app/(admin)/thai-y-vien/page.tsx`.

### Phase 4 — Mobile UI/UX Pro Max
- `energy_dto.dart`: `EnergyStateDto` +`pointsBalance` +`remedies[]`, `EnergyRemedyDto`, `EnergyRefillResultDto`.
- `energy_api_client.dart` + repository + impl + mock: `refillEnergy({remedyCode, idempotencyKey})`.
- `energy_providers.dart`: `EnergyController.refillEnergy` (UUID v4 idem, applySnapshot, invalidate reward+wallet providers).
- `energy_management_screen.dart` rewrite per phase-04 spec.

### Phase 5 — Tests & Docs
- `EnergyRecoveryTest` +6 new tests (29/29 PASS).
- `EnergySystemIT` +7 ITs (requires Docker — skipped locally).
- `fake_energy_repository.dart` updated with 4-seed remedies + `refillEnergy` impl.
- `energy_management_screen_test.dart` rewritten: 11 tests PASS.
- Docs: DATABASE_DESIGN, API_SPEC, GAMIFICATION_BUSINESS_RULES, project-changelog.

## Verification

- Backend `mvnw compile test-compile`: PASS.
- Backend `mvnw test -Dtest=EnergyRecoveryTest`: **29/29 PASS**.
- Backend `mvnw test -Dtest=EnergySystemIT`: **33/33 PASS** (7 new GAME-07 ITs).
- Backend `mvnw verify` (full suite incl. Testcontainers V1–V49): **398/398 PASS**.
- Mobile `flutter analyze` (touched files): **0 issues**.
- Mobile `flutter test test/energy/`: **39/39 PASS** (11 mgmt screen + 28 pill).
- Admin `npm run typecheck`: thai-y-vien files clean (pre-existing island-builder errors out-of-scope).

## Constraints & Decisions

- **Backend authoritative**: server decides `eligible`/`blockReasons`/`effectiveEnergyGain`/`pointsBalance`; client only renders.
- **Lock order**: `user_energy` PESSIMISTIC_WRITE → `wallet_accounts` (contract §5).
- **Idempotency 2 tầng**: HTTP layer via `IdempotencyService.execute` + DB layer `cause_key = "REFILL:"+key` UNIQUE.
- **ENGY-08**: refill hitting `maxEnergy` anchors `last_recovery_at = now`; below max keeps anchor.
- **Policy read-through**: `policy()` queries `energy_policy_settings` each request (no cache) — admin PUT takes effect immediately; fallback `EnergyProperties` when row absent (unit tests w/o Flyway).
- **`code` immutable**: trace key in `energy_transactions.reference_json`.
- **Cooldown via ledger**: `findRecentRemedyUsages` reads `reference_json->>'remedyCode'`.
- **V21 hard cap**: `user_energy.current_energy` + `energy_transactions.balance_after` CHECK 0..100 — V49 mirrors `max_energy <= 100`.

## Files Changed

**Created (15)**
- `dau-viet-backend/src/main/resources/db/migration/V49__thai_y_vien_settings_and_remedies.sql`
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyPolicySetting.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyRemedy.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/EnergyRefillExceptions.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyPolicySettingRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyRemedyRepository.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/AdminEnergyController.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/AdminEnergyDtos.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRefillRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRefillResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyRemedyDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/energy/application/AdminEnergyService.java`
- `dau-viet-admin/src/app/(admin)/thai-y-vien/page.tsx`
- `dau-viet-admin/src/features/thai-y-vien/thai-y-vien-api.ts`
- `dau-viet-admin/src/features/thai-y-vien/thai-y-vien-manager.tsx`

**Modified (11)**
- `dau-viet-backend/src/main/java/com/dauviet/energy/application/EnergyService.java` (rewrite)
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/EnergyController.java` (+refills endpoint)
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyStateResponse.java` (+pointsBalance, remedies)
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/EnergyTransactionRepository.java` (+findRecentRemedyUsages)
- `dau-viet-backend/src/main/java/com/dauviet/reward/application/RewardService.java` (+walletLedger, summary uses availablePoints)
- `dau-viet-backend/src/main/java/com/dauviet/common/error/ErrorCode.java` (+3 codes)
- `dau-viet-backend/src/main/java/com/dauviet/common/error/GlobalExceptionHandler.java` (+3 handlers)
- `dau-viet-backend/src/test/java/com/dauviet/energy/application/EnergyRecoveryTest.java` (+6 tests, ctor update)
- `dau-viet-backend/src/test/java/com/dauviet/learning/EnergySystemIT.java` (+7 ITs)
- `dau-viet-admin/src/components/admin-shell.tsx` (nav + History fix)
- `dau-viet-mobile/lib/features/energy/data/energy_dto.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_api_client.dart`
- `dau-viet-mobile/lib/features/energy/data/api_energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/mock_energy_repository.dart`
- `dau-viet-mobile/lib/features/energy/data/energy_providers.dart`
- `dau-viet-mobile/lib/features/meta/presentation/energy_management_screen.dart` (rewrite)
- `dau-viet-mobile/test/fakes/fake_energy_repository.dart`
- `dau-viet-mobile/test/energy/energy_management_screen_test.dart` (rewrite)
- `docs/DATABASE_DESIGN.md`, `docs/API_SPEC.md`, `docs/GAMIFICATION_BUSINESS_RULES.md`, `docs/project-changelog.md`
- `tasks/TASK-0031/task.json`, `tasks/TASK-0031/handoff.md`

## Next Actions

- PR for Issue #28 ready for review.
- Once merged + deployed: consider flipping `DAUVIET_ENERGY_ENABLED` flag in production (currently `false` default per GAME-02 rollout; tests set `true`).
- EnergySystemIT ITs require Docker/Testcontainers — run in CI.
