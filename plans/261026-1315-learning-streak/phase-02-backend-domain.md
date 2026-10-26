# Phase 02 â€” Backend Domain (`com.dauviet.streak`)

## Context Links
- `dau-viet-backend/src/main/java/com/dauviet/energy/application/EnergyService.java` â€” closest analog: `recoverLocked`, `insertIgnore` lazy-create, `Clock` injected, `@Transactional(REQUIRED)`.
- `dau-viet-backend/src/main/java/com/dauviet/energy/domain/UserEnergy.java` â€” entity template (`@Id userId`, `@Version rowVersion`).
- `dau-viet-backend/src/main/java/com/dauviet/energy/infrastructure/persistence/UserEnergyRepository.java` â€” `findForUpdate` + `insertIgnore` patterns.
- `dau-viet-backend/src/main/java/com/dauviet/learning/application/LearnerAttemptService.java:445-506` â€” `doComplete()` hook point (phase-03 wires the call).

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 4h

Create the `com.dauviet.streak` bounded context: 2 JPA entities + 2 repositories + 1 application service (`StreakService`) + 1 `StreakProperties` config bean. Pure domain logic, no controller yet â€” that's phase-03.

## Key Insights
- Mirror `EnergyService` shape exactly: same lock pattern, same `Clock` injection for IT determinism, same `insertIgnore` lazy-create, same `@Transactional(REQUIRED)` so callers can compose into outer tx.
- `study_date` computed **once** in Java via `Instant.now(clock).atZone(VN_ZONE).toLocalDate()` â€” keeps SQL trivial and test-friendly (inject fixed `Clock`).
- Idempotency lives in `streak_days` repo's `insertIgnore` returning `int` (0 = already written, 1 = new day). Caller branches on that to decide whether to update parent streak counter.
- `recordCompletion` returns a small result record `(streakIncreased, newStreak, previousStreak, completedToday, studyDate)` â€” phase-03 uses it to build the additive `CompleteAttemptResponse` fields and the `GET /me/streak` payload.

## Requirements
- **Functional**:
  - `recordCompletion(userId, lessonId, attemptId, completedAt)` â€” same-day call is no-op; consecutive day increments; gap resets to 1.
  - `stateOf(userId)` â€” returns `{currentStreak, longestStreak, completedToday, lastQualifiedDate, today, timezone, serverTime, streakAlive}`.
  - `calendarOf(userId, fromDate, toDate)` â€” list of `study_date`s (asc) in range.
  - Lazy-create parent row on first write AND on first read (return zero-state, not 404).
- **Non-functional**: O(1) `stateOf` (single row read); O(range) `calendarOf`.
- **Idempotent**: N calls with same `(user, study_date)` â†’ exactly 1 day row, current_streak moved only once.
- **Concurrency**: 2 threads same user same day â†’ both succeed; `current_streak` incremented exactly once.
- **No** EXP/points/wallet side-effects (POINT-03).

## Architecture

```
StreakService (@Service)
  â”œâ”€â”€ UserLearningStreakRepository (JpaRepository<UserLearningStreak, UUID>)
  â”‚     â”œâ”€â”€ findForUpdate(userId)         @Lock(PESSIMISTIC_WRITE)
  â”‚     â”œâ”€â”€ findById(userId)               (for read paths)
  â”‚     â””â”€â”€ insertIgnore(userId, now)      @Modifying native
  â”œâ”€â”€ UserLearningStreakDayRepository (JpaRepository<UserLearningStreakDay, StreakDayId>)
  â”‚     â”œâ”€â”€ insertIgnore(userId, studyDate, lessonId, attemptId, completedAt)
  â”‚     â”œâ”€â”€ findByUserIdAndStudyDateBetweenOrderByStudyDateAsc(userId, from, to)
  â”‚     â””â”€â”€ existsByUserIdAndStudyDate(userId, date)
  â”œâ”€â”€ StreakProperties (@ConfigurationProperties "dauviet.streak")
  â”‚     â””â”€â”€ enabled (default true), timezone (default "Asia/Ho_Chi_Minh")
  â””â”€â”€ Clock (existing bean)
```

