# Phase 03 â€” Backend API + Hook into `doComplete()`

## Context Links
- `dau-viet-backend/src/main/java/com/dauviet/learning/application/LearnerAttemptService.java:445-506` â€” `doComplete()` body.
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/dto/CompleteAttemptResponse.java` â€” additive-field precedent (`newlyUnlockedDossiers`).
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/EnergyController.java` â€” controller template.
- `dau-viet-backend/src/main/java/com/dauviet/energy/api/dto/EnergyStateResponse.java` â€” `serverTime` field precedent.
- `docs/API_SPEC.md` â€” endpoint conventions, error envelope.

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 3h

Wire `StreakService.recordCompletion()` into `LearnerAttemptService.doComplete()` inside the existing tx, add additive `streakIncreased`/`newStreak`/`previousStreak`/`completedToday`/`studyDate` fields to `CompleteAttemptResponse`, and create `StreakController` exposing `GET /api/v1/me/streak` + `GET /api/v1/me/streak/calendar`.

## Key Insights
- **Hook position**: AFTER `itemUnlocks.evaluateAfterLessonCompletion(...)` and INSIDE `if (completedVersion != null)` block â€” same tx, AFTER `attempts.save(a)`+`lessonResults.save(...)`. The attempt is already marked COMPLETED, so streak is only recorded for true completions.
- **Additive response fields**: extend `CompleteAttemptResponse` record with 5 new fields (default `false`/`0`/`null` for replay path, populated only on fresh completion) â€” exactly mirrors `newlyUnlockedDossiers` pattern. `CompleteResultDto.fromJson` on mobile safely handles missing fields.
- **No separate endpoint for "increment"** â€” completion IS the trigger.
- **`GET /me/streak`** is the read path; `streakAlive` is the differentiator between "alive but not completed today" vs "completed today" vs "streak lost".

## Requirements
- `GET /api/v1/me/streak` â†’ `StreakStateResponse {currentStreak, longestStreak, completedToday, lastQualifiedDate, today, timezone, serverTime, streakAlive}`.
- `GET /api/v1/me/streak/calendar?from=YYYY-MM-DD&to=YYYY-MM-DD` â†’ `List<LocalDate>` (or wrapped `{dates: [...]}`).
- Auth: `@AuthenticationPrincipal Jwt` â†’ `JwtSubjectExtractor.userId`. Self-scope only.
- Errors: standard `{code,message,details,traceId}` envelope; `400` on bad date format / `from>to`; `401` unauth.
- `POST /attempts/{id}/complete` returns additive streak fields â€” backward compatible (older clients ignore).

## Architecture

```
POST /attempts/{id}/complete
  â””â”€ LearnerAttemptService.complete(idem-key)
       â””â”€ @Transactional
            â”œâ”€ findForUpdate(attempt)
            â”œâ”€ idempotency.execute(key â†’ doComplete)
            â”‚    â”œâ”€ markCompleted + save
            â”‚    â”œâ”€ lessonResults.save
            â”‚    â”œâ”€ rewardGrants.grantFirstCompletion        (existing)
            â”‚    â”œâ”€ eventMilestones.recordIfEarned           (existing)
            â”‚    â”œâ”€ itemUnlocks.evaluateAfterLessonCompletion (existing)
            â”‚    â””â”€ streakService.recordCompletion            (NEW â€” same tx)
            â”‚         â†’ StreakUpdateResult
            â””â”€ CompleteAttemptResponse (with streak fields)

GET /api/v1/me/streak            â†’ StreakController.state()  â†’ StreakService.stateOf()
GET /api/v1/me/streak/calendar   â†’ StreakController.calendar() â†’ StreakService.calendarOf()
```

## Related Code Files

**Create**:
- `dau-viet-backend/src/main/java/com/dauviet/streak/api/StreakController.java`
- `dau-viet-backend/src/main/java/com/dauviet/streak/api/dto/StreakStateResponse.java`
- `dau-viet-backend/src/main/java/com/dauviet/streak/api/dto/StreakCalendarResponse.java`

