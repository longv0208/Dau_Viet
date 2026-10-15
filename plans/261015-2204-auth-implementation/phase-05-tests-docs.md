# Phase 05 — Tests (15 flows) + docs

## Context Links

- Test patterns: `AbstractPostgresIT`, `FlywayMigrationIT`, `EventSeedServiceIT` (@DataJpaTest + Testcontainers), `HistoricalEventControllerTest` (@WebMvcTest + @MockitoBean), `ActuatorHealthIT` (@SpringBootTest).
- AC-10 (15 flows), AC-11 (docs).
- Env: Docker DOWN locally → all `*IT` classes NOT VERIFIED locally; slice tests (`@WebMvcTest`) and pure unit tests run without Docker.

## Overview

Cover the 15 required flows; update `docs/API_SPEC.md` auth section + `docs/backend-runbook.md` (JWT env, admin bootstrap); update task.json acEvidence/status; keep existing tests green.

## Required test flows → test mapping

| # | Flow | Test (class.method) | Type |
|---|---|---|---|
| 1 | register ok | `AuthControllerIT.register_created_returns201Profile` | IT (SpringBootTest+MockMvc, TC) |
| 2 | register duplicate email (case-insensitive) | `AuthControllerIT.register_duplicateEmail_409` | IT |
| 3 | register invalid input (bad email / short pw / role supplied) | `AuthControllerIT.register_invalid_400` + `register_roleSupplied_400` | IT/slice |
| 4 | login ok | `AuthControllerIT.login_valid_200Tokens` | IT |
| 5 | login bad credentials | `AuthControllerIT.login_wrongPassword_401` | IT |
| 6 | login locked/disabled → 401 | `AuthControllerIT.login_locked_401` (seed LOCKED user) | IT |
| 7 | valid JWT accesses /users/me | `AuthControllerIT` or `UserControllerIT.me_validJwt_200` | IT |
| 8 | invalid/expired JWT → 401 | `JwtAuthIT.expiredToken_401` + `tamperedToken_401` | IT (mint expired token via JwtEncoder directly w/ past exp) |
| 9 | refresh rotation works | `AuthRefreshIT.rotate_returnsNewPair_oldRevoked` | IT |
| 10 | revoked/replayed refresh rejected + family revoked | `AuthRefreshIT.replay_oldToken_401_familyRevoked` | IT |
| 11 | expired refresh rejected | `AuthRefreshIT.expiredRefresh_401` (insert row w/ past expiry) | IT |
| 12 | logout revokes; retry safe | `AuthRefreshIT.logout_204_thenRefresh401_retryStill204` | IT |
| 13 | learner blocked from admin endpoint (403) | `AdminPingIT.learner_403_admin_200` | IT |
| 14 | public events still open | existing `HistoricalEventControllerTest` green + `EventsPublicIT.events_200_unauthenticated` | slice + IT |
| 15 | migrations on clean+V1 DBs | existing `FlywayMigrationIT` (already covers; unchanged) | IT |

Non-IT complement (runnable without Docker):
- `AuthServiceTest` (pure Mockito unit): uniform-401 paths, role rejection, timing blunting call.
- `JwtTokenServiceTest`: mint token → decode → assert sub/role/exp claims (needs only encoder/decoder beans, no DB).
- `RefreshTokenServiceTest` (Mockito repo): rotation/replay logic branch coverage.
- Slice `@WebMvcTest(AuthController.class)` for validation 400s — but AuthController depends on AuthService mock; SecurityConfig now needs JwtDecoder — handle via `@MockitoBean JwtDecoder` (per phase-03 risk note).

New test files:
- `src/test/java/com/dauviet/auth/api/AuthControllerIT.java` — register/login/refresh/logout end-to-end on TC Postgres; seed users via `UserRepository`.
- `src/test/java/com/dauviet/auth/AuthRefreshIT.java` — rotation/replay/expiry/logout flows.
- `src/test/java/com/dauviet/user/api/UserControllerIT.java` — /users/me flows.
- `src/test/java/com/dauviet/admin/AdminPingIT.java` — 401 anon / 403 learner / 200 admin.
- `src/test/java/com/dauviet/security/jwt/JwtTokenServiceTest.java` — unit.
- `src/test/java/com/dauviet/auth/application/AuthServiceTest.java`, `RefreshTokenServiceTest.java` — Mockito units.
- `src/test/java/com/dauviet/EventsPublicIT.java` (or extend ActuatorHealthIT style) — events open without token under full security chain.
- Modify `HistoricalEventControllerTest` only if context breaks (add `@MockitoBean JwtDecoder`).

Helper: `src/test/java/com/dauviet/auth/TestUsers.java`? Keep simple — inline helpers in each IT (`registerUser(email, role, status)` via repos). If duplication grows >2 files, extract `AuthTestFixtures` under `src/test/java/com/dauviet/auth/`.

For minting test JWTs: autowire `JwtEncoder` in ITs → helper `bearerFor(user, role, ttlSeconds)` building claims like prod service (sub=id, role claim). For expired-token test: same helper with `expiresAt=now-60`.

Docs updates:
- `docs/API_SPEC.md` §2: fill in request/response shapes for `/auth/register|login|refresh|logout`, `/users/me`, error codes EMAIL_TAKEN/INVALID_CREDENTIALS table additions; note role-field rejection; note admin ping placeholder.
- `docs/backend-runbook.md`: JWT_SECRET env (min 32 bytes), TTL props, ADMIN_EMAIL/ADMIN_PASSWORD bootstrap, local profile flow, "generate secret: openssl rand -base64 48" example.
- `tasks/TASK-0007/task.json`: append acEvidence per AC, status per workflow gates, roleReports refs, nextAction update.
- `docs/PROGRESS.md` regenerated only if harness does it (do not hand-edit if generated).

## Implementation Steps

1. Unit tests first (no Docker): JwtTokenServiceTest, AuthServiceTest, RefreshTokenServiceTest — run via `mvnw -q test -Dtest='...'` (works locally).
2. Write IT classes (can't run locally — still write them; executor on Docker host runs `mvnw verify`).
3. Fix slice test if context fails (JwtDecoder @MockitoBean).
4. Run `mvnw -q test-compile` + unit-only tests locally; record results.
5. Update API_SPEC + runbook.
6. Update task.json acEvidence/status → `verifying` with NOT VERIFIED note for IT gate, per AGENT_WORKFLOW evidence rules.

## Todo

- [ ] 3 unit test classes (no Docker) — run green locally
- [ ] 5 IT classes written (marked NOT VERIFIED until Docker host)
- [ ] Slice-test JwtDecoder fix if needed
- [ ] API_SPEC.md auth section
- [ ] backend-runbook.md JWT/admin section
- [ ] task.json acEvidence + status update
- [ ] `mvnw -q test-compile` + local unit tests green
- [ ] `mvnw verify` → Docker host/CI (NOT VERIFIED locally)

## Success Criteria

- All 15 flows have a named test; unit-level ones pass locally; ITs pass on Docker host.
- No secrets committed; env names documented.
- AC→test mapping visible in task.json acEvidence.

## Security Considerations

- Tests must assert response bodies never contain passwordHash/token_hash fields.
- Test fixtures must not hardcode a real-looking secret beyond local dev value.

## Risk

- Can't execute ITs locally — primary risk is undetected wiring bugs; mitigate with unit coverage of service logic + slice tests + careful SecurityConfig review by code-reviewer.
