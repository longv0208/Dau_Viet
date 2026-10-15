# Phase 04 — Refresh rotation, logout, admin bootstrap

## Context Links

- Phase-02 (AuthService, RefreshTokenService.issue, RefreshTokenRepository, RefreshRequest/TokenResponse DTOs).
- V2 `auth_refresh_tokens` columns incl. `token_family_id`, `previous_token_id`, `revoked_at`, `last_used_at`.
- `EventSeedRunner` pattern (Profile local + ConditionalOnProperty app.seed.enabled).
- AC-5, AC-6, AC-9.

## Overview

Implement POST `/api/v1/auth/refresh` (rotation with reuse detection → family revocation), POST `/api/v1/auth/logout` (idempotent revoke), and `AdminBootstrapRunner` seeding a CONTENT_ADMIN from env vars under local profile.

## Requirements

### Refresh flow (`AuthService.refresh(String rawToken)` or `RefreshTokenService.refresh` — put rotation in RefreshTokenService, called from AuthService to keep controller thin)

1. `hash = sha256Hex(raw)`; `repo.findByTokenHash(hash)` → absent → 401 `INVALID_CREDENTIALS` (uniform with other token failures).
2. If `revokedAt != null` → REPLAY detected: `revokeFamily(token.tokenFamilyId)` (set revoked_at=now on all family rows where revoked_at is null) → 401.
3. If `expiresAt < now` → 401 (no family revocation needed — expiry isn't theft signal; still revoke just this token? No: leave as is, it's dead anyway).
4. Else rotate: set `revokedAt=now`, `lastUsedAt=now` on old row; issue new token with `previousTokenId=old.id`, same `tokenFamilyId`; new access token for user. Check user still ACTIVE — if LOCKED/DISABLED since issue → 401 + revoke family (cheap safety).
5. Return `TokenResponse`.

### Logout flow

- POST `/auth/logout` body `{refreshToken}` (optional auth — endpoint permitAll under `/api/v1/auth/**`; logout needs no access token since access may already be expired). If hash found and not revoked → set revokedAt=now. If absent/already revoked → still 204. Idempotent by design.
- Response: `204 No Content` (or 200 `{status:"ok"}` — pick 204, REST-clean; document).

### Family revocation

`RefreshTokenService.revokeFamily(UUID familyId)`: bulk `UPDATE auth_refresh_tokens SET revoked_at=now() WHERE token_family_id=:f AND revoked_at IS NULL` via `@Modifying @Query` on repository — efficient, no row loading.

### Admin bootstrap

`auth/infrastructure/seed/AdminBootstrapRunner.java` implementing ApplicationRunner:
- `@Profile("local")` + `@ConditionalOnProperty(name="app.seed.enabled", havingValue="true")` — same guard as EventSeedRunner.
- Reads env via `@Value`/`Environment`: `ADMIN_EMAIL`, `ADMIN_PASSWORD`, optional `ADMIN_DISPLAY_NAME`.
- If env missing → log warn "admin bootstrap skipped (ADMIN_EMAIL/ADMIN_PASSWORD unset)" — NOT fail-fast (dev convenience; document runbook). DECIDE: skip-with-warn, not crash — matches optional-seed spirit.
- If user with email exists → ensure role=CONTENT_ADMIN? NO — insert-only like EventSeedService: if exists, log and skip (never overwrite local edits, never silently promote).
- Else create user role=CONTENT_ADMIN, status=ACTIVE, BCrypt password.
- Documented SQL alternative in runbook for non-local envs.

## Related Code Files

Create:
- `auth/infrastructure/seed/AdminBootstrapRunner.java`.

Modify:
- `auth/application/RefreshTokenService.java` — add `rotate(String raw)` → returns record `RotatedTokens(RefreshToken newToken, User user)` or have it return new raw token + user; add `revokeFamily`, `revokeByRawToken` (logout).
- `auth/infrastructure/persistence/RefreshTokenRepository.java` — add `Optional<RefreshToken> findByTokenHash(String)`, `@Modifying @Query int revokeActiveByFamily(UUID familyId, Instant now)`.
- `auth/application/AuthService.java` — add `refresh(RefreshRequest)` → TokenResponse; `logout(RefreshRequest)` (reuse RefreshRequest DTO = {refreshToken}).
- `auth/api/AuthController.java` — add POST `/refresh` → 200 TokenResponse; POST `/logout` → 204.

## Implementation Steps

1. Repository: `findByTokenHash`, `revokeActiveByFamily` modifying query, `findByTokenFamilyIdAndRevokedAtIsNull` (optional, tests may want it).
2. RefreshTokenService: `rotate(raw)` implementing steps 1–4 above in one `@Transactional`; `revoke(raw)` for logout (`revoked_at=now` if present & active); `revokeFamily(familyId)`.
3. AuthService: `refresh` calls rotate → builds TokenResponse via jwtTokenService; `logout` calls revoke. Both uniform 401 on failure.
4. AuthController: two endpoints. RefreshRequest `{refreshToken}` `@NotBlank`.
5. AdminBootstrapRunner per above.
6. test-compile green.

## Todo

- [ ] Repository queries (findByTokenHash, revokeActiveByFamily)
- [ ] RefreshTokenService.rotate + replay family revocation
- [ ] RefreshTokenService.revoke (logout idempotent)
- [ ] AuthService.refresh/logout
- [ ] AuthController /refresh + /logout
- [ ] AdminBootstrapRunner (local+seed, env-driven, insert-only)
- [ ] test-compile green

## Success Criteria

- Rotation: old token revoked, `previous_token_id` points at old row, same family id; new pair works.
- Replaying revoked token → 401 AND all active family tokens revoked (provable in IT: subsequent refresh with the NEW token also 401s).
- Expired token → 401.
- Logout → 204; retry → 204; refresh after logout → 401.
- Local boot with ADMIN_* env + seed enabled creates CONTENT_ADMIN; second boot no-op.

## Security Considerations

- Family revocation is the theft-detection core — must run in same tx as detection read (or immediately after) — use `@Transactional` on rotate.
- Replay response is same 401 envelope as bad credentials — don't leak "reuse detected" to client; DO log.warn server-side (security audit signal) without token value (log token id/family id only).
- Raw refresh token never persisted/logged; only sha256.
- Admin runner never logs the password; logs email only.

## Risk

- `@Modifying` bulk query bypasses persistence context — call `entityManager.clear()` not needed if test asserts via fresh repo calls; fine.
- Concurrency: two parallel refreshes of same token — first rotates (revoked_at set), second sees revoked → family revocation. Acceptable (strict mode); document that rapid client retry should reuse the new token, and add `@Version`? auth_refresh_tokens has no row_version column — rely on revoked_at check inside tx + DB row lock via `findByTokenHash` with `@Lock(PESSIMISTIC_WRITE)`? Simpler: unique on token_hash + revoked-check is enough for MVP; note concurrent double-refresh as known limitation → family revoke is the safe outcome anyway (both parties get 401, user re-logs). Document, don't over-engineer (YAGNI).