## Related Code Files

**Create** (package `com.dauviet.streak`):
- `domain/UserLearningStreak.java`
- `domain/UserLearningStreakDay.java`
- `domain/StreakDayId.java` â€” composite PK `(userId, studyDate)` `Serializable` w/ `equals`/`hashCode`.
- `domain/StreakUpdateResult.java` â€” record `(boolean streakIncreased, int newStreak, int previousStreak, boolean completedToday, LocalDate studyDate)`.
- `application/StreakService.java`
- `application/StreakProperties.java`
- `infrastructure/persistence/UserLearningStreakRepository.java`
- `infrastructure/persistence/UserLearningStreakDayRepository.java`

**Modify**: none in this phase (phase-03 wires the call site).

## Implementation Steps

### Step 1 â€” `StreakDayId.java`

```java
package com.dauviet.streak.domain;

import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class StreakDayId implements Serializable {
    private UUID userId;
    private LocalDate studyDate;
    public StreakDayId() {}
    public StreakDayId(UUID userId, LocalDate studyDate) {
        this.userId = userId; this.studyDate = studyDate;
    }
    // getters
    public UUID getUserId() { return userId; }
    public LocalDate getStudyDate() { return studyDate; }
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof StreakDayId that)) return false;
        return Objects.equals(userId, that.userId)
            && Objects.equals(studyDate, that.studyDate);
    }
    @Override public int hashCode() { return Objects.hash(userId, studyDate); }
}
```

### Step 2 â€” `UserLearningStreak.java` (entity)

```java
@Entity @Table(name = "user_learning_streaks")
public class UserLearningStreak {
    @Id @Column(name="user_id", updatable=false) private UUID userId;
    @Column(name="current_streak", nullable=false) private int currentStreak;
    @Column(name="longest_streak", nullable=false) private int longestStreak;
    @Column(name="last_qualified_date") private LocalDate lastQualifiedDate;
    @Column(name="created_at", nullable=false) private Instant createdAt;
    @Column(name="updated_at", nullable=false) private Instant updatedAt;
    @Version @Column(name="row_version", nullable=false) private Long rowVersion;

    public static UserLearningStreak start(UUID userId, Instant now) { /* zeros */ }

    /** Apply a NEW qualifying day under caller's lock. */
    public void applyQualifiedDay(LocalDate studyDate, Instant now) {
        int prev = this.currentStreak;
        if (lastQualifiedDate == null) {
            this.currentStreak = 1;
        } else if (studyDate.equals(lastQualifiedDate.plusDays(1))) {
            this.currentStreak = prev + 1;
        } else if (studyDate.isAfter(lastQualifiedDate.plusDays(1))) {
            this.currentStreak = 1;
        } else {
            // studyDate <= lastQualifiedDate â€” should be impossible due to
            // UNIQUE backstop; defensive no-op.
            return;
        }
        this.longestStreak = Math.max(this.longestStreak, this.currentStreak);
        this.lastQualifiedDate = studyDate;
        this.updatedAt = now;
    }
    // getters
}
```

### Step 3 â€” `UserLearningStreakDay.java` (entity)

```java
@Entity @Table(name = "user_learning_streak_days")
@IdClass(StreakDayId.class)
public class UserLearningStreakDay {
    @Id @Column(name="user_id") private UUID userId;
    @Id @Column(name="study_date") private LocalDate studyDate;
    @Column(name="lesson_id") private UUID lessonId;
    @Column(name="learner_attempt_id") private UUID learnerAttemptId;
    @Column(name="completed_at", nullable=false) private Instant completedAt;
    @Column(name="created_at", nullable=false) private Instant createdAt;
    // getters only â€” append-only
}
```

### Step 4 â€” Repositories