**Modify**:
- `dau-viet-backend/src/main/java/com/dauviet/learning/api/dto/CompleteAttemptResponse.java` â€” add 5 fields, new factory.
- `dau-viet-backend/src/main/java/com/dauviet/learning/application/LearnerAttemptService.java` â€” inject `StreakService`, call in `doComplete()`, populate response.

**Delete**: none.

## Implementation Steps

### Step 1 â€” Extend `CompleteAttemptResponse`

```java
public record CompleteAttemptResponse(
        UUID attemptId, String status, boolean alreadyCompleted,
        Instant completedAt, LessonCompletion completion,
        AttemptProgressResponse.Progress progress,
        List<UUID> newlyUnlockedDossiers,
        // LEARNING-STREAK additive (default false/0/null on replay)
        boolean streakIncreased,
        int newStreak,
        int previousStreak,
        Boolean completedToday,
        LocalDate studyDate) {

    /** Replay path / old-shape â€” no new streak data. */
    public static CompleteAttemptResponse of(UUID attemptId, String status,
            boolean alreadyCompleted, Instant completedAt,
            LessonCompletion completion,
            AttemptProgressResponse.Progress progress) {
        return new CompleteAttemptResponse(attemptId, status, alreadyCompleted,
                completedAt, completion, progress, List.of(),
                false, 0, 0, null, null);
    }

    /** Fresh-completion factory including unlock + streak payload. */
    public static CompleteAttemptResponse of(UUID attemptId, String status,
            Instant completedAt, LessonCompletion completion,
            AttemptProgressResponse.Progress progress,
            List<UUID> newlyUnlockedDossiers,
            StreakUpdateResult streak) {
        return new CompleteAttemptResponse(attemptId, status, false,
                completedAt, completion, progress, newlyUnlockedDossiers,
                streak.streakIncreased(), streak.newStreak(),
                streak.previousStreak(), streak.completedToday(),
                streak.studyDate());
    }
}
```

### Step 2 â€” Hook into `doComplete()`

In `LearnerAttemptService.java`, add field + ctor param:
```java
private final StreakService streakService;
// ... inject via constructor
```

Inside `doComplete()`, after `itemUnlocks.evaluateAfterLessonCompletion(userId, lessonId, a.getId());` and still inside the `if (completedVersion != null)` block:

```java
            itemUnlocks.evaluateAfterLessonCompletion(userId, lessonId,
                    a.getId());
            // LEARNING-STREAK: ghi 1 ngĂ y há»c trong CĂ™NG transaction â€”
            // rollback cá»§a báº¥t ká»³ pháº§n nĂ o tráº£ cáº£ vá» tráº¡ng thĂ¡i chÆ°a hoĂ n
            // thĂ nh. Idempotent: ON CONFLICT DO NOTHING trĂªn (user_id, study_date).
            streakResult = streakService.recordCompletion(
                    userId, lessonId, a.getId(), a.getCompletedAt());
```

Declare `StreakUpdateResult streakResult = StreakUpdateResult.disabled();` BEFORE the `if (completedVersion != null)` block, then pass into the new `CompleteAttemptResponse.of(...)` factory at the bottom:

```java
        return CompleteAttemptResponse.of(a.getId(), a.getStatus().name(),
                a.getCompletedAt(), verdict, progress,
                List.copyOf(newlyUnlockedDossiers), streakResult);
```

The `alreadyCompleted` replay path keeps using the existing `CompleteAttemptResponse.of(...)` overload â€” returns `streakIncreased=false`/`newStreak=0`/etc.

### Step 3 â€” `StreakStateResponse` DTO

```java
package com.dauviet.streak.api.dto;

public record StreakStateResponse(
        int currentStreak,
        int longestStreak,
        boolean completedToday,
        LocalDate lastQualifiedDate,
        LocalDate today,
        String timezone,
        Instant serverTime,
        boolean streakAlive) {}
```

