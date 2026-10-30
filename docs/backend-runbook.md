# Backend runbook — dau-viet-backend

## Prerequisites

- **JDK 21** — on this machine `E:\Java\jdk-21`. The system `JAVA_HOME` is broken
  (points to a deleted folder); set it per shell:
  - PowerShell: `$env:JAVA_HOME = 'E:\Java\jdk-21'`
  - Bash: `export JAVA_HOME='E:\Java\jdk-21'`
- **Docker Desktop** running (Postgres 16 container + Testcontainers tests)
- **Maven Wrapper** bundled — use `./mvnw` / `./mvnw.cmd` (no global Maven needed)

## Run Postgres (dev)

```powershell
cd dau-viet-backend
docker compose up -d
docker compose ps   # wait for (healthy)
```

Database `dauviet` on `localhost:5433`, user `dauviet`, password `dauviet_dev`
(dev-only defaults; override via `DB_URL` / `DB_USER` / `DB_PASSWORD` env vars).

## Run the app (local profile)

```powershell
$env:JAVA_HOME = 'E:\Java\jdk-21'
cd dau-viet-backend
./mvnw spring-boot:run "-Dspring-boot.run.profiles=local"
```

Under `local` the dev seed upserts the `bach-dang-938` event once
(idempotent, slug-keyed, fixed UUID `00000000-0000-0000-0000-000000000001`).

## Verify

- Health: `curl http://localhost:8080/actuator/health` → `{"status":"UP"}`
- List: `curl http://localhost:8080/api/v1/events` → paginated published events
- Detail: `curl http://localhost:8080/api/v1/events/00000000-0000-0000-0000-000000000001`
- Not found: `curl http://localhost:8080/api/v1/events/<uuid>` → 404 JSON envelope
- Unauthorized path: `curl http://localhost:8080/api/v1/anything` → 401

## Tests

```powershell
$env:JAVA_HOME = 'E:\Java\jdk-21'
./mvnw verify          # unit + WebMvc + Testcontainers IT
./mvnw test            # unit + WebMvc only (skip *IT)
```

`verify` requires Docker daemon running (Testcontainers). Without Docker the
integration tests fail — run `./mvnw test` for unit/MVC only and record the
integration result as NOT VERIFIED.

## Mobile (dau-viet-mobile)

Timeline `GET /api/v1/events` + Campaign Detail `GET /api/v1/events/{id}` nạp
từ API này khi app chạy mặc định (`USE_MOCK=false`).

```bash
cd ../dau-viet-mobile
flutter pub get
flutter run                                     # auto: 10.0.2.2:8080 trên Android, localhost:8080 còn lại
flutter run --dart-define=API_BASE_URL=http://<ip>:8080   # máy thật / backend xa
flutter run --dart-define=USE_MOCK=true                    # demo offline, không cần backend
```

Khi API lỗi app hiển thị lỗi + THỬ LẠI; không tự động đổi sang mock.

## Authentication (TASK-0007)

Endpoints (public): `POST /api/v1/auth/register|register/verify|otp/resend|password/forgot|password/reset|google|login|refresh|logout`.
Protected: `GET /api/v1/users/me` (any authenticated), `/api/v1/admin/**`
(requires `CONTENT_ADMIN`).

- **JWT secret** — env `JWT_SECRET`, HS256 needs >= 32 bytes. Local dev has a
  fallback in `application-local.yml`; production MUST set the env var or the
  app fails to start. Generate: `openssl rand -base64 48`.
- **TTLs** — `app.security.access-token-ttl-seconds` (default 900),
  `app.security.refresh-token-ttl-seconds` (default 1209600 = 14 days).
- **Admin bootstrap (dev)** — with profile `local` + `app.seed.enabled=true`,
  set `ADMIN_EMAIL` + `ADMIN_PASSWORD` (optional `ADMIN_DISPLAY_NAME`) env vars
  before launching: `AdminBootstrapRunner` creates the account insert-only
  (never overwrites or promotes an existing user).
- **Admin bootstrap (non-local)** — insert directly, e.g.:

  ```sql
  INSERT INTO users (id, email, password_hash, display_name, role, status, email_verified_at)
  VALUES (gen_random_uuid(), 'admin@example.com',
          '<bcrypt-hash>', 'Admin', 'CONTENT_ADMIN', 'ACTIVE', now());
  ```

  Hash a password with any BCrypt tool (e.g. `htpasswd -bnBC 10 "" pw | tr -d ':\n'`).

## OTP + Google sign-in (Issue #34 / TASK-0021)

Registration is now a 2-step OTP flow: `POST /auth/register` issues a
REGISTER_VERIFY challenge (202, no user yet) and emails a 6-digit code;
`POST /auth/register/verify` completes it. Password reset:
`POST /auth/password/forgot` (always 200) → `POST /auth/password/reset`
(verifies OTP, sets new hash, revokes ALL refresh tokens).
`POST /auth/otp/resend` re-issues with a 60s cooldown.

- **OTP tuning** — `dauviet.auth.otp.*`: `DAUVIET_OTP_TTL_SECONDS` (300),
  `DAUVIET_OTP_RESEND_COOLDOWN_SECONDS` (60), `DAUVIET_OTP_MAX_ATTEMPTS` (5).
- **Mail delivery** — `MAIL_ENABLED=false` (default) selects `LoggingOtpSender`,
  which prints the OTP **only under the `local` profile** — that's the dev
  workflow for completing OTP screens without an SMTP server. Production MUST
  set `MAIL_ENABLED=true` plus `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`,
  `MAIL_PASSWORD` (and optionally `MAIL_SMTP_AUTH`, `MAIL_SMTP_STARTTLS`,
  `MAIL_SENDER`); with mail enabled the code is never logged anywhere.
- **Google sign-in** — set `GOOGLE_CLIENT_IDS` to a comma-separated whitelist
  of OAuth client ids (Android/iOS/Web — the Web client id must be included
  for Flutter Web sign-in). `/auth/google` accepts either `idToken`
  (Android/iOS — signature/`iss`/`exp`/`aud`/`email_verified` verified via
  Google's certs) **or** `accessToken` (Flutter Web — verified against
  Google's `oauth2/v3/tokeninfo`; aud must match the whitelist and
  `email_verified` must be true). Empty whitelist → `503 FEATURE_DISABLED`.
  Mobile passes the web client id via `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
  at run time; Flutter Web uses `--dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>`
  or the `google-signin-client_id` meta tag in `web/index.html`
  (google_sign_in_web rejects `serverClientId`).

Quick check:
`curl -X POST localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"email":"a@b.vn","password":"password123"}'`
→ `202` + (local profile) the OTP code appears in the app log; then
`curl -X POST localhost:8080/api/v1/auth/register/verify -H "Content-Type: application/json" -d '{"email":"a@b.vn","otpCode":"<code>"}'` → `200` tokens.

## Common issues

- **`JAVA_HOME` broken** — the env var points to `C:\Program Files\Java\jdk-21`
  which no longer exists; always override with `E:\Java\jdk-21`.
- **Port 5433 busy** — another local Postgres is on 5432; this module uses
  5433→5432 to avoid collision. Change `ports:` in `docker-compose.yml` if
  needed and update `DB_URL`.
- **Schema changed** — wipe the volume: `docker compose down -v` then `up -d`;
  Flyway re-applies migrations.
- **Secrets** — never commit `.env` or real credentials; dev defaults are in
  `application-local.yml` for clarity only.