```java
public interface UserLearningStreakRepository
        extends JpaRepository<UserLearningStreak, UUID> {

    @Modifying @Query(value = """
        INSERT INTO user_learning_streaks
            (user_id, current_streak, longest_streak, last_qualified_date,
             created_at, updated_at, row_version)
        VALUES (:userId, 0, 0, NULL, :now, :now, 0)
        ON CONFLICT (user_id) DO NOTHING
        """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId, @Param("now") Instant now);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT s FROM UserLearningStreak s WHERE s.userId = :userId")
    Optional<UserLearningStreak> findForUpdate(@Param("userId") UUID userId);
}
```

```java
public interface UserLearningStreakDayRepository
        extends JpaRepository<UserLearningStreakDay, StreakDayId> {

    @Modifying @Query(value = """
        INSERT INTO user_learning_streak_days
            (user_id, study_date, lesson_id, learner_attempt_id, completed_at)
        VALUES (:userId, :studyDate, :lessonId, :attemptId, :completedAt)
        ON CONFLICT (user_id, study_date) DO NOTHING
        """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("studyDate") LocalDate studyDate,
                     @Param("lessonId") UUID lessonId,
                     @Param("attemptId") UUID attemptId,
                     @Param("completedAt") Instant completedAt);

    List<UserLearningStreakDay> findByUserIdAndStudyDateBetweenOrderByStudyDateAsc(
            UUID userId, LocalDate from, LocalDate to);

    boolean existsByUserIdAndStudyDate(UUID userId, LocalDate studyDate);
}
```

### Step 5 â€” `StreakProperties.java`

```java
@ConfigurationProperties(prefix = "dauviet.streak")
public record StreakProperties(boolean enabled, String timezone) {
    public StreakProperties {
        if (timezone == null || timezone.isBlank()) timezone = "Asia/Ho_Chi_Minh";
    }
}
```
Register via `@ConfigurationPropertiesScan` (already used project-wide â€” verify in `DauVietApplication` or a `@EnableConfigurationProperties`).

### Step 6 â€” `StreakService.java`

```java
@Service
public class StreakService {
    private static final ZoneId VN_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private final UserLearningStreakRepository streaks;
    private final UserLearningStreakDayRepository days;
    private final StreakProperties props;
    private final Clock clock;

    /* ---------- write path ---------- */

    /**
     * Ghi nháº­n 1 attempt COMPLETED. ÄÆ°á»£c gá»i Tá»ª LearnerAttemptService.doComplete()
     * TRONG CĂ™NG transaction. Idempotent: same (user, study_date) â†’ no-op.
     * Tráº£ StreakUpdateResult Ä‘á»ƒ controller cá»™ng thĂªm streakIncreased/newStreak.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public StreakUpdateResult recordCompletion(UUID userId, UUID lessonId,
                                               UUID attemptId, Instant completedAt) {
        if (!props.enabled()) {
            return StreakUpdateResult.disabled();
        }
        Instant now = Instant.now(clock);
        LocalDate studyDate = completedAt.atZone(zone()).toLocalDate();
        LocalDate today = now.atZone(zone()).toLocalDate();

        // 1) Lazy-create parent + lock
        UserLearningStreak s = lockedOrCreate(userId, now);

        // 2) Idempotent write of day-row. Return value is the ground truth:
        //    1 = new day, 0 = already recorded.
        int written = days.insertIgnore(userId, studyDate, lessonId,
                                        attemptId, completedAt);
        int prev = s.getCurrentStreak();
        if (written == 0) {
            // ÄĂ£ ghi ngĂ y nĂ y â€” replay/2nd-device: no-op, khĂ´ng tÄƒng.
            return new StreakUpdateResult(false, prev, prev, true, studyDate);
        }

        // 3) Apply day-under-lock
        s.applyQualifiedDay(studyDate, now);
        streaks.save(s);
        return new StreakUpdateResult(
                s.getCurrentStreak() > prev || prev == 0,
                s.getCurrentStreak(), prev,
                studyDate.equals(today), studyDate);
    }

    /* ---------- read paths ---------- */

    @Transactional
    public StreakStateResponse stateOf(UUID userId) {
        Instant now = Instant.now(clock);
        LocalDate today = now.atZone(zone()).toLocalDate();
        UserLearningStreak s = lockedOrCreate(userId, now);
        boolean completedToday = today.equals(s.getLastQualifiedDate());
        boolean alive = s.getLastQualifiedDate() != null
                && !s.getLastQualifiedDate().isBefore(today.minusDays(1));
        return new StreakStateResponse(
                s.getCurrentStreak(), s.getLongestStreak(),
                completedToday, s.getLastQualifiedDate(),
                today, zone().getId(), now, alive);
    }

    @Transactional(readOnly = true)
    public List<LocalDate> calendarOf(UUID userId, LocalDate from, LocalDate to) {
        return days.findByUserIdAndStudyDateBetweenOrderByStudyDateAsc(
                userId, from, to)
            .stream().map(UserLearningStreakDay::getStudyDate).toList();
    }

    /* ---------- internals ---------- */

    private UserLearningStreak lockedOrCreate(UUID userId, Instant now) {
        UserLearningStreak s = streaks.findForUpdate(userId).orElse(null);
        if (s == null) {
            streaks.insertIgnore(userId, now);
            s = streaks.findForUpdate(userId).orElseThrow(() ->
                new IllegalStateException("streak row lost for " + userId));
        }
        return s;
    }

    private ZoneId zone() { return ZoneId.of(props.timezone()); }
}
```

