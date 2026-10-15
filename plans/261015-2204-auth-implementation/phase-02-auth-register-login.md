# Phase 02 — Auth domain + register/login

## Context Links

- Phase-01 (User, UserRepository). Phase-03 supplies `JwtTokenService` interface used here — write this phase against the interface signature `String createAccessToken(User user)` defined in phase-03; compile order: pom (03 step-1) → 01 → 03 partial (encoder/decoder + token service) → 02 → 03 SecurityConfig. Executor may reorder within a single commit set; keep it simple: phases sequential as listed in plan.md.
- V2 `auth_refresh_tokens` schema. AC-3, AC-4.

## Overview

`com.dauviet.auth` module: RefreshToken entity + repository, request/response DTOs, `AuthService` (register, login), `RefreshTokenService` (issue raw token, persist hash), `AuthController` exposing POST `/api/v1/auth/register` and `/api/v1/auth/login`. Rotation/logout land in phase-04.

## Requirements

- Register request: {email, password, displayName?, role?}. Bean validation: `@Email @NotBlank email`, `@Size(min=8,max=72) @NotBlank password`, `@Size(max=120) displayName`, `role` — if non-null → throw `IllegalArgumentException`/`MethodArgumentNotValidException` path → 400 `VALIDATION_ERROR`. Simplest: validate in service `if (req.role() != null) throw new InvalidRoleRequestedException()` mapped via `IllegalArgumentException` handler (already exists → VALIDATION_ERROR).
- Email normalize `trim().toLowerCase(Locale.ROOT)` in `AuthService.register`.
- Password hash: `PasswordEncoder` bean = `BCryptPasswordEncoder` (declared in phase-03 SecurityConfig or a new `auth/AuthSecurityBeans` — decide: put `@Bean PasswordEncoder` inside `SecurityConfig` to keep one security file).
- Unique email: pre-check `findByEmailIgnoreCase` (fast path, nicer error) AND catch `DataIntegrityViolationException` on save → throw `EmailTakenException` → 409 `EMAIL_TAKEN`.
- New `ErrorCode` enum values: `EMAIL_TAKEN`, `INVALID_CREDENTIALS`. New exceptions in `common/error` or `auth/domain`: `EmailTakenException`, `InvalidCredentialsException`. Add `@ExceptionHandler` entries in `GlobalExceptionHandler`: EmailTakenException → 409 EMAIL_TAKEN; InvalidCredentialsException → 401 INVALID_CREDENTIALS.
- Login: find by normalized email; if absent → `passwordEncoder.matches(dummyHash...)` to blunt timing then throw InvalidCredentialsException (uniform). If present but status != ACTIVE → same 401. If matches → issue access token + create refresh token row (family = new UUID, previousTokenId=null) → return `TokenResponse {accessToken, tokenType:"Bearer", expiresIn, refreshToken, refreshExpiresIn}`.
- Refresh token storage: raw token = `UUID + 32-byte SecureRandom` base64url (or plain 256-bit random hex); store `sha256Hex(raw)` in `token_hash`. Never log raw.
- last_login_at update on successful login.
- Refresh TTL/access TTL read from `app.security.*` properties (defined phase-03; AuthService takes `AuthProperties`).

## Related Code Files

Create:
- `auth/domain/RefreshToken.java` — entity for `auth_refresh_tokens` (id, user_id, token_hash, token_family_id, previous_token_id, expires_at, revoked_at, created_at, last_used_at).
- `auth/infrastructure/persistence/RefreshTokenRepository.java` — findByTokenHash, findByTokenFamilyId, save.
- `auth/api/dto/RegisterRequest.java`, `LoginRequest.java`, `RefreshRequest.java` (created now, used phase-04), `TokenResponse.java`.
- `auth/application/AuthService.java` — register(), login().
- `auth/application/RefreshTokenService.java` — `issue(User, previousToken)` returns {rawToken, entity}; `hash(raw)`; `revokeFamily(familyId)` used in 04 (may stub-create now or defer — defer to 04 to keep file focused).
- `auth/api/AuthController.java` — `/api/v1/auth` POST register + login only this phase.
- `auth/domain/EmailTakenException.java`, `auth/domain/InvalidCredentialsException.java` (or under common/error — pick `auth/domain` to keep feature-local).
- `auth/config/AuthProperties.java` — `@ConfigurationProperties("app.security")` {accessTokenTtlSeconds, refreshTokenTtlSeconds, jwtSecret} bound in phase-03.

