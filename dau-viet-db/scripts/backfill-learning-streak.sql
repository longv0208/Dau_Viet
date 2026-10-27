-- STREAK-01 backfill: tái dựng user_learning_streak_days + user_learning_streaks
-- từ lịch sử learner_attempts.completed_at (status='COMPLETED').
--
-- Idempotent: INSERT ... ON CONFLICT DO NOTHING ở cả hai bảng; chạy lại
-- không nhân đôi. Nguồn sự thật = server-side completed_at (UTC → VN date).
--
-- Chạy:
--   psql -v dry_run=on  -f backfill-learning-streak.sql  → chỉ report, ROLLBACK
--   psql -v dry_run=off -f backfill-learning-streak.sql  → ghi thật, COMMIT
--   psql -f backfill-learning-streak.sql                 → mặc định dry-run.

\if :{?dry_run}
\else
    \set dry_run on
\endif

\echo ==== STREAK-01 BACKFILL dry_run=:dry_run ====

BEGIN;

-- ---------- 1) Rebuild candidate day rows từ attempts COMPLETED ----------
-- Mỗi (user, study_date) chọn attempt COMPLETED sớm nhất trong ngày đó —
-- attempt kích hoạt ngày = lần hoàn thành đầu tiên theo UTC ts.
CREATE TEMP TABLE _streak_src ON COMMIT DROP AS
SELECT DISTINCT ON (la.user_id, (la.completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
    la.user_id,
    (la.completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS study_date,
    lv.lesson_id,
    la.id AS learner_attempt_id,
    la.completed_at
FROM learner_attempts la
JOIN lesson_versions lv ON lv.id = la.lesson_version_id
WHERE la.status = 'COMPLETED' AND la.completed_at IS NOT NULL
ORDER BY la.user_id,
         (la.completed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
         la.completed_at ASC;

SELECT COUNT(*) AS source_day_rows FROM _streak_src;
SELECT COUNT(DISTINCT user_id) AS affected_users FROM _streak_src;

-- ---------- 2) Tính streak per user bằng gaps-and-islands ----------
-- Mỗi block các ngày liên tiếp = 1 chuỗi. Chuỗi "current" chỉ tính nếu
-- ngày cuối của block = hôm nay hoặc hôm qua (VN time) — còn lại là chuỗi
-- cũ đã ngắt, longest vẫn ghi nhận.
CREATE TEMP TABLE _streak_calc ON COMMIT DROP AS
WITH ordered AS (
    SELECT user_id, study_date,
           study_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY study_date))::int AS grp
    FROM _streak_src
),
blocks AS (
    SELECT user_id, grp,
           MIN(study_date) AS block_start,
           MAX(study_date) AS block_end,
           COUNT(*) AS block_len
    FROM ordered GROUP BY user_id, grp
),
per_user AS (
    SELECT user_id,
           MAX(block_len) AS longest,
           -- current = độ dài block CHỨA hôm nay hoặc hôm qua (VN).
           COALESCE(MAX(block_len) FILTER (
               WHERE block_end IN (
                   (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
                   (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date - 1)),
               0) AS current_val,
           MAX(block_end) AS last_day
    FROM blocks GROUP BY user_id
)
SELECT * FROM per_user;

-- ---------- 3) Report ----------
SELECT user_id, current_val AS current_streak, longest AS longest_streak,
       last_day AS last_qualified_date
  FROM _streak_calc ORDER BY user_id;

-- ---------- 4) Apply (vẫn trong tx; COMMIT/ROLLBACK quyết định ở cuối) ----------
INSERT INTO user_learning_streak_days
    (user_id, study_date, lesson_id, learner_attempt_id, completed_at)
SELECT user_id, study_date, lesson_id, learner_attempt_id, completed_at
FROM _streak_src
ON CONFLICT (user_id, study_date) DO NOTHING;

-- streaks: upsert; chỉ cập nhật nếu giá trị mới "mới hơn" (an toàn cho
-- user vừa complete trong lúc backfill chạy song song).
INSERT INTO user_learning_streaks
    (user_id, current_streak, longest_streak, last_qualified_date)
SELECT user_id, current_val, longest, last_day FROM _streak_calc
ON CONFLICT (user_id) DO UPDATE SET
    longest_streak = GREATEST(user_learning_streaks.longest_streak,
                              EXCLUDED.longest_streak),
    -- current chỉ ghi đè khi last_qualified_date cũ xa hơn — không đè ngày
    -- mới vừa ghi bởi transaction complete song song.
    current_streak = CASE
        WHEN user_learning_streaks.last_qualified_date IS NULL
          OR user_learning_streaks.last_qualified_date < EXCLUDED.last_qualified_date
        THEN EXCLUDED.current_streak
        ELSE user_learning_streaks.current_streak
    END,
    last_qualified_date = GREATEST(
        COALESCE(user_learning_streaks.last_qualified_date,
                 EXCLUDED.last_qualified_date),
        EXCLUDED.last_qualified_date),
    updated_at = now();

\if :dry_run
    \echo ==== DRY RUN — ROLLBACK ====
    ROLLBACK;
\else
    \echo ==== APPLY — COMMIT ====
    COMMIT;
\endif
