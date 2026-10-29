-- Dấu Việt | V51 | STREAK-02 Khiên Bảo Vệ Chuỗi + Thưởng Chuỗi Ngày Học.
-- Issue #38: mỗi learner tích trữ tối đa 3 khiên, đổi 20 Điểm Sử Ký / 1 khiên;
-- bỏ lỡ đúng 1 ngày mà còn khiên → tự trừ 1 khiên giữ chuỗi; nghỉ >= 2 ngày
-- hoặc hết khiên → reset chuỗi. Nối chuỗi ngày mới grant EXP + Điểm Sử Ký
-- (daily từ ngày 2+, mốc lớn tại 3/7/14/30) — idempotent theo (user,study_date).

-- ================= user_learning_streaks: shield_count =================
ALTER TABLE user_learning_streaks
    ADD COLUMN shield_count INTEGER NOT NULL DEFAULT 0,
    ADD CONSTRAINT chk_streak_shield_count
        CHECK (shield_count BETWEEN 0 AND 3);

-- ================= user_learning_streak_days: day_type + reward =================
-- Row SHIELD_PROTECTED: ngày bỏ lỡ được khiên cứu. lesson_id /
-- learner_attempt_id trỏ về attempt của NGÀY HỌC SAU (attempt đã kích hoạt
-- auto-consume) — FK vẫn hợp lệ, PK (user_id, study_date) chặn trùng ngày.
ALTER TABLE user_learning_streak_days
    ADD COLUMN day_type VARCHAR(20) NOT NULL DEFAULT 'STUDY',
    ADD COLUMN reward_exp INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN reward_points INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN milestone_day INTEGER,
    ADD CONSTRAINT chk_streak_day_type
        CHECK (day_type IN ('STUDY', 'SHIELD_PROTECTED')),
    ADD CONSTRAINT chk_streak_day_reward_nonneg
        CHECK (reward_exp >= 0 AND reward_points >= 0);

-- Tra cứu các ngày được khiên bảo vệ (calendar API).
CREATE INDEX idx_streak_days_user_type
    ON user_learning_streak_days (user_id, study_date)
    WHERE day_type = 'SHIELD_PROTECTED';