Modify:
- `common/error/ErrorCode.java` — add `EMAIL_TAKEN`, `INVALID_CREDENTIALS`.
- `common/error/GlobalExceptionHandler.java` — two new handlers.
- `common/config/SecurityConfig.java` — add `PasswordEncoder` bean + `permitAll` POST `/api/v1/auth/**` (full wiring lands phase-03; adding matchers now is fine and keeps register/login testable).

## Implementation Steps

1. Add `EMAIL_TAKEN`, `INVALID_CREDENTIALS` to `ErrorCode`.
2. Add handlers in `GlobalExceptionHandler` for `EmailTakenException` (409) and `InvalidCredentialsException` (401).
3. `RefreshToken` entity + `RefreshTokenRepository` (columns per V2).
4. DTOs: `RegisterRequest(email,password,displayName,role)`, `LoginRequest(email,password)`, `TokenResponse(accessToken,tokenType,expiresIn,refreshToken,refreshExpiresIn)`.
5. `AuthProperties` config props class (fields above + defaults documented; no secret default in prod — dev fallback documented).
6. `RefreshTokenService.issue`: generate raw (32B SecureRandom, Base64url no-padding), sha-256 hex via `MessageDigest`, build entity (family=new UUID when previous==null), set expiry = now+refreshTtl, save, return raw.
7. `AuthService.register`: reject role!=null → 400; normalize email; `new User` id=UUID.randomUUID, role=LEARNER, status=ACTIVE, passwordHash=encoder.encode; try/catch DataIntegrityViolationException → EmailTakenException; return `UserProfileDto` via UserMapper (reuse from phase-01 — cross-module use of mapper bean is fine, keeps DRY).
8. `AuthService.login`: normalize email; findByEmailIgnoreCase; timing-blunt dummy compare when absent (`passwordEncoder.matches(raw, DUMMY_BCRYPT)` constant); verify matches; check status==ACTIVE else 401; set lastLoginAt; `jwtTokenService.createAccessToken(user)`; `refreshTokenService.issue(user,null)`; build TokenResponse with configured TTLs.
9. `AuthController`: `@PostMapping("/register")` → 201 + UserProfileDto; `@PostMapping("/login")` → 200 + TokenResponse. `@Valid` on bodies.
10. SecurityConfig: add `.requestMatchers(HttpMethod.POST, "/api/v1/auth/**").permitAll()` before anyRequest; add `@Bean PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(); }`.
11. `mvnw -q test-compile`.

## Todo

- [ ] ErrorCode + handler entries
- [ ] RefreshToken entity + repository
- [ ] DTOs + AuthProperties
- [ ] RefreshTokenService.issue/hash
- [ ] AuthService register/login with uniform 401 + timing blunting
- [ ] AuthController register + login
- [ ] SecurityConfig PasswordEncoder bean + auth permitAll matcher
- [ ] test-compile green

## Success Criteria

- Register 201 returns profile DTO (no hash); duplicate email → 409 EMAIL_TAKEN; role supplied → 400.
- Login 200 returns both tokens + expiresIn; wrong password/nonexistent/locked/disabled → identical 401 INVALID_CREDENTIALS envelope.
- DB row stores hash, never raw token.

## Security Considerations

- No account-existence leak: same code+status+body shape for all login failures; dummy BCrypt compare when user missing.
- Refresh raw token only returned once in response; DB holds sha256.
- role field ignored-or-rejected decision: REJECTED (400) — document in API_SPEC.

## Risk

- Depends on `JwtTokenService` (phase-03) — interface must exist before this compiles; keep interface minimal and create it in phase-03 step order, or create interface file in this phase (preferred: create `security/jwt/JwtTokenService.java` in phase-02 as interface, impl lands phase-03 — still one file each, no overlap).
- Constraint-violation message must not echo email value back in details beyond the submitted field — details map `{"email":"already registered"}` fine.
