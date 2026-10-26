# Phase 05 — Controllers, DTOs, error-code plumbing

**Priority:** P1 · **Status:** pending · **Depends on:** Phases 02, 03, 04

## Context

- Pattern: `RewardController`/`EnergyController` — `@RestController`, `/api/v1/...`, `JwtSubjectExtractor` for userId (never from client), constructor injection.
- `ApiError` envelope already: `{code,message,details,traceId}`; `GlobalExceptionHandler` is a `@RestControllerAdvice` — add handlers per new exception.

## Files to create

### island/api/
- `IslandController.java`:
  ```
  GET    /api/v1/me/island                      → IslandView
  POST   /api/v1/me/island/upgrade              body {expectedRevision} → IslandView
  PUT    /api/v1/me/island/placements/{slotId}  body {itemId, expectedRevision} → IslandView
  DELETE /api/v1/me/island/placements/{slotId}  → IslandView (200) — idempotent
  ```
  `slotId` path var `UUID` → malformed → MALFORMED_ID via existing type-mismatch handler (name must be "id"? Existing handler keys on `ex.getName().equals("id")` — name the path variable `slotId` → falls to VALIDATION_ERROR 400. Acceptable; or rename param to make it work — check: handler does `"id".equals(ex.getName())` → name it `@PathVariable("slotId") UUID slotId` gives 400 VALIDATION_ERROR anyway. Fine either way; document.)

### shop/api/
- `ShopController.java`:
  ```
  GET  /api/v1/shop/items              → List<ShopItemView>
  POST /api/v1/me/shop/purchases       header Idempotency-Key (required)
                                       body {itemId} → PurchaseView
  ```
  Task spec says `GET /shop/items` (no /me prefix — it's the public catalog) and `POST /me/shop/purchases` (user-scoped). Keep exactly those paths.

### wallet/api/
- `WalletController.java`:
  ```
  GET /api/v1/me/wallet               → WalletView {currency,balance,earned,spent,serverTime}
  GET /api/v1/me/wallet/transactions  → PageResponse<WalletTxView> (page/size, size≤50)
                                        — include? Task lists only GET /me/wallet.
                                        Ledger endpoint is one extra repo call +
                                        PageResponse plumbing already proven —
                                        include it: QA + admin debugging need it,
                                        and contract §11.2 lists it for GAME-07.
                                        Cheap now, no rework later. INCLUDE.
  ```

### dto files (each package api/dto/)
- `IslandView`, `SlotView`, `PlacedItem`, `UpgradeIslandRequest`, `PlacementRequest`
- `ShopItemView`, `PurchaseRequest` (`@NotNull UUID itemId`), `PurchaseView`
- `WalletView`, `WalletTxView`

## Files to modify

- `common/error/ErrorCode.java` — append enum values (order matters only for readability): `INSUFFICIENT_FUNDS, ITEM_NOT_OWNED, ITEM_ALREADY_OWNED, ITEM_NOT_PLACEABLE, SLOT_LOCKED, SLOT_OCCUPIED, ISLAND_UPGRADE_NOT_ELIGIBLE, STALE_ISLAND_REVISION, ITEM_NOT_FOR_SALE, FEATURE_DISABLED` (IDEMPOTENCY_CONFLICT, NOT_FOUND exist).
- `common/error/GlobalExceptionHandler.java` — add handlers:
  | Exception | HTTP | Code | Details |
  |---|---|---|---|
  | `InsufficientFundsException` | 409 | INSUFFICIENT_FUNDS | {balance, required} |
  | `ItemNotOwnedException` | 403 | ITEM_NOT_OWNED | {itemId} |
  | `ItemAlreadyOwnedException` | 409 | ITEM_ALREADY_OWNED | {itemId} |
  | `ItemNotPlaceableException` | 422 | ITEM_NOT_PLACEABLE | {itemId, slotId?} |
  | `SlotLockedException` | 403 | SLOT_LOCKED | {slotId, unlockTier, currentTier} |
  | `SlotOccupiedException` | 409 | SLOT_OCCUPIED | {slotId} |
  | `UpgradeNotEligibleException` | 422 | ISLAND_UPGRADE_NOT_ELIGIBLE | {required, completed} |
  | `StaleRevisionException` | 409 | STALE_ISLAND_REVISION | {expected, current} |
  | `ItemNotForSaleException` | 422 | ITEM_NOT_FOR_SALE | {itemId, reason} |
  | `FeatureDisabledException` | 503 | FEATURE_DISABLED | {} |
  | `SlotNotFoundException` | 404 | NOT_FOUND | {slotId} |

  StaleRevisionException placed BEFORE the generic `OptimisticLockingFailureException` handler (both 409 but different codes — subclass ordering: `@ExceptionHandler` matches most specific first anyway if it's not a subclass; keep it a plain RuntimeException, no inheritance link).

- `reward/api/dto/InventoryItemResponse.java` — task: "GET /me/inventory them placeable/placedSlotId tuong thich nguoc" → add two trailing record fields `Boolean placeable, UUID placedSlotId` (record components are positional; adding fields changes canonical ctor — internal code constructs it in 2 places in RewardService + AdminItemService? grep `new InventoryItemResponse` and update all call sites; JSON output gains two fields — backward compatible for clients).
- `reward/application/RewardService.java` — populate new fields: `placeable` from ItemCatalog; `placedSlotId` requires join to `user_island_placements` — inject `UserIslandPlacementRepository`, batch-fetch placements for user's items (one `findByUserId` → map itemId→slotId). Additive only.
- `common/config/SecurityConfig.java` — check route rules: all new endpoints are authenticated learner endpoints — likely covered by `/api/v1/**` authenticated default; verify `/api/v1/shop/items` isn't accidentally permitted-all or admin-only. Read file, adjust only if needed.
- `application.yml` — add `dauviet.shop.enabled: true` under existing `dauviet:` section (check current yml layout — energy props live under `dauviet.energy.*`? grep).

## Request validation

- `PlacementRequest`/`UpgradeIslandRequest`/`PurchaseRequest` → `@Valid` + `@NotNull` fields; null → 400 VALIDATION_ERROR (existing handler).
- `Idempotency-Key` header: `@RequestHeader("Idempotency-Key") String` (required=true default) → missing → MissingRequestHeaderException — existing handler? GlobalExceptionHandler has `MissingServletRequestParameterException` but maybe not header variant — check; if unhandled it becomes generic 500 → add `@ExceptionHandler(MissingRequestHeaderException.class)` → 400 VALIDATION_ERROR {parameter: header name}. Verify + add if missing.

## Todo

- [ ] Grep `new InventoryItemResponse` — update all ctor call sites (record arity +2)
- [ ] Create 3 controllers + DTOs
- [ ] Extend ErrorCode + GlobalExceptionHandler (+ MissingRequestHeaderException handler if absent)
- [ ] RewardService inventory enrichment (placeable + placedSlotId)
- [ ] Check SecurityConfig + application.yml
- [ ] `mvnw compile`

## Success criteria

- All 8 endpoints reachable, JWT-scoped; error envelope identical shape to existing APIs.
- `/me/inventory` response has `placeable`/`placedSlotId` (null when not placed); old fields unchanged.

## Risks

- Record arity change breaks other constructors — grep catches all.
- Missing-header 500 leak — verify handler exists, add if not.
- `GET /shop/items` unauthenticated by accident → explicit SecurityConfig check.
