# Phase 02 — Admin Events endpoints

## Context links

- `tasks/TASK-0008/task.json` AC-1, AC-4
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/api/HistoricalEventController.java` (public; reuse sort whitelist pattern)
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/application/HistoricalEventService.java` (read-only public — DO NOT extend with admin writes; create separate `AdminEventService` for clean module boundary)
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/domain/HistoricalEvent.java` + `EventStatus.java`
- `dau-viet-backend/src/main/java/com/dauviet/admin/api/AdminPingController.java` (existing admin URL convention)

## Overview

- Priority: P1
- Status: pending
- Implements `/api/v1/admin/events` CRUD + lifecycle actions: create, list (paginated + search + status filter), detail, update metadata, publish, archive. No DELETE.

## Key insights

- Public `GET /api/v1/events` MUST stay unchanged. Admin endpoints live at `/api/v1/admin/events` and are gated by existing `hasRole("CONTENT_ADMIN")`.
- Status state machine for `HistoricalEvent`: `DRAFT → PUBLISHED → ARCHIVED` and `DRAFT → ARCHIVED`. Forbid `PUBLISHED → DRAFT`, `ARCHIVED → *`.
- Publish action: `POST /{id}/publish`. Archive: `POST /{id}/archive`. Both are dedicated POSTs (not PATCH) — matches API_SPEC idiom and gives clear audit trail.
- Slug rule: client supplies slug at create; service validates format `[a-z0-9-]+` and uniqueness via `ux_historical_events_slug`. Update cannot change slug once `status = PUBLISHED` (slug is referenced externally).
- Event-in-use protection: archiving a `PUBLISHED` event must check `lessonRepository.existsByEventIdAndStatusNot(id, ARCHIVED)` — if any non-archived lesson exists → 409 `EVENT_IN_USE`. **Decision:** do NOT auto-archive lessons (explicit > implicit).
- Optimistic locking: `@Version` auto-applied. Concurrent updates throw `ObjectOptimisticLockingFailureException` → mapped to 409 `OPTIMISTIC_LOCK_CONFLICT`.

## Requirements

- `POST /api/v1/admin/events` — body `{slug, title, era?, period?, startYear?, summary, description?, location?, coverAssetKey?, tags?[]}` → 201 `AdminEventDetailDto`. Initial status always `DRAFT` (client cannot set).
- `GET /api/v1/admin/events?page=&size=&sort=&status=&q=` — paginated list of `AdminEventSummaryDto`. `status` filter accepts `DRAFT|PUBLISHED|ARCHIVED` (invalid → 400). `q` filters on title OR slug (case-insensitive LIKE).
- `GET /api/v1/admin/events/{id}` — returns full `AdminEventDetailDto` regardless of status.
- `PATCH /api/v1/admin/events/{id}` — partial update of `{title?, era?, period?, startYear?, summary?, description?, location?, coverAssetKey?, tags?, slug?}`. Slug change allowed only when `status=DRAFT`. Returns updated detail.
- `POST /api/v1/admin/events/{id}/publish` — transition `DRAFT → PUBLISHED`. Reject `PUBLISHED` (no-op or 409? — decide 409 to surface admin error). Reject `ARCHIVED`. After publish, public list must include event.
- `POST /api/v1/admin/events/{id}/archive` — transition `DRAFT|PUBLISHED → ARCHIVED`. If `PUBLISHED` and `lessons.event_id` has any non-`ARCHIVED` rows → 409 `EVENT_IN_USE`. After archive, public GET returns 404.

## Architecture

```
com.dauviet.historicalevent.admin/
├── AdminEventController.java       (@RestController, /api/v1/admin/events)
├── AdminEventService.java          (@Service, @Transactional write methods)
├── dto/
│   ├── AdminEventCreateRequest.java
│   ├── AdminEventUpdateRequest.java
│   ├── AdminEventSummaryDto.java
│   └── AdminEventDetailDto.java
└── mapper/
    └── AdminEventMapper.java
