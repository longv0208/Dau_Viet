# Phase 01 â€” Database Flyway V31 + Backfill Script

## Context Links
- `dau-viet-backend/src/main/resources/db/migration/V21__gamification_energy.sql` â€” DDL template (PK on user_id, CHECK constraints, `ux_` prefix, TIMESTAMPTZ, `row_version`).
- `docs/DATABASE_DESIGN.md` â€” table docs through V30; `learner_attempts.completed_at TIMESTAMPTZ` is backfill source.
- `dau-viet-backend/src/main/resources/db/migration/` â€” authoritative migration dir (next = **V31**).
- `dau-viet-db/db/migration/` â€” secondary copy; sync V31 to both.

## Overview
- **Priority**: P1 (blocks all subsequent phases)
- **Status**: complete
- **Est**: 3h

Create `V31__learning_streaks.sql` (2 tables + indexes + FK + CHECK). Backfill is a **separate, manually invoked script** (`backfill_streak.sql`) â€” NOT auto-applied by Flyway â€” because the set-based INSERT over `learner_attempts` history can be slow and we want operator control + dry-run capability.

## Key Insights
- `user_learning_streaks` is 1 row per user (PK=`user_id`), lazy-created via `insertIgnore` like `user_energy`.
- `user_learning_streak_days` is the per-day audit log â€” `UNIQUE(user_id, study_date)` is the idempotency backstop that makes concurrent same-day completes safe even if both race past the lock (DB-level final say).
- `study_date` stored as `DATE` (not TIMESTAMP) â€” already in `Asia/Ho_Chi_Minh` civil date.
- `last_qualified_date` denormalized on parent for O(1) `stateOf()` read; canonical record is the days table.
- Backfill: derive `(user_id, study_date)` distinct pairs from `learner_attempts WHERE status='COMPLETED'`, taking `MIN(completed_at)` per pair; then compute `current_streak`/`longest_streak` per user by walking consecutive date runs.

## Requirements
- **Functional**: 2 tables, FK to `users(id)`, idempotent re-run safe (`CREATE TABLE IF NOT EXISTS` for safety in test envs is OK; Flyway baseline ensures once-only).
- **Non-functional**: indexes support `SELECT ... WHERE user_id=? AND study_date BETWEEN ? AND ?` (calendar) and `SELECT ... WHERE user_id=? ORDER BY study_date DESC LIMIT 1` (recent day).
- **Backfill**: idempotent (re-run produces same result); dry-run mode produces report only; batched commits optional for very large histories.

## Architecture

```
learner_attempts (existing)
   â””â”€â”€ completed_at TIMESTAMPTZ  â”€â”€â”
                                   â”‚  (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
                                   â–¼
                  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                  â”‚ user_learning_streak_days        â”‚
                  â”‚  (user_id, study_date) UNIQUE    â”‚
                  â”‚  lesson_id, learner_attempt_id   â”‚
                  â”‚  completed_at (first of day)     â”‚
                  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                   â”‚
                          aggregate (on write)
                                   â–¼
                  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                  â”‚ user_learning_streaks            â”‚
                  â”‚  PK user_id                      â”‚
                  â”‚  current_streak, longest_streak  â”‚
                  â”‚  last_qualified_date             â”‚
                  â”‚  row_version                     â”‚
                  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
```

## Related Code Files

**Create**:
- `dau-viet-backend/src/main/resources/db/migration/V31__learning_streaks.sql` â€” DDL only.
- `dau-viet-db/db/migration/V31__learning_streaks.sql` â€” identical copy for the standalone DB module.
- `dau-viet-db/scripts/backfill_streak.sql` â€” manual backfill w/ `\set dry_run` flag.

**Modify**: none (backfill is not in V31; admin endpoint optional in phase-02).

**Delete**: none.

## Implementation Steps

### Step 1 â€” Write V31 migration

File: `dau-viet-backend/src/main/resources/db/migration/V31__learning_streaks.sql`

```sql
-- Dáº¥u Viá»‡t | V31 | Learning Streak (Chuá»—i NgĂ y Há»c) â€” server-authoritative.
-- user_learning_streaks: Ä‘Ăºng 1 dĂ²ng/user (PK = user_id), lazy-create láº§n
-- Ä‘áº§u COMPLETED attempt ghi nháº­n â€” KHĂ”NG seed hĂ ng loáº¡t.
-- user_learning_streak_days: append-only audit; UNIQUE (user_id, study_date)
-- cháº·n race hai thiáº¿t bá»‹ cĂ¹ng complete trong cĂ¹ng ngĂ y theo giá» VN.
CREATE TABLE user_learning_streaks (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    -- NgĂ y VN gáº§n nháº¥t cĂ³ â‰¥1 attempt COMPLETED. NULL = chÆ°a há»c bao giá».
    last_qualified_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_streak_nonneg CHECK (current_streak >= 0
        AND longest_streak >= 0),
    CONSTRAINT chk_streak_order CHECK (longest_streak >= current_streak)
);

CREATE TABLE user_learning_streak_days (
    user_id UUID NOT NULL REFERENCES users(id),
    study_date DATE NOT NULL,
    -- Attempt COMPLETED Ä‘áº§u tiĂªn cá»§a ngĂ y VN Ä‘Ă³ (winner cá»§a race).
    lesson_id UUID,
    learner_attempt_id UUID,
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_streak_days PRIMARY KEY (user_id, study_date)
);
-- Calendar view + debug "khi nĂ o há»c láº§n cuá»‘i".
CREATE INDEX idx_streak_days_user_date ON user_learning_streak_days(user_id, study_date DESC);
```

