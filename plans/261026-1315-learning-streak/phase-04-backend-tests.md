# Phase 04 â€” Backend Tests (Unit + Integration)

## Context Links
- `dau-viet-backend/src/test/java/com/dauviet/energy/` â€” `EnergyServiceTest` + `EnergyServiceIT` patterns to mirror.
- `dau-viet-backend/src/test/java/com/dauviet/learning/` â€” existing `LearnerAttemptServiceIT` (completion tests).
- `dau-viet-backend/src/test/java/com/dauviet/FlywayMigrationIT.java` â€” table count + schema assertions.
- `src/test/resources/` â€” test config, `Clock` bean override precedents.

## Overview
- **Priority**: P1
- **Status**: complete
- **Est**: 4h

Cover `StreakService` with unit tests (mocked repos) + integration tests (real DB, transactional) + completion-flow tests proving atomicity & idempotency.

## Key Insights
- Inject fixed `Clock` in tests â†’ deterministic `studyDate` and timezone boundary tests (23:55 vs 00:05 VN).
- The `days.insertIgnore` return value is THE decision bit â€” test both branches.
- Concurrency test needs real DB (IT, not unit) â€” spawn 2 threads calling `recordCompletion` for same user same day, assert `current_streak=1` exactly.
- Atomicity: force `itemUnlocks` (or a stub) to throw AFTER `recordCompletion` â†’ verify day row not persisted (transaction rollback covers streak).

## Requirements
- â‰¥85% line coverage on `com.dauviet.streak`.
- IT runs against testcontainers/H2 (project standard â€” see existing ITs).
- All deterministic via `Clock` injection.
- Reuse existing test fixtures for `User`/`Lesson`/`LessonVersion`/`LearnerAttempt` creation (search `*IT.java` for `@BeforeEach` setups).

## Architecture

```
src/test/java/com/dauviet/streak/
  â”œâ”€â”€ application/
  â”‚   â”œâ”€â”€ StreakServiceTest.java          (unit, Mockito)
  â”‚   â””â”€â”€ StreakServiceIT.java            (real DB, @SpringBootTest)
  â””â”€â”€ api/
      â””â”€â”€ StreakControllerIT.java         (@WebMvcTest or full IT)
src/test/java/com/dauviet/learning/
  â””â”€â”€ LearnerAttemptServiceStreakIT.java  (doComplete streak side-effects)
src/test/java/com/dauviet/
  â””â”€â”€ FlywayMigrationIT.java               (update table count +2)
```

## Related Code Files

**Create**:
- `src/test/java/com/dauviet/streak/application/StreakServiceTest.java`
- `src/test/java/com/dauviet/streak/application/StreakServiceIT.java`
- `src/test/java/com/dauviet/streak/api/StreakControllerIT.java`
- `src/test/java/com/dauviet/learning/LearnerAttemptServiceStreakIT.java`

**Modify**:
- `src/test/java/com/dauviet/FlywayMigrationIT.java` â€” bump expected table count.

## Implementation Steps

### Step 1 â€” `StreakServiceTest` (unit, Mockito)

Cases:
- `recordCompletion_firstEverDay_createsRowAndIncrements` â€” `days.insertIgnore`â†’1; assert `current=1, longest=1, lastQualified=today`.
- `recordCompletion_sameDay_replay_noOp` â€” `days.insertIgnore`â†’0; assert no `applyQualifiedDay`, `streakIncreased=false`.
- `recordCompletion_consecutiveDay_increments` â€” pre-set `lastQualifiedDate=yesterday, current=3`; new `studyDate=today` â†’ `current=4`.
- `recordCompletion_gapOf2Days_resetsTo1` â€” `lastQualifiedDate=2 days ago` â†’ `current=1`, `longest` unchanged.
- `recordCompletion_sameDay_differentAttempt_stillOneDay` â€” same `studyDate`, different `attemptId` â†’ `insertIgnore`â†’0 â†’ no change.
- `stateOf_returnsAliveTrue_whenCompletedYesterday` â€” `lastQualifiedDate=yesterday`, `completedToday=false`, `streakAlive=true`.
- `stateOf_returnsAliveFalse_whenLastQualifiedTwoDaysAgo`.
- `stateOf_lazyCreatesRow_whenUserIsNew`.
- `calendarOf_filtersByRange` â€” repo mock returns list; assert filter/order.
- `recordCompletion_disabled_returnsDisabledResult` â€” `props.enabled=false`.

