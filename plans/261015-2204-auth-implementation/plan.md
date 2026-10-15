# TASK-0007 Phase B+C — Authentication & Authorization backend

## Context

- Task: `tasks/TASK-0007/task.json` (high-risk; auth/DB/version adjacent)
- Phase A done at `d1763c1`: V2/V3/V4 migrations imported; FlywayMigrationIT extended.
- Base: Spring Boot 3.4.13, Java 21, modular monolith `com.dauviet.*`.
- Env: Windows 11, `JAVA_HOME=E:\Java\jdk-21`; Docker Desktop DOWN — Testcontainers ITs run only on Docker host/CI → mark NOT VERIFIED locally.

## Goals

Auth endpoints (register/login/refresh/logout), JWT access tokens, refresh rotation + family revocation, roles LEARNER/CONTENT_ADMIN, `GET /api/v1/users/me`, admin gating, admin bootstrap, public events stay open.

## Key decisions

1. JWT stack: `spring-boot-starter-oauth2-resource-server` (Nimbus). Decoder validates incoming Bearer tokens; tokens minted via `JwtEncoder` with HMAC secret (HS256). Rationale: one Spring-managed dep, built-in Bearer auth + `Jwt` principal, no custom filter. Minting needs symmetric `JwtEncoder`/`JwtDecoder` beans from `ImmutableSecret`.
2. Principal = user UUID. JWT `sub` = user id string; role claim `role` mapped to `ROLE_<role>` authority via `JwtAuthenticationConverter` in SecurityConfig.
3. Refresh replay response: 401 `INVALID_CREDENTIALS`-class code — add `INVALID_CREDENTIALS` and `EMAIL_TAKEN` to `ErrorCode`. Reuse of revoked token → revoke whole family, return 401.
4. LOCKED/DISABLED login → 401 `INVALID_CREDENTIALS` (no status leak, per AC-4).
5. Register: client-supplied `role` field is ignored if absent; if present → 400 `VALIDATION_ERROR` (explicit reject, cleaner than silent ignore; document choice). Email normalized `trim().toLowerCase(Locale.ROOT)` in service before persist; rely on `ux_users_email_lower` + catch `DataIntegrityViolationException` → 409 `EMAIL_TAKEN` (new code; 409 per API_SPEC conflict semantics).
6. Admin bootstrap: `AdminBootstrapRunner` (ApplicationRunner, `@Profile("local")`, `@ConditionalOnProperty app.seed.enabled=true`) reading `ADMIN_EMAIL`/`ADMIN_PASSWORD` env — mirrors EventSeedRunner; fails fast if env missing. Documented SQL alternative in runbook.
7. SecurityConfig: permitAll `/api/v1/auth/**` POSTs + existing public matchers; `hasRole("CONTENT_ADMIN")` on `/api/v1/admin/**`; `oauth2ResourceServer(jwt)` replaces `anyRequest().authenticated()`-only chain.

## Phases

| Phase | File | Status |
|---|---|---|
| 01 User module | `phase-01-user-module.md` | done |
| 02 Auth domain + register/login | `phase-02-auth-register-login.md` | done |
| 03 JWT security wiring | `phase-03-jwt-security.md` | done |
| 04 Refresh rotation + logout + admin bootstrap | `phase-04-refresh-logout-bootstrap.md` | done |
| 05 Tests (15 flows) + docs | `phase-05-tests-docs.md` | done — unit+slice green locally; ITs NOT VERIFIED (Docker down) |

Order: 01 → 02/03 (02 needs User repo; 03 needs pom + properties) → 04 → 05. One writer; sequential.

## Non-goals

- Email verification, password reset, rate limiting (note as follow-up).
- Admin CMS endpoints beyond `GET /api/v1/admin/ping` placeholder.
- Changing `dau-viet-db/` or V2–V4 migration contents.

## Verification

- `mvnw -q test-compile` after each phase (JAVA_HOME=E:\Java\jdk-21).
- `mvnw verify` full IT suite → Docker host/CI only; report NOT VERIFIED locally.
- Existing `HistoricalEventControllerTest`, `ActuatorHealthIT` must stay green (slice tests need updated SecurityConfig import — see phase-03).
