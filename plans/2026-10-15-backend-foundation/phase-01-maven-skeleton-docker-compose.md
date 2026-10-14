# Phase 01 — Maven skeleton + Docker Compose Postgres

## Context links
- Plan: [plan.md](plan.md)
- Stack: `docs/TECH_STACK.md` (Java 21, Spring Boot 3.x, Maven, Postgres, Flyway)
- Harness config: `.harness/config.json` (`backend.path = dau-viet-backend`, manifests `[pom.xml]`)

## Overview
- **Priority:** P1 — blocking all later phases
- **Status:** completed
- **Effort:** 2h
- Scaffold `dau-viet-backend/` as a single-module Maven project and bring up a local Postgres 16 container for dev/test.

## Key insights
- `dau-viet-backend/` does not exist today; no Java code anywhere in repo.
- JAVA_HOME env is broken on this machine — implementation MUST prefix `JAVA_HOME=E:\Java\jdk-21` (or set per-command) before running `mvn`/`mvnw`.
- Docker Desktop is installed but daemon is not running; phase-01 includes a pre-check step that starts Docker and verifies `docker info` succeeds.
- Maven Wrapper (`mvnw`, `mvnw.cmd`, `.mvn/wrapper/`) is required so CI and other devs can build without a local Maven install.

## Requirements
- `pom.xml` at `dau-viet-backend/pom.xml`, parent `org.springframework.boot:spring-boot-starter-parent:3.4.5`, groupId `com.dauviet`, artifactId `dau-viet-backend`, Java 21.
- Dependencies (pinned to Spring Boot BOM where possible):
  - `spring-boot-starter-web`
  - `spring-boot-starter-data-jpa`
  - `spring-boot-starter-validation`
  - `spring-boot-starter-security`
  - `spring-boot-starter-actuator`
  - `org.flywaydb:flyway-core` + `org.flywaydb:flyway-database-postgresql`
  - `org.postgresql:postgresql` (runtime)
  - Test: `spring-boot-starter-test`, `spring-boot-testcontainers`, `org.testcontainers:postgresql`, `org.testcontainers:junit-jupiter`, `spring-security-test`
- Maven Wrapper generated via `mvn -N wrapper:wrapper -Dmaven=3.9.11` (or copy `.mvn/wrapper/maven-wrapper.properties` + scripts).
- `docker-compose.yml` at repo root (or `dau-viet-backend/docker-compose.yml`) with a `postgres` service:
  - image `postgres:16-alpine`
  - container `dauviet-postgres`
  - env `POSTGRES_DB=dauviet`, `POSTGRES_USER=dauviet`, `POSTGRES_PASSWORD=dauviet_dev` (dev-only, documented as non-secret)
  - port `5433:5432`
  - volume `dauviet-pgdata:/var/lib/postgresql/data`
  - healthcheck `pg_isready -U dauviet -d dauviet`
- `application.yml` (default): server.port=8080, `spring.application.name=dau-viet-backend`, `spring.jpa.hibernate.ddl-auto=validate`, `spring.flyway.enabled=true`, `management.endpoints.web.exposure.include=health,info`.
- `application-local.yml`: datasource url `jdbc:postgresql://localhost:5433/dauviet`, user/password via env-overridable `${DB_USER:dauviet}` / `${DB_PASSWORD:dauviet_dev}`, `app.seed.enabled=true`.
- `application-test.yml`: no datasource url (Testcontainers supplies JDBC URL); `app.seed.enabled=false`.
- `DauVietApplication.java` in `com.dauviet` with `@SpringBootApplication`.
- `.gitignore` additions for `target/`, `.idea/`, `*.iml`, `.mvn/wrapper/maven-wrapper.jar` (use the non-jar wrapper distro).

## Architecture