### Step 7 â€” `StreakUpdateResult.java` + `StreakStateResponse.java`

DTO lives in `api/dto/` (phase-03 creates the package; declare now to satisfy service signature).

```java
public record StreakUpdateResult(
        boolean streakIncreased,
        int newStreak,
        int previousStreak,
        boolean completedToday,
        LocalDate studyDate) {
    public static StreakUpdateResult disabled() {
        return new StreakUpdateResult(false, 0, 0, false, null);
    }
}
```

## Todo List
- [ ] Create `com.dauviet.streak` package skeleton.
- [ ] Write `StreakDayId`, `UserLearningStreak`, `UserLearningStreakDay` entities.
- [ ] Write `UserLearningStreakRepository` + `UserLearningStreakDayRepository`.
- [ ] Write `StreakProperties` + register in `@ConfigurationPropertiesScan` if not auto.
- [ ] Write `StreakUpdateResult` record.
- [ ] Write `StreakService` (recordCompletion, stateOf, calendarOf, lockedOrCreate).
- [ ] Compile: `./mvnw compile` â†’ green.
- [ ] Verify no references to `gamification` umbrella package.

## Success Criteria
- Code compiles.
- `StreakService` is Spring-discovered (`@Service`, package scanned â€” verify `com.dauviet` is base scan).
- All DB access funnels through `lockedOrCreate` for writes (lock-order invariant: learner_attempts â†’ user_learning_streaks, matching `attempt â†’ user_energy` precedent).

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Race: 2 devices complete same day â†’ `current_streak` increments twice | `days.insertIgnore` returns 0 for loser â†’ no `applyQualifiedDay`. UNIQUE is final arbiter. |
| Lock-order deadlock vs energy/reward | Order enforced: caller already holds `learner_attempts` lock; streak lock is leaf â€” never acquires further locks. |
| Timezone bug (UTC date used) | `studyDate` computed via `VN_ZONE` ZoneId once; IT in phase-04 asserts boundary 23:55 UTC+7 â†’ next-day roll. |
| `streakIncreased` semantics wrong on streak=1 first-ever | `prev == 0` short-circuit returns `true` â€” first day counts as an increase for UI celebration. |
| `props.enabled=false` short-circuit breaks API | `disabled()` result; controller still returns zero-state for `stateOf` (or `enabled` flag in payload â€” phase-03 decides). |

## Security Considerations
- `userId` always comes from JWT (`@AuthenticationPrincipal`) â€” never from path/body. Caller (`LearnerAttemptService`) already validated ownership.
- No raw SQL beyond `insertIgnore` â€” no injection surface.
- Read endpoints scoped to self (`/me/*`).

## Next Steps
- Phase 03 wires `StreakService` into `LearnerAttemptService.doComplete()` + creates `StreakController` + DTOs.
