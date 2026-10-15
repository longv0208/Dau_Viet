# Code Review — TASK-0007 Phase B+C: Authentication & Authorization backend

**Reviewer:** code-reviewer
**Date:** 2026-10-15
**Scope:** working-tree changes vs base `d1763c1` (plan `plans/261015-2204-auth-implementation/`, phases 01–05)
**Build check:** `mvnw -q test-compile` green (JAVA_HOME=E:\Java\jdk-21). Unit tests reported green by implementer; ITs NOT VERIFIED (Docker down) — accepted as residual risk.

## Verdict

**PASS-WITH-NOTES** — implementation is correct, secure, and matches the plan + ACs. No blocking findings. Notes below are non-blocking improvements and residual risks.

## Findings (ranked)

### Medium

- **M1 — Refresh-rotation order: presented token revoked before user-status check.** `RefreshTokenService.rotate()` (src/main/java/com/dauviet/auth/application/RefreshTokenService.java:93–102) sets `revokedAt`/`lastUsedAt` on the presented token before loading the user; if the user is LOCKED/DISABLED the whole family is revoked anyway, so the outcome is correct — but the ordering isn't commented. A future refactor that returns early could leave the presented token half-revoked. Non-blocking readability note.

- **M2 — Register lacks the plan's fast-path pre-check.** Phase-02 said "pre-check `findByEmailIgnoreCase` AND catch DataIntegrityViolationException"; implementation keeps only the catch (AuthService.java:73–77). Still correct and race-safe (unique index `ux_users_email_lower` is authoritative → 409 EMAIL_TAKEN). Every duplicate attempt costs a failed INSERT + exception — acceptable at MVP volume. Plan deviation only.

- **M3 — `ddl-auto=validate` not proven locally.** Entity↔V2 mapping verified by eye: `User` matches `users` (11 columns + `row_version` `@Version`); `RefreshToken` matches `auth_refresh_tokens` (9 columns). Both clean. Actual validation requires FlywayMigrationIT/context boot on Docker — currently NOT VERIFIED.

### Low

- **L1 — `AdminPingIT` unused imports/field** (`MvcResult`, `JsonNode`, `ObjectMapper om`, `MediaType`, `MockMvcRequestBuilders` — src/test/java/com/dauviet/admin/AdminPingIT.java:15,23–26,39). Cosmetic.
- **L2 — `AuthService.buildTokenResponse(user, previous)`:** `previous` is always null at the only call site. Dead param, could inline `issue(user, null)`.
- **L3 — `UserService.getProfile` → `ResourceNotFoundException`** maps to `EVENT_NOT_FOUND` code (`GlobalExceptionHandler:88`). Plan flagged this knowingly; a deleted-user-with-valid-JWT gets correct 404 status with semantically-wrong code. Follow-up: generic `NOT_FOUND` code.
- **L4 — `userLoader` Function field** obscures a plain `UserRepository.findById` inside the same tx. Style nit.
- **L5 — Broad `permitAll POST /api/v1/auth/**`:** fine today (register/login/refresh/logout all public), but a future authenticated POST under `/auth/` (e.g. change-password) would silently be public. Flag for whichever task adds the next auth endpoint; consider narrowing to explicit paths then.
- **L7 — No `iss` validator on decoder** (`NimbusJwtDecoder.withSecretKey` defaults: signature+expiry only). Single-issuer monolith sharing one secret — theoretical. One-line `JwtValidators.createDefaultWithIssuer(ISSUER)` hardening available.

### Security audit answers

- **Register role elevation:** impossible — non-blank `role` → 400 (`AuthService:63`); always `LEARNER`. IT `register_roleSupplied_400` covers.
- **Raw token logged/stored:** never — SHA-256 only (`RefreshTokenService:64,126`); replay log uses ids only. `TokenResponse` carries raw to client exactly once.
- **Login timing leak:** `DUMMY_BCRYPT` compare on unknown email; identical 401 envelope for all failures; LOCKED/DISABLED uniform via `status != ACTIVE`.
- **Refresh replay:** `PESSIMISTIC_WRITE` row lock + `@Transactional` → concurrent double-refresh: loser sees revoked → family revoked → both 401. Correct theft-containment. Expired → 401 without family revoke (per plan).
- **JWT secret:** empty default → `JwtConfig:34` fail-fast <32 bytes. Local fallback only in `application-local.yml`. Never logged.
- **401 vs 403:** entry point → 401 unauthenticated; access-denied → 403 wrong-role. AdminPingIT covers all three legs.
- **`/users/me` malformed sub:** → 401, defensive.
- **Admin bootstrap:** local profile + seed flag + env-driven, insert-only, never promotes/logs password. No self-registration to CONTENT_ADMIN. AC-9 satisfied.

## AC compliance

| AC | Status | Evidence |
|---|---|---|
| AC-3 register | PASS | normalize+LEARNER+role-reject+BCrypt+409; `AuthServiceTest` green, `AuthControllerIT` written (NOT VERIFIED) |
| AC-4 login | PASS | uniform 401 + timing blunting + status gate + last_login_at; unit+IT |
| AC-5 refresh | PASS | rotate/replay/family chain; `AuthRefreshIT` written (NOT VERIFIED) + unit green |
| AC-6 logout | PASS | idempotent 204; IT written |
| AC-7 /users/me | PASS | record DTO, no hash field; IT written |
| AC-8 JWT/gating | PASS | HS256, configurable TTLs, env secret, stateless, `hasRole` admin, events public |
| AC-9 bootstrap | PASS | `AdminBootstrapRunner` + runbook SQL alt |
| AC-10 tests | PARTIAL | All 15 flows mapped to named tests; unit+slice green; 6 ITs NOT VERIFIED (Docker) — honest per policy |
| AC-11 docs | PASS | API_SPEC + runbook updated; no secrets committed |

## Plan deviations (all acceptable)

- Register pre-check dropped (catch-only) — M2.
- `InvalidCredentialsException` named `AuthenticationFailedException` — better name.
- Bootstrap env-missing logs at info not warn — cosmetic.
- `UserProfileDto` includes `status` — per plan, self-only exposure.

## Residual risks

1. **Six IT classes unverified** — matcher order, `@Modifying` syntax, validate-mode column match, TC boot could still hide bugs. `mvnw verify` on a Docker host is the real gate.
2. Concurrent-login `last_login_at` via `@Version` could throw optimistic-lock 500 on simultaneous logins — rare, untested, acceptable.
3. No login rate-limit/lockout (plan non-goal) — future hardening.
4. `role` claim → authority verbatim; safe because minting reads DB role. Re-audit if users ever gain a role-edit path.

## Recommended actions (non-blocking)

1. `mvnw verify` on Docker host; record IT outcomes in task.json.
2. Follow-up: generic `NOT_FOUND` code for non-event 404s (L3).
3. Follow-up: rate limiting + lockout (plan non-goal).
4. Optional: drop AdminPingIT unused imports (L1); remove dead `previous` param (L2); add issuer validator (L7).

## Unresolved questions

- Does harness policy need an explicit `docs/PROGRESS.md` regen after acEvidence update? Phase-05 defers to harness — confirm at finish.