```
dau-viet-backend/
├── pom.xml
├── mvnw, mvnw.cmd, .mvn/wrapper/maven-wrapper.properties
├── docker-compose.yml          # or repo root
├── src/main/java/com/dauviet/DauVietApplication.java
└── src/main/resources/
    ├── application.yml
    ├── application-local.yml
    └── application-test.yml    # under src/test/resources instead
```

## Related code files
- Create: `dau-viet-backend/pom.xml`
- Create: `dau-viet-backend/mvnw`, `mvnw.cmd`, `.mvn/wrapper/maven-wrapper.properties`
- Create: `dau-viet-backend/docker-compose.yml` (compose file kept inside module so `cwd` is unambiguous)
- Create: `dau-viet-backend/src/main/java/com/dauviet/DauVietApplication.java`
- Create: `dau-viet-backend/src/main/resources/application.yml`, `application-local.yml`
- Create: `dau-viet-backend/src/test/resources/application-test.yml`
- Modify: root `.gitignore` (append Java/Maven entries)

## Implementation steps
1. Verify Docker daemon: `docker info` — if not running, `Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"` then poll until ready; document NOT VERIFIED if cannot start.
2. Create `dau-viet-backend/` tree and `pom.xml` with the dependencies above.
3. Generate Maven Wrapper: `cd dau-viet-backend; $env:JAVA_HOME='E:\Java\jdk-21'; C:\apache-maven-3.9.11-bin\apache-maven-3.9.11\bin\mvn.cmd -N wrapper:wrapper -Dmaven=3.9.11`.
4. Write `application.yml`, `application-local.yml`, `application-test.yml`.
5. Write `DauVietApplication.java` (bare `@SpringBootApplication` main).
6. Write `docker-compose.yml`; run `docker compose -f dau-viet-backend/docker-compose.yml up -d postgres`; `docker compose ps` shows `healthy`.
7. Smoke: `$env:JAVA_HOME='E:\Java\jdk-21'; ./mvnw -q -DskipTests package` produces `target/dau-viet-backend-0.0.1-SNAPSHOT.jar`.
8. Run `java -jar target/...jar --spring.profiles.active=local` once, confirm `Started DauVietApplication`, `/actuator/health` returns `UP`. Stop process.

## Todo checklist
- [ ] Docker daemon running, `docker compose up -d postgres` healthy on 5433
- [ ] `pom.xml` compiles with Java 21 + Boot 3.4.5
- [ ] Maven Wrapper committed (`mvnw`, `mvnw.cmd`, `.mvn/wrapper/maven-wrapper.properties`)
- [ ] `application{,-local}.yml` load datasource from env-with-default
- [ ] `application-test.yml` disables Flyway datasource URL (Testcontainers will inject)
- [ ] `.gitignore` covers `target/`, IDE files, `maven-wrapper.jar`
- [ ] `mvnw -DskipTests package` produces runnable jar
- [ ] `actuator/health` reachable on `:8080` under `local` profile

## Success criteria
- `./mvnw clean package` exits 0 on this machine
- `docker compose up -d postgres` reaches healthy state
- App boots under `local` profile and `/actuator/health` returns `{"status":"UP"}` (empty DB — Flyway not yet run, `ddl-auto=validate` would fail on missing tables; either set `ddl-auto=none` for phase-01 smoke or defer smoke to phase-03 — record which was done)

## Risk assessment
- **Docker unavailable** → mark Testcontainers + integration runs as NOT VERIFIED; unit + compile steps still verify.
- **JAVA_HOME wrong** → all `mvn`/`mvnw` invocations in subsequent phases MUST prefix `$env:JAVA_HOME='E:\Java\jdk-21'`.
- **`ddl-auto=validate` + no tables** → first boot fails; acceptable, but document the order: real boot smoke happens after Flyway V1 in phase-03.

## Security considerations
- Dev credentials are dev-only defaults; production deployment injects via env (`DB_USER`/`DB_PASSWORD`).
- Do not commit any production credentials; only `application-local.yml` defaults are committed.

## Next steps
- Phase 02 — common infra beans (error handler, security chain, CORS).
