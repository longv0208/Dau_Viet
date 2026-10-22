# Phase 02 — Backend learner map API (+ admin CRUD endpoints)

## Context links

- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/api/HistoricalEventController.java` — learner controller conventions
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/LearnerAttemptController.java` — `@AuthenticationPrincipal Jwt` + `JwtSubjectExtractor`
- `dau-viet-backend/src/main/java/com/dauviet/learning/infrastructure/persistence/LearnerAttemptRepository.java` — JPQL join pattern across `lesson_versions`
- `dau-viet-backend/src/main/java/com/dauviet/common/config/SecurityConfig.java` — `anyRequest().authenticated()` covers `/api/v1/map/**`; no change required
- `dau-viet-backend/src/main/java/com/dauviet/historicalevent/admin/api/AdminEventController.java` — admin conventions
- `docs/API_SPEC.md` — error envelope `{code,message,details,traceId}`

## Overview

- Priority: P0
- Learner endpoints: `GET /api/v1/map/locations`, `GET /api/v1/map/locations/{id}` — authenticated (both LEARNER and CONTENT_ADMIN can read; consistent with lessons surface).
- Admin endpoints under `/api/v1/admin/events/{eventId}/map-locations` — CRUD for the admin UI (phase 03).

## Unlock semantics (decision — locked)

```
unlockState =
  UNLOCKED  if unlock_lesson_id IS NOT NULL
            AND exists (SELECT 1 FROM learner_attempts a
                        JOIN lesson_versions v ON a.lesson_version_id = v.id
                        WHERE a.user_id = :userId
                          AND a.status = 'COMPLETED'
                          AND v.lesson_id = loc.unlock_lesson_id)
  AVAILABLE if unlock_lesson_id IS NULL
  LOCKED    otherwise
```

- Attempt pinned to ANY version of that lesson counts (republish-safe).
- Multiple attempts — one COMPLETED is enough.
- Completion is read-only here; map never mutates attempts.

## Endpoints

### Learner

| Method | Path | Notes |
|---|---|---|
| GET | `/api/v1/map/locations` | All `active=true` locations whose parent event is `PUBLISHED`. No paging needed for MVP (bounded by admin-configured count); return plain array — NOT PageResponse (list is small; keep KISS). |
| GET | `/api/v1/map/locations/{id}` | Detail. Locked → preview projection only. |

### Admin

| Method | Path | Notes |
|---|---|---|
| POST | `/api/v1/admin/events/{eventId}/map-locations` | Create. |
| GET | `/api/v1/admin/events/{eventId}/map-locations` | List all (incl. inactive) ordered. |
| GET | `/api/v1/admin/map-locations/{id}` | Detail. |
| PATCH | `/api/v1/admin/map-locations/{id}` | Update; accepts `expectedRowVersion`. |
| DELETE | `/api/v1/admin/map-locations/{id}` | Hard delete OK — no published snapshots reference map locations (unlike evidence). Keep simple; document decision. |

## DTOs (records, `com.dauviet.map.api.dto`)

`MapLocationSummaryResponse` (list element):

```java
public record MapLocationSummaryResponse(
    UUID id, UUID eventId, String eventTitle, String eventSlug,
    String title, String description,
    double latitude, double longitude,
    String unlockState,            // AVAILABLE | LOCKED | UNLOCKED
    RequiredLessonDto requiredLesson  // null unless LOCKED
) {}
```

`RequiredLessonDto` (preview only — no content):

```java
public record RequiredLessonDto(UUID lessonId, String title) {}
```

`MapLocationDetailResponse` — same fields + `String eventDescription`? Keep to `{...summary fields, Instant updatedAt}` minimal; detail adds nothing extra beyond summary in MVP — decision: detail endpoint returns the SAME record shape (plus `requiredLesson`), kept for future-proof path symmetry with `/events/{id}`. Cheaper: detail returns summary shape; document.

LOCKED rule: summary + detail return `title`, `description` (preview), coords, `unlockState=LOCKED`, `requiredLesson{lessonId,title}`. No event-internal data beyond what list already exposes — description IS the preview (brief says "preview + required lesson info only" — preview = title/description/coords themselves).

Admin DTOs:

```java
public record AdminMapLocationResponse(UUID id, UUID eventId, String title,
    String description, double latitude, double longitude,
    UUID unlockLessonId, int displayOrder, boolean active,
    long rowVersion, Instant createdAt, Instant updatedAt) {}

public record MapLocationUpsertRequest(
    @NotBlank @Size(max=255) String title,
    @Size(max=4000) String description,
    @NotNull @Min(-90) @Max(90) Double latitude,
    @NotNull @Min(-180) @Max(180) Double longitude,
    UUID unlockLessonId,
    @Min(0) Integer displayOrder,
    Boolean active) {}

public record MapLocationPatchRequest( // all optional
    @Size(max=255) String title, @Size(max=4000) String description,
    @Min(-90) @Max(90) Double latitude, @Min(-180) @Max(180) Double longitude,
    UUID unlockLessonId, @Min(0) Integer displayOrder, Boolean active,
    Long expectedRowVersion) {}
```