```

`AdminEventService` injects `HistoricalEventRepository` (for spec search + writes) and `LessonRepository` (for `EVENT_IN_USE` check on archive).

## Related code files

### Create

- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/AdminEventController.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/AdminEventService.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/dto/AdminEventCreateRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/dto/AdminEventUpdateRequest.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/dto/AdminEventSummaryDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/dto/AdminEventDetailDto.java`
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/mapper/AdminEventMapper.java`

### Modify

- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/infrastructure/persistence/HistoricalEventRepository.java` — add `JpaSpecificationExecutor<HistoricalEvent>`; existing derived methods stay.

### Delete

- None.

## Implementation steps

1. DTOs (records):
   - `AdminEventCreateRequest(slug @NotBlank @Pattern("[a-z0-9-]+"), title @NotBlank, era, period, startYear @Min(0)?, summary @NotBlank, description, location, coverAssetKey, tags List<String>)`.
   - `AdminEventUpdateRequest` — all fields `@Nullable` (partial update); if `slug` present validate same pattern.
   - `AdminEventSummaryDto(id, slug, title, era, period, startYear, summary, coverAssetKey, tags, status, updatedAt)`.
   - `AdminEventDetailDto` — same as summary + `description`, `location`, `createdAt`.
2. `AdminEventService`:
   - `create(req)` — check slug uniqueness; build entity with `status=DRAFT`, `id=UUID.randomUUID()`; save; return detail.
   - `list(page, size, sort, status, q)` — build `Specification<HistoricalEvent>` combining `status eq` (when present) and `(title ilike :q or slug ilike :q)` (when present); `repository.findAll(spec, pageable)`.
   - `getById(id)` — `findById` or `ResourceNotFoundException("Historical event not found")`.
   - `update(id, req)` — `findById` → 404; if `req.slug` present and differs and `status != DRAFT` → `InvalidStatusTransitionException` (or new `SlugImmutableException` — decide `INVALID_STATUS_TRANSITION` is fine, message explains); apply non-null fields; save → `ObjectOptimisticLockingFailureException` bubbles up → handler maps 409.
   - `publish(id)` — transition guard `DRAFT` only; set status `PUBLISHED`; save.
   - `archive(id)` — if current `PUBLISHED` and `lessonRepository.existsByEventIdAndStatusNot(id, ARCHIVED)` → `EventInUseException`; set `ARCHIVED`; save.
   - All write methods `@Transactional`. Read `@Transactional(readOnly=true)`.
3. `AdminEventController` — `@RestController @RequestMapping("/api/v1/admin/events") @Validated`. Methods mirror the spec. Sort whitelist `{"title","startYear","updatedAt","createdAt"}`.
4. Wire everything; run `mvnw -q test-compile`.

## Todo

- [ ] `AdminEventCreateRequest`/`UpdateRequest`/`SummaryDto`/`DetailDto` records.
- [ ] `AdminEventMapper` (entity → admin DTOs).
- [ ] `AdminEventService` — create/list/get/update/publish/archive.
- [ ] `AdminEventController` — six endpoints.
- [ ] Specification-based filtering (`status` + `q`) wired in service.
- [ ] `mvnw -q test-compile` clean.

## Success criteria

- All six endpoints respond correctly under `CONTENT_ADMIN`.
- `LEARNER` → 403, anonymous → 401 (covered by existing SecurityConfig + new ITs).
- `PATCH` with stale `@Version` → 409 `OPTIMISTIC_LOCK_CONFLICT` (deferred to phase-05 IT).
- Slug change on `PUBLISHED` event → 409.
- Archiving `PUBLISHED` event with live lessons → 409 `EVENT_IN_USE`.

## Risk assessment

- **Risk:** Specification API + `tags` array column — Hibernate may generate SQL for `tags` join that breaks spec. Mitigation: do NOT include `tags` in `q` search (title + slug only).
- **Risk:** `EVENT_IN_USE` check requires `LessonRepository` — cyclic dep between `historicalevent.admin` and `lesson` packages? Acceptable — both are application services in the same module.

## Security considerations

- All endpoints under `/api/v1/admin/**` → `hasRole("CONTENT_ADMIN")` already enforced.
- No PII or secrets in event metadata.
- Slug validation prevents path injection.

## Next steps

- Phase 03 implements lessons (parallel-safe only if file ownership is disjoint; it is — different packages).
