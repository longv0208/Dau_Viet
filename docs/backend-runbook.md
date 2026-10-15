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

Endpoints (public): `POST /api/v1/auth/register|login|refresh|logout`.
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
  INSERT INTO users (id, email, password_hash, display_name, role, status)
  VALUES (gen_random_uuid(), 'admin@example.com',
          '<bcrypt-hash>', 'Admin', 'CONTENT_ADMIN', 'ACTIVE');
  ```

  Hash a password with any BCrypt tool (e.g. `htpasswd -bnBC 10 "" pw | tr -d ':\n'`).

Quick check: `curl -X POST localhost:8080/api/v1/auth/register -H "Content-Type: application/json" -d '{"email":"a@b.vn","password":"password123"}'` → 201.

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
