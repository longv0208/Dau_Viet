# Phase 01 — User module (entity, enums, repository, /users/me)

## Context Links

- `docs/TECH_STACK.md` module layout; `docs/CODING_RULES.md` §3 Spring rules.
- V2 schema: `dau-viet-backend/src/main/resources/db/migration/V2__users_and_auth.sql`.
- Pattern refs: `historicalevent/domain/HistoricalEvent.java`, `Historic alEventRepository`, `HistoricalEventController`.
- Task AC-7, AC-8 (partial).

## Overview

Create `com.dauviet.user` module: `User` JPA entity mapped to `users` table, `UserRole`/`UserStatus` enums, `UserRepository`, `GET /api/v1/users/me` returning safe profile DTO.

## Requirements

- Entity mirrors V2 columns exactly (ddl-auto=validate will fail otherwise): id, email, password_hash, display_name, role, status, email_verified_at, last_login_at, created_at, updated_at, row_version.
- `row_version` → `@Version Long rowVersion` (optimistic lock column exists in schema).
- Enums `LEARNER|CONTENT_ADMIN`, `ACTIVE|LOCKED|DISABLED` — do NOT rename.
- `UserProfileDto` = record {id, email, displayName, role, status, emailVerifiedAt, createdAt} — never passwordHash.
- `GET /api/v1/users/me`: authenticated; resolve user id from `Jwt.getSubject()` → UUID; user missing/soft-deleted → 404 `NOT_FOUND` (add handler mapping if ResourceNotFoundException stays EVENT_NOT_FOUND — see step 5).
- Endpoint stays protected under current deny-by-default config; no SecurityConfig change needed this phase.

## Related Code Files

Create:
- `user/domain/User.java` — entity, plain getters/setters, UUID set manually, `@CreationTimestamp`/`@UpdateTimestamp`.
- `user/domain/UserRole.java`, `user/domain/UserStatus.java`.
- `user/infrastructure/persistence/UserRepository.java` — `JpaRepository<User,UUID>` + `Optional<User> findByEmailIgnoreCase(String email)` (query on `lower(email)` won't hit the functional index via derived query; prefer `@Query("select u from User u where lower(u.email) = lower(:email)")`).
- `user/api/UserController.java` — `/api/v1/users` base; `GET /me` takes `@AuthenticationPrincipal Jwt jwt` (import available once phase-03 dep added — if compile ordering matters, land controller in phase-03 instead; decide: keep here, phase-03 adds the dep before `mvnw test-compile`).
- `user/api/dto/UserProfileDto.java` — record.
- `user/api/mapper/UserMapper.java` — toProfileDto (component, mirrors HistoricalEventMapper).
- `user/application/UserService.java` — `getProfile(UUID id)` read-only tx.

Modify: none this phase.

## Implementation Steps

1. Write `UserRole`, `UserStatus` enums (UPPER_SNAKE constants).
2. Write `User` entity: `@Entity @Table(name="users")`, `@Enumerated(STRING)` on role/status, `@Version` on rowVersion, all `@Column` snake_case names matching V2.
3. Write `UserRepository` with the lower(email) query above.
4. Write `UserProfileDto` record + `UserMapper.toProfileDto`.
5. Write `UserService.getProfile`: findById → orElseThrow `ResourceNotFoundException("User not found")`. NOTE: existing handler maps ResourceNotFoundException → `EVENT_NOT_FOUND`; acceptable short-term but file follow-up: introduce generic `NOT_FOUND` code for non-event 404s (add `UserNotFoundException extends ResourceNotFoundException` is NOT needed — simplest: keep ResourceNotFoundException, accept EVENT_NOT_FOUND code for now, document in report; alternative: add `NotFoundException` with own handler — pick simplest = reuse, flag to reviewer).
6. Write `UserController`: `@RestController @RequestMapping("/api/v1/users")`; `GET /me` → `jwt.getSubject()` → `UUID.fromString` → service → dto. Malformed subject → 401 (defensive; should not happen).
7. `mvnw -q test-compile` (JAVA_HOME set). Jwt import unresolved until phase-03 pom — expected; either do phase-03 pom edit first or comment nothing; coordinate: executor runs phase-03 step-1 (pom) first if needed.

## Todo

- [ ] UserRole/UserStatus enums
- [ ] User entity matches V2 columns
- [ ] UserRepository + lower(email) finder
- [ ] UserProfileDto + mapper
- [ ] UserService.getProfile
- [ ] UserController GET /me
- [ ] test-compile green

## Success Criteria

- Entity loads under ddl-auto=validate (proved by FlywayMigrationIT/context boot on Docker host).
- `/users/me` returns profile fields; hash absent from DTO type entirely.
- File sizes <200 lines.

## Security Considerations

- DTO is a record without passwordHash — compile-time guarantee no leak.
- Subject→UUID parse inside try/catch → 401, never 500.

## Risk

- `@Version` + manual UUID: harmless; check column name `row_version` maps.
- Jwt principal type not yet on classpath → sequence pom change before controller compile.
