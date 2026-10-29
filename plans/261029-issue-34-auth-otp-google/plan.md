---
title: "[AUTH] Đăng nhập Google, Quên mật khẩu & OTP đăng ký/đặt lại mật khẩu (Issue #34)"
description: "Email OTP verification for registration, forgot/reset password via OTP with refresh-token revocation, and Google ID-token sign-in with account linking — backend (Spring Boot + Flyway) + Flutter mobile flows."
status: in-progress
priority: P0
effort: 2d
branch: feat/issue-34-auth-otp-google
tags: [backend, mobile, auth, otp, google-oauth, flyway, high-risk, issue-34]
created: 2026-10-29
---

# [AUTH] OTP đăng ký / quên mật khẩu + Google Sign-In (Issue #34)

## 1. Goal & Scope

Implement the 3 flows in [Issue #34](https://github.com/longv0208/Dau_Viet/issues/34) (labels `area:backend`, `area:mobile`, `high-risk`):

1. **Registration OTP** — register no longer activates immediately; it creates a `REGISTER_VERIFY` challenge and emails a 6-digit OTP. `email_verified_at` set + `TokenResponse` issued only after valid OTP. Resend with 60s cooldown; max 5 wrong attempts per code.
2. **Forgot/Reset password via OTP** — `POST /auth/password/forgot` always returns 200 (anti-enumeration); `POST /auth/password/reset` verifies OTP, sets new BCrypt hash, **revokes all refresh tokens** for that user.
3. **Google Sign-In** — `POST /auth/google` verifies Google `idToken` (signature via Google certs, `iss`, `aud ∈ configured client ids`, `exp`, `email_verified`); auto-creates `LEARNER` with `email_verified_at` or links to verified existing account via `user_oauth_accounts`; rejects `LOCKED`/`DISABLED`.

**Out of scope:** Admin web forgot-password UI (backend endpoints support it; admin module UI optional), Apple/Facebook sign-in, changing refresh-token rotation itself.

### Backward-compat decision (stated in issue)

`POST /api/v1/auth/register` semantics change: it now starts the OTP challenge instead of immediately creating an ACTIVE user. This is a **breaking contract change for the mobile register screen**, which we update in Phase 3 to route through OTP verification. Old behavior (register → immediate login) is replaced by register → request-otp → verify-otp → tokens.

## 2. Current State (researched)

- `AuthController` (`/api/v1/auth`): register/login/refresh/logout only. `AuthService.register` creates ACTIVE user immediately; `login` has timing-equalization dummy bcrypt + uniform `INVALID_CREDENTIALS`.
- `users` table (V2): `password_hash NOT NULL`, `email_verified_at` already exists, `status ∈ ACTIVE|LOCKED|DISABLED`. `auth_refresh_tokens` has `revoked_at`, `token_family_id`.
- `RefreshTokenService.rotate` already revokes family on replay / non-ACTIVE user via `RefreshTokenFamilyService`. Needs a new `revokeAllForUser(userId)` for password reset.
- `SecurityConfig`: `POST /api/v1/auth/**` already `permitAll` — new endpoints need no security change.
- `ErrorCode` enum: needs `OTP_INVALID`, `OTP_EXPIRED`, `OTP_MAX_ATTEMPTS_EXCEEDED`, `OTP_RESEND_COOLDOWN`, `GOOGLE_TOKEN_INVALID`, `ACCOUNT_DISABLED` (or reuse existing where fitting).
- Mobile: `AuthApiClient` has login/register/refresh/logout/me. `AuthRepository.register` does register+login; must be split into request-otp / verify-otp. `RegisterScreen` → new `OtpVerificationScreen`. No `google_sign_in` dep yet. Router has `/auth`, `/register` — add `/auth/otp`, `/auth/forgot`.
- Latest migration: `V50`. Next: `V53`. No `spring-boot-starter-mail`, no Google client lib in `pom.xml`. `spring-boot-starter-oauth2-resource-server` already present (JWT for own tokens only — Google token verified via google-api-client, not Nimbus decoder, because Google's id_token is a third-party token and we want explicit aud/iss checks).

## 3. Phase 1 — DB Migration `V53__auth_otp_and_google_oauth.sql`

```sql
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
-- accounts created via Google before setting a password keep NULL;
-- chk prevents accidental NULL+no-oauth combos at app layer (login path
-- rejects NULL hash → INVALID_CREDENTIALS, same as wrong password).

CREATE TABLE auth_otp_challenges (
    id            UUID PRIMARY KEY,
    email         VARCHAR(320) NOT NULL,           -- normalized lowercase
    purpose       VARCHAR(32)  NOT NULL,           -- REGISTER_VERIFY | PASSWORD_RESET
    code_hash     VARCHAR(128) NOT NULL,           -- SHA-256(email|purpose|code|salt) — never plaintext
    payload_json  JSONB,                           -- REGISTER_VERIFY: {displayName, passwordHash}; PASSWORD_RESET: {userId}
    attempts      INT NOT NULL DEFAULT 0,
    max_attempts  INT NOT NULL DEFAULT 5,
    expires_at    TIMESTAMPTZ NOT NULL,
    consumed_at   TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_otp_purpose CHECK (purpose IN ('REGISTER_VERIFY','PASSWORD_RESET')),
    CONSTRAINT chk_otp_attempts CHECK (attempts >= 0 AND attempts <= max_attempts)
);
CREATE INDEX idx_otp_email_purpose_created
    ON auth_otp_challenges (lower(email), purpose, created_at DESC);
-- Partial index: at most one active challenge per (email,purpose)
CREATE UNIQUE INDEX ux_otp_active
    ON auth_otp_challenges (lower(email), purpose) WHERE consumed_at IS NULL;

CREATE TABLE user_oauth_accounts (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider         VARCHAR(32) NOT NULL,
    provider_subject VARCHAR(255) NOT NULL,        -- Google `sub`
    provider_email   VARCHAR(320),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_oauth_provider CHECK (provider IN ('GOOGLE')),
    CONSTRAINT ux_oauth_provider_subject UNIQUE (provider, provider_subject)
);
CREATE INDEX idx_oauth_user ON user_oauth_accounts(user_id);
```

**Single-active-challenge design:** resend/forget invalidates the old code by `UPDATE … SET consumed_at = now()` then INSERT new row — enforced by `ux_otp_active`, so a race can't leave two live codes for the same (email,purpose). Verify looks up the single active row `FOR UPDATE`, checks attempts/expiry/code hash atomically.

## 4. Phase 2 — Backend

### New deps (`pom.xml`)
- `spring-boot-starter-mail` (SMTP; configured via `MAIL_HOST`/`MAIL_PORT`/`MAIL_USERNAME`/`MAIL_PASSWORD`).
- `com.google.api-client:google-api-client` + `com.google.http-client:google-http-client-jackson2` for `GoogleIdTokenVerifier` (fetches & caches Google JWKs, checks sig/iss/exp/aud).

### Config (`application.yml` + properties classes)
```
dauviet:
  auth:
    otp:
      ttl-seconds: 300        # 5 min
      resend-cooldown-seconds: 60
      max-attempts: 5
      mail-enabled: ${MAIL_ENABLED:false}   # false → LoggingOtpSender
    google:
      client-ids: ${GOOGLE_CLIENT_IDS:}     # comma-separated aud whitelist
```
`spring.mail.*` from `MAIL_*` env in `application-local.yml` example. `mail-enabled=false` → `LoggingOtpSender` logs "OTP sent to a***@b.com" (never logs the code — see AC-5).

### Components (all under `com.dauviet.auth`)

| File | Role |
|---|---|
| `domain/OtpPurpose.java` | enum `REGISTER_VERIFY`, `PASSWORD_RESET` |
| `domain/OtpChallenge.java` | JPA entity mapping `auth_otp_challenges` |
| `domain/UserOauthAccount.java` | JPA entity mapping `user_oauth_accounts` |
| `domain/OtpException.java` + subclasses | `OtpInvalidException`, `OtpExpiredException`, `OtpMaxAttemptsExceededException`, `OtpResendCooldownException` |
| `infrastructure/persistence/OtpChallengeRepository.java` | `findActiveForUpdate(email,purpose)`, `consumeActive(email,purpose)` |
| `infrastructure/persistence/UserOauthAccountRepository.java` | `findByProviderAndProviderSubject` |
| `application/OtpSender.java` + `SmtpOtpSender` + `LoggingOtpSender` | send 6-digit code via email; Logging fallback gated by `mail-enabled` (prod must set true — Logging sender never prints code, only that a send happened) |
| `application/OtpService.java` | `issue(email,purpose,payload)` (SecureRandom 6-digit, SHA-256 hash w/ per-challenge salt, consume old active), `verify(email,purpose,code)` (FOR UPDATE row → attempts++/expiry/hash → consume), `resendCooldownCheck` |
| `application/GoogleTokenVerifier.java` | wraps `GoogleIdTokenVerifier`; returns verified `GoogleIdToken.Payload` or throws `GoogleTokenInvalidException`; enforces `email_verified==true` |
| `application/AuthOtpService.java` (or extend `AuthService`) | register request-otp / verify-otp / forgot / reset / google orchestration; all `@Transactional` |

### Endpoints (all `permitAll` under existing `/api/v1/auth/**`)

| Method/Path | Request | Response | Notes |
|---|---|---|---|
| `POST /auth/register` | `{email,password,displayName?}` | `202 {email, otpPurpose:"REGISTER_VERIFY", otpTtlSeconds, resendCooldownSeconds}` | changed contract: no longer returns profile; if email already registered → `409 EMAIL_TAKEN`. If an active REGISTER_VERIFY challenge exists → resend per cooldown rules |
| `POST /auth/register/verify` | `{email,otpCode}` | `200 TokenResponse` | verify → create user (`email_verified_at=now()`, role LEARNER) → issue tokens. Errors: `400 OTP_INVALID`, `410 OTP_EXPIRED` (use 400 + code; see error table), `429 OTP_MAX_ATTEMPTS_EXCEEDED` |
| `POST /auth/otp/resend` | `{email,purpose}` | `202 {email,otpTtlSeconds,resendCooldownSeconds}` | `429 OTP_RESEND_COOLDOWN` if <60s since last issue. For REGISTER_VERIFY requires an existing challenge (can't resend for never-registered email → `404`/400 `OTP_NO_CHALLENGE`). For PASSWORD_RESET behaves like forgot (200 even if unknown) |
| `POST /auth/password/forgot` | `{email}` | `200 {}` always | if user exists & ACTIVE → issue PASSWORD_RESET + send mail. No info leak |
| `POST /auth/password/reset` | `{email,otpCode,newPassword}` | `204` | verify OTP → `password_hash=bcrypt(new)`, `revokeAllForUser(userId)` on `auth_refresh_tokens`, consume challenge |
| `POST /auth/google` | `{idToken}` | `200 TokenResponse` | verify → find `user_oauth_accounts(GOOGLE, sub)` → else find user by email: if exists & `email_verified_at != null` → link; if exists & unverified → `403 GOOGLE_EMAIL_UNVERIFIED` (don't auto-link unverified local account — takeover risk); if absent → create user + link. Non-ACTIVE user → `401` uniform |

**New error codes** → `ErrorCode`: `OTP_INVALID` (400), `OTP_EXPIRED` (400), `OTP_MAX_ATTEMPTS_EXCEEDED` (429), `OTP_RESEND_COOLDOWN` (429, `details.retryAfterSeconds`), `OTP_NO_CHALLENGE` (400), `GOOGLE_TOKEN_INVALID` (401), `GOOGLE_EMAIL_UNVERIFIED` (403). `INVALID_CREDENTIALS` unchanged for login/disabled.

**Security details:**
- OTP = 6 digits via `SecureRandom`; stored hash = `SHA-256(salt + code)` with per-challenge random salt in `payload_json` (cheap, brute-force still limited by `max_attempts` + lockout → BCrypt unnecessary for a 10⁶ space, hashing prevents DB-read leaks).
- `verify` increments `attempts` before comparing; on `attempts >= max_attempts` consume the row and throw `OTP_MAX_ATTEMPTS_EXCEEDED` → client must resend.
- Password reset revokes **all** user refresh tokens (`UPDATE auth_refresh_tokens SET revoked_at=now() WHERE user_id=? AND revoked_at IS NULL`).
- Never log OTP code, idToken, or password. LoggingOtpSender logs `to` (masked) + purpose only — for local dev the code is discoverable via DB is NOT possible (hashed); for dev convenience, `LoggingOtpSender` prints the code ONLY when `mail-enabled=false` AND profile `local` — this matches the issue's "LoggingOtpSender fallback cho môi trường local/test" (issue explicitly wants the dev fallback to be usable). Prod (`mail-enabled=true`) never logs codes. → AC-5 satisfied: no plaintext OTP in prod logs.
- `GoogleTokenVerifier` beans: built once with `client-ids` list; empty list → bean disabled, endpoint returns `503 FEATURE_DISABLED`.

**Entity change:** `User.passwordHash` → `@Column(nullable = true)` + login path: `passwordHash == null → INVALID_CREDENTIALS` after dummy-match timing equalization.

## 5. Phase 3 — Mobile (`dau-viet-mobile`)

### Deps
- `google_sign_in: ^6.2.1` (idToken via `GoogleSignInAuthentication.idToken`); requires `GOOGLE_CLIENT_ID` per platform — document in runbook; Android works without extra config for idToken when default web client set server-side.

### Data layer
- `AuthApiClient` += `requestRegisterOtp`, `verifyRegisterOtp`, `resendOtp`, `forgotPassword`, `resetPassword`, `loginWithGoogle`.
- `AuthRepository`: split `register()` → `requestRegisterOtp()` (returns `OtpChallengeInfo` for the UI) and `verifyRegisterOtp()` (returns `AuthState` storing tokens + profile via `/users/me`). `loginWithGoogle(idToken)` mirrors `login`. `resetPassword` returns void.
- `AuthSessionController`: expose `requestRegisterOtp`, `verifyRegisterOtp`, `resendOtp`, `forgotPassword`, `resetPassword`, `loginWithGoogle`.

### Screens & routes (`lib/features/auth/presentation/` + router)
- `OtpVerificationScreen` (new, `/auth/otp`): 6-box OTP input (single `TextField` w/ segmented style or 6 fields), 60s resend countdown (`Timer`), error mapping `OTP_INVALID`/`OTP_EXPIRED`/`OTP_MAX_ATTEMPTS_EXCEEDED`/`OTP_RESEND_COOLDOWN`, on success → `/dashboard`. Carries `{email, purpose:'REGISTER_VERIFY'}` via route `extra`; for `PASSWORD_RESET` navigates to reset-password step on success.
- `ForgotPasswordScreen` (new, `/auth/forgot`): step 1 email → forgot; step 2 OTP + new password + confirm → reset → back to `/auth` with success snackbar. (One screen, two steps — matches "Bước 1/Bước 2" in issue while keeping router small.)
- `RegisterScreen`: `_register` now calls `requestRegisterOtp` → `context.go('/auth/otp', extra: …)`; copy updated ("Nhập mã xác thực đã gửi về email").
- `AuthScreen`: add "Quên mật khẩu?" `TextButton` → `/auth/forgot`; add "Tiếp tục với Google" `DongSonButton`/`OutlinedButton` (heritage style: secondary outlined, Google 'G' mark via `google_sign_in` recommended branding text "Tiếp tục với Google").
- `GoogleSignIn` flow: `signIn()` → `authentication.idToken` → `loginWithGoogle`. Missing idToken (web needs clientId meta) → error message. Sign-out from Google on failure to allow account switching.
- Router `needsAuth` unchanged; new public routes added before redirect logic (routes are under `/auth/*` which is already the unauth destination — check `redirect` doesn't block `/auth/otp`, `/auth/forgot`: they're only visited while unauthenticated anyway).

### Widget tests (`test/auth/`)
- `otp_verification_screen_test.dart`: renders 6 boxes; wrong code → error text; resend disabled during countdown; success → repository `verifyRegisterOtp` called & navigates.
- `forgot_password_screen_test.dart`: email step → OTP+password step; mismatched confirm → validation error; success → back to auth.
- `auth_screen_test.dart`: "Quên mật khẩu?" navigates; Google button calls sign-in (mock `GoogleSignIn` via provider override).
- Update `auth_repository_test.dart` / `auth_screen_test.dart` register expectations for new two-step flow.

## 6. Phase 4 — Tests & Docs

### Backend tests (`dau-viet-backend/src/test/java/com/dauviet/auth/`)
- `OtpServiceTest` (unit, mocks repo/sender): issue creates challenge w/ hash ≠ code; verify wrong code → attempts+1 + `OTP_INVALID`; 5 wrong → `OTP_MAX_ATTEMPTS_EXCEEDED` + consumed; expired → `OTP_EXPIRED`; resend <60s → `OTP_RESEND_COOLDOWN`; resend invalidates prior code (old code → OTP_INVALID after reissue).
- `AuthOtpFlowIT` (Testcontainers Postgres, extends `AbstractPostgresIT`): register→verify→tokens + user ACTIVE+verified; verify twice → second fails; forgot unknown email → 200; forgot+reset → old refresh tokens revoked (login → refresh before reset → reset → old refresh → 401); reset with wrong OTP → 400.
- `GoogleAuthServiceTest` (unit; `GoogleIdTokenVerifier` mocked via seam — wrap verify in an interface `GoogleTokenVerifier`): valid token new email → creates LEARNER+link+tokens; valid token existing verified email → links; existing unverified → 403; `email_verified=false` → 401; aud mismatch → 401; LOCKED user → 401.
- `AuthControllerIT`: extend with endpoint-level status codes (404? no — forgot is 200; resend cooldown → 429).

### Mobile tests
- As §5; run `flutter test test/auth/` + full `flutter test` regression.

### Docs
- `docs/API_SPEC.md`: new endpoints, DTOs, error codes.
- `docs/DATABASE_DESIGN.md`: `auth_otp_challenges`, `user_oauth_accounts`, `users.password_hash` nullable.
- `docs/backend-runbook.md`: `MAIL_*`, `GOOGLE_CLIENT_IDS`, `DAUVIET_OTP_*` envs; local dev uses `LoggingOtpSender`.
- `docs/project-changelog.md`: entry.

## 7. AC → check mapping

| Issue AC | Check |
|---|---|
| AC-1 register OTP lifecycle | `AuthOtpFlowIT.register_verify_issues_tokens_and_sets_email_verified`, `OtpServiceTest` invalid/expired/max-attempts cases; mobile `otp_verification_screen_test` |
| AC-2 resend + cooldown + old codes invalid | `OtpServiceTest.resend_cooldown`, `resend_invalidates_previous`; `AuthOtpFlowIT` 429 case |
| AC-3 forgot/reset + revoke all refresh | `AuthOtpFlowIT.reset_revokes_all_refresh_tokens` (assert `auth_refresh_tokens.revoked_at` set for every user token; old refresh → 401) |
| AC-4 google verify/link/locked-reject | `GoogleAuthServiceTest` all cases + IT endpoint smoke w/ mocked verifier bean |
| AC-5 no plaintext OTP in DB/logs (prod), bcrypt, tests green | `OtpServiceTest` asserts stored `code_hash` ≠ code & hash differs across same-code challenges (salt); `mail-enabled=false` restricted to local profile documented; `mvnw test` + `flutter test` green |

## 8. Risks / open questions

- **Breaking register contract** — existing mobile `register()` updated same PR; any other consumer? (Admin doesn't register learners.) `AuthControllerIT` expectations updated.
- **`google_sign_in` platform config** — Android needs no extra native config for idToken if `serverClientId` = web client id passed at runtime; iOS needs `GIDClientID` in Info.plist — documented; test env uses mock so CI stays green.
- **Email delivery in dev** — no SMTP server locally; `LoggingOtpSender` prints code when `local` profile only (issue-sanctioned fallback).
- **Unverified-email Google linking** — conservative: refuse (403) rather than auto-link. Could revisit if PO wants auto-link on password-verified accounts.
- **V53 naming** — issue text says `V50__auth_otp_and_google_oauth.sql` but V50 is taken (`seed_lesson_cover_assets`) → use V53.