### Step 2 â€” `StreakServiceIT` (real DB)

- `@SpringBootTest` + inject `Clock` bean override (`Clock.fixed(...)`).
- Cases mirror Step 1 but with REAL `INSERT ON CONFLICT` â€” proves the SQL is correct.
- **Concurrency test**: `ExecutorService` 2 threads â†’ same `recordCompletion(userId, l, a, completedAt)` â†’ `CountDownLatch` start â†’ both join â†’ `assertEquals(1, streaks.findById(u).get().getCurrentStreak())` AND `assertEquals(1, days.count())`.
- **Timezone boundary**: `completedAt = 2026-10-26T16:59:59Z` (23:59:59 VN) vs `17:00:00Z` (00:00 VN next day) â†’ 2 different `study_date`s.

### Step 3 â€” `StreakControllerIT`

- `GET /me/streak` unauth â†’ 401.
- `GET /me/streak` auth fresh user â†’ `{currentStreak:0, longestStreak:0, completedToday:false, ...}`.
- `GET /me/streak/calendar` with valid range â†’ 200 list.
- `GET /me/streak/calendar` `to<from` â†’ 400.
- `GET /me/streak/calendar` range > 1 year â†’ 400.

### Step 4 â€” `LearnerAttemptServiceStreakIT`

- `completeAttempt_firstCompletion_recordsStreakDay` â€” full pipeline: create user, lesson, start attempt, complete â†’ assert `user_learning_streak_days` has row AND `CompleteAttemptResponse.streakIncreased=true`.
- `completeAttempt_idempotentReplay_noSecondDay` â€” same idempotency key, 2 calls â†’ only 1 day row; 2nd response `streakIncreased=false`.
- `completeAttempt_rollback_doesNotWriteStreak` â€” mock `itemUnlocks.evaluateAfterLessonCompletion` to throw â†’ assert no day row + attempt not COMPLETED.
- `completeAttempt_twoAttemptsSameDay_oneDayRow` â€” user completes 2 different lessons same day â†’ `current_streak=1` (not 2), day row count = 1.

### Step 5 â€” `FlywayMigrationIT` update
- Locate the table count assertion; bump +2 (or update list to include `user_learning_streaks` + `user_learning_streak_days`).

## Todo List
- [ ] Write `StreakServiceTest` (10 cases above).
- [ ] Write `StreakServiceIT` (real DB + concurrency + tz boundary).
- [ ] Write `StreakControllerIT` (5 cases).
- [ ] Write `LearnerAttemptServiceStreakIT` (4 cases).
- [ ] Update `FlywayMigrationIT` table count.
- [ ] `./mvnw test` green; `./mvnw verify` green for affected modules.
- [ ] Coverage report: `com.dauviet.streak` â‰¥85% lines.

## Success Criteria
- All new tests pass.
- Existing `LearnerAttemptServiceIT`, `EnergyServiceIT`, `EventCompletionIT` still pass â€” no regressions.
- Concurrency test deterministically passes (no flakes over 5 runs).

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Clock injection leaks between tests | New `Clock.fixed` per test, `@DirtiesContext` if needed |
| Concurrency test flaky on slow CI | Use `CountDownLatch` + generous timeout; assert on DB state (not timing) |
| Test data leaks across tests | `@Sql` cleanup or `@Transactional` test-rollback per existing IT pattern |
| `recordCompletion` ordering vs reward/event/item | Test asserts streak writes BEFORE response â€” order documented in code |

## Security Considerations
- No auth bypass tests needed beyond standard 401 check.
- Verify `userId` from JWT â€” can't pass arbitrary UUID in path.

## Next Steps
- Phase 05: mobile data layer (DTO, repo, providers).