### Step 4 â€” `StreakCalendarResponse` DTO

```java
public record StreakCalendarResponse(List<LocalDate> dates) {}
```
(List of ISO dates; wrapper keeps door open for future metadata.)

### Step 5 â€” `StreakController`

```java
@RestController
@RequestMapping("/api/v1/me/streak")
public class StreakController {
    private final StreakService service;
    private final JwtSubjectExtractor subjects;

    public StreakController(StreakService service,
                            JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    @GetMapping
    public StreakStateResponse state(@AuthenticationPrincipal Jwt jwt) {
        return service.stateOf(subjects.userId(jwt));
    }

    @GetMapping("/calendar")
    public StreakCalendarResponse calendar(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to")   @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        if (to.isBefore(from)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "to must be >= from");
        }
        if (from.plusYears(1).isBefore(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "range must be <= 1 year");
        }
        return new StreakCalendarResponse(
                service.calendarOf(subjects.userId(jwt), from, to));
    }
}
```

### Step 6 â€” Verify controller discovery
- `com.dauviet.streak` is under the `com.dauviet` base scan â€” automatic.
- Confirm `JwtSubjectExtractor` is on classpath (used by `EnergyController`).

## Todo List
- [ ] Add 5 fields to `CompleteAttemptResponse`; add new `of` factory overload.
- [ ] Inject `StreakService` in `LearnerAttemptService` ctor.
- [ ] Declare `streakResult` var + call `recordCompletion` inside `doComplete`.
- [ ] Pass `streakResult` to new `CompleteAttemptResponse.of` factory.
- [ ] Write `StreakStateResponse` + `StreakCalendarResponse` records.
- [ ] Write `StreakController` with both endpoints + range validation.
- [ ] `./mvnw compile` green.
- [ ] Smoke test: `curl -H "Authorization: Bearer $JWT" localhost:8080/api/v1/me/streak` â†’ 200 with zeros.
- [ ] Smoke test: complete an attempt â†’ response contains `streakIncreased:true, newStreak:1, previousStreak:0`.

## Success Criteria
- POST /attempts/{id}/complete response JSON includes `streakIncreased`, `newStreak`, `previousStreak`, `completedToday`, `studyDate`.
- Replay (same idempotency key) returns `streakIncreased:false` â€” never double-fires.
- GET endpoints work; unauthenticated â†’ 401.
- Existing tests in `LearnerAttemptService*` ITs still pass (additive fields don't break old assertions).

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Breaking change to `CompleteAttemptResponse` (record positional args) | Record constructor is positional â€” adding fields changes signature. All callers go through `of` factories; the only direct-construction site is `of` itself. Search `new CompleteAttemptResponse` before merging. |
| Lazy-create inside `@Transactional(readOnly=true)` `stateOf` fails | `stateOf` is NOT `readOnly` â€” it writes if first call creates the row. Keep `@Transactional` (write-capable). |
| `streakIncreased` semantics on `alreadyCompleted` replay | Replay returns `false`, `0`, `0`, `null`, `null` â€” client treats as "no new info"; doesn't re-animate. |
| Calendar `from`/`to` huge range â†’ memory/perf | Cap at 1 year via `plusYears(1)` check. |
| Clock skew between `completedAt` (stored) and `clock.now()` in service | Both server-derived; `completedAt` is `Instant.now()` set in `markCompleted` â€” same JVM, sub-ms delta. Safe. |

## Security Considerations
- JWT-only identity. `subjects.userId(jwt)` â€” never trusts `userId` param.
- `/me/*` scope â€” no user-vs-user reads.
- Rate limiting: standard (existing global filter). Streak endpoint is cheap (single row).
- No PII in response â€” only counts + dates.

## Next Steps
- Phase 04 writes IT + unit tests covering all streak paths including boundary cases.