Sync byte-identical copy to `dau-viet-db/db/migration/V31__learning_streaks.sql` (project convention).

### Step 2 â€” Write backfill script (manual, dry-run capable)

File: `dau-viet-db/scripts/backfill_streak.sql`

```sql
-- Idempotent backfill: populate user_learning_streak_days + user_learning_streaks
-- from learner_attempts where status='COMPLETED'.
-- Dry-run:  psql -v dry_run=1 -f backfill_streak.sql
-- Real run: psql -f backfill_streak.sql
\set ON_ERROR_STOP on

BEGIN;

-- Step 1: insert one row per (user, vn-date) pair with the FIRST completion.
WITH firsts AS (
  SELECT user_id,
         (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS study_date,
         MIN(completed_at) AS first_completed_at,
         (array_agg(lesson_id ORDER BY completed_at))[1] AS lesson_id,
         (array_agg(id ORDER BY completed_at))[1] AS attempt_id
    FROM learner_attempts
   WHERE status = 'COMPLETED' AND completed_at IS NOT NULL
   GROUP BY user_id, (completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
)
INSERT INTO user_learning_streak_days
    (user_id, study_date, lesson_id, learner_attempt_id, completed_at)
SELECT user_id, study_date, lesson_id, attempt_id, first_completed_at
  FROM firsts
ON CONFLICT (user_id, study_date) DO NOTHING;

-- Step 2: compute streaks per user (consecutive-day runs).
WITH ordered AS (
  SELECT user_id, study_date,
         study_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY study_date))::int
           AS grp
    FROM user_learning_streak_days
),
runs AS (
  SELECT user_id, grp, COUNT(*) AS run_len, MAX(study_date) AS run_end
    FROM ordered
   GROUP BY user_id, grp
),
per_user AS (
  SELECT r.user_id,
         MAX(r.run_len) AS longest,
         (SELECT run_len FROM runs r2
            WHERE r2.user_id = r.user_id
              AND r2.run_end = (SELECT MAX(study_date) FROM user_learning_streak_days d
                                 WHERE d.user_id = r.user_id)
         ) AS trailing_run_len,
         (SELECT MAX(study_date) FROM user_learning_streak_days d
           WHERE d.user_id = r.user_id) AS last_date
    FROM runs r
   GROUP BY r.user_id
)
INSERT INTO user_learning_streaks
    (user_id, current_streak, longest_streak, last_qualified_date)
SELECT user_id,
       -- current = trailing run IF last_date == today VN or yesterday VN
       CASE WHEN last_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 1
            THEN trailing_run_len ELSE 0 END,
       longest,
       last_date
  FROM per_user
ON CONFLICT (user_id) DO UPDATE SET
    current_streak = EXCLUDED.current_streak,
    longest_streak = EXCLUDED.longest_streak,
    last_qualified_date = EXCLUDED.last_qualified_date,
    updated_at = now();

-- Report
SELECT COUNT(*) AS days_written FROM user_learning_streak_days;
SELECT COUNT(*) AS users_with_streak FROM user_learning_streaks;

\if :dry_run
  \echo 'DRY-RUN: rolling back'
  ROLLBACK;
\else
  COMMIT;
\endif
```

### Step 3 â€” Sanity check on dev DB
- `mvnw flyway:migrate` (or restart app) â†’ confirm V31 applied, tables exist.
- `psql -v dry_run=1 -f backfill_streak.sql` â†’ verify counts >0, no error.
- `psql -f backfill_streak.sql` â†’ real run.
- Re-run script â†’ idempotent (no diff).

### Step 4 â€” Update table count test
- `FlywayMigrationIT` likely asserts table count (currently 18+). Update assertion to +2 â†’ 20 (search: `FlywayMigrationIT` in `src/test`).

## Todo List
- [ ] Write `V31__learning_streaks.sql` in backend resources.
- [ ] Sync identical file to `dau-viet-db/db/migration/`.
- [ ] Write `dau-viet-db/scripts/backfill_streak.sql` with `\if :dry_run` toggle.
- [ ] Apply migration locally, verify schema.
- [ ] Dry-run backfill on dev DB, sanity-check counts.
- [ ] Real-run backfill on dev DB.
- [ ] Re-run backfill â€” confirm idempotent (counts identical, no error).
- [ ] Update `FlywayMigrationIT` expected table count.

## Success Criteria
- V31 applies cleanly on fresh + existing DB.
- Re-running backfill produces identical `user_learning_streaks` state (idempotent).
- `UNIQUE(user_id, study_date)` prevents duplicates â€” verify with manual `INSERT` of same pair twice (second fails).
- `current_streak` correctly = 0 when `last_qualified_date` is â‰¥ 2 days ago; = trailing run length otherwise.

## Risk Assessment
| Risk | Mitigation |
|------|------------|
| Backfill slow on huge `learner_attempts` | Separate script, not auto-migration; operator runs off-peak |
| Backfill computes `current_streak` wrong on boundary | `>= today-1` rule covers "yesterday still alive"; IT in phase-04 validates |
| Existing `learner_attempts` rows with `completed_at IS NULL` but status=COMPLETED | Filtered out; log count for ops review |
| Check constraint `longest >= current` fails on race | `current` written under FOR UPDATE; constraint is safety net |

## Security Considerations
- FK to `users(id)` with `ON DELETE` default (RESTRICT) â€” prevents orphan streaks; acceptable (delete-user flow not in scope).
- No PII beyond `user_id` (already PK elsewhere).

## Next Steps
- Phase 02 implements `StreakService` reading these tables.
- Phase 03 wires `recordCompletion()` into `doComplete()` â€” the writer path goes live.