## N+1 avoidance — query approach

Single JPQL/native query for learner list — NOT per-location unlock checks:

```java
// MapLocationRepository
@Query(value = """
    SELECT l.*, (CASE WHEN l.unlock_lesson_id IS NULL THEN 'AVAILABLE'
                      WHEN EXISTS (
                        SELECT 1 FROM learner_attempts a
                        JOIN lesson_versions v ON a.lesson_version_id = v.id
                        WHERE a.user_id = :userId
                          AND a.status = 'COMPLETED'
                          AND v.lesson_id = l.unlock_lesson_id
                      ) THEN 'UNLOCKED' ELSE 'LOCKED' END) AS unlock_state
    FROM map_locations l
    JOIN historical_events e ON l.event_id = e.id
    WHERE l.active = true AND e.status = 'PUBLISHED'
    ORDER BY l.display_order ASC, l.created_at ASC
    """, nativeQuery = true)
List<MapWithUnlockProjection> findLearnerVisibleWithUnlockState(@Param("userId") UUID userId);
```

Or projection via interface `MapLocationWithState` / Tuple. One round-trip.

`requiredLesson` titles: one `IN` query on `lessons` for the distinct
`unlock_lesson_id`s returned, then a `Map<UUID,String>` merge in service —
2 queries total, no N+1.

Detail: reuse the same native query filtered by `l.id = :id` (single row).

## Files

Create:
- `map/api/LearnerMapController.java` (`@RequestMapping("/api/v1/map")`)
- `map/api/AdminMapLocationController.java` (`/api/v1/admin/events/{eventId}/map-locations` + `/api/v1/admin/map-locations/{id}` — split into two controllers optional; single controller with both mappings OK)
- `map/application/MapLocationService.java` — learner reads
- `map/application/AdminMapLocationService.java` — admin writes; validates `unlockLesson.eventId == eventId` (load `Lesson` via `LessonRepository`, check `lesson.getEventId().equals(eventId)` else throw `UnlockLessonMismatchException`); validates parent event exists (404 `EVENT_NOT_FOUND` via `ResourceNotFoundException` — note GlobalExceptionHandler maps it to `EVENT_NOT_FOUND` code; reuse).
- `map/api/dto/*` records above
- `map/api/mapper/MapLocationMapper.java` (static or Spring mapper — follow `HistoricalEventMapper` style)

Modify:
- `common/error/GlobalExceptionHandler.java` — if `ResourceNotFoundException` is reused for map-not-found it yields `EVENT_NOT_FOUND` code; preferred: dedicated `MapLocationNotFoundException` → 404 `MAP_LOCATION_NOT_FOUND` (phase 01 already lists it).
- `common/error/ErrorCode.java` — add enum values `MAP_LOCATION_NOT_FOUND`, `UNLOCK_LESSON_MISMATCH`.
- `AbstractPostgresIT` (test support) — add `delete from map_locations` to `clearAuthoringTables` (phase 05).

## Security

- `GET /api/v1/map/**` → `anyRequest().authenticated()` (already covered; add a comment in SecurityConfig documenting intent).
- `/api/v1/admin/**` → `hasRole("CONTENT_ADMIN")` (already covered).
- userId derived ONLY from `Jwt` subject via `JwtSubjectExtractor` — never request param.
- Locked locations must not leak `event.description` extras — response DTO has no field for it (design-level guarantee, not a runtime strip).

## Implementation steps

1. Repository projection + native query.
2. `MapLocationService.listForLearner(userId)`, `.getForLearner(userId,id)`.
3. `LearnerMapController` — thin.
4. `AdminMapLocationService` + controller + request DTOs.
5. Exceptions + ErrorCode + handler wiring.
6. Compile + spot-test query in `MapLocationRepositoryIT` later (phase 05).

## Todo

- [ ] Repository native query + projection interface
- [ ] Learner service + controller + DTOs
- [ ] Admin service + controller + DTOs
- [ ] ErrorCode + handler entries
- [ ] SecurityConfig comment

## Success criteria

- `GET /api/v1/map/locations` as learner returns 200 with computed `unlockState`.
- Anonymous → 401; LEARNER role → 200.
- Admin PATCH with stale `expectedRowVersion` → 409 `OPTIMISTIC_LOCK_CONFLICT` (handled by existing `@Version` + handler).
- `unlock_lesson_id` pointing at a lesson of another event → 422 `UNLOCK_LESSON_MISMATCH`.
- Location on non-PUBLISHED event invisible to learner list/detail (404 detail).

## Risks

- Native query + JPQL mixing: keep it in repository only, projection typed.
- Event status flip PUBLISHED→ARCHIVED hides locations instantly (desired).
- Large location count — no paging; acceptable for MVP (flagged in docs).

## Security considerations

- No answer keys/validation content anywhere in responses.
- `details` map in errors must not include internal entity data.
