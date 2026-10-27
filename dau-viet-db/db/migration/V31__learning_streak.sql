-- Dấu Việt | V31 | STREAK-01 Chuỗi Ngày Học — Ngọn Lửa Hào Khí.
-- Daily Learning Streak: số ngày liên tiếp user hoàn thành ít nhất 1 lesson.
-- Nguồn sự thật: server-side completion timestamp (learner_attempts.completed_at)
-- chuyển đổi qua timezone Asia/Ho_Chi_Minh. KHÔNG tin client time.

-- ================= user_learning_streaks =================
-- Đúng 1 dòng/user (PK = user_id, lazy-create lần đầu complete). Lưu tổng hợp
-- hiện tại; row_version giữ optimistic lock, đường ghi serialize bằng
-- findForUpdate của service — hai thiết bị complete cùng lúc không tạo 2 ngày.
CREATE TABLE user_learning_streaks (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    -- Chuỗi ngày liên tiếp hiện tại; reset về 1 khi bỏ lỡ rồi học lại.
    current_streak INTEGER NOT NULL DEFAULT 0,
    -- Kỷ lục chuỗi dài nhất từng đạt — không bao giờ giảm.
    longest_streak INTEGER NOT NULL DEFAULT 0,
    -- Ngày gần nhất được công nhận (theo giờ VN); NULL = chưa từng học.
    last_qualified_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_streak_current_nonneg CHECK (current_streak >= 0),
    CONSTRAINT chk_streak_longest_nonneg CHECK (longest_streak >= 0),
    CONSTRAINT chk_streak_longest_ge_current CHECK (longest_streak >= current_streak)
);

-- ================= user_learning_streak_days =================
-- Ledger kiểm toán: 1 row cho mỗi ngày được công nhận. Lưu lesson + attempt
-- đầu tiên kích hoạt ngày đó; các bài hoàn thành sau cùng ngày không đổi row.
-- UNIQUE(user_id, study_date) chống concurrent insert tạo trùng ngày.
CREATE TABLE user_learning_streak_days (
    user_id UUID NOT NULL REFERENCES users(id),
    study_date DATE NOT NULL,
    lesson_id UUID NOT NULL REFERENCES lessons(id),
    learner_attempt_id UUID NOT NULL REFERENCES learner_attempts(id),
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_streak_days PRIMARY KEY (user_id, study_date)
);
-- Tra cứu lịch sử: mọi query lọc user + sort theo ngày.
CREATE INDEX idx_streak_days_user_date ON user_learning_streak_days(user_id, study_date DESC);

-- ================= BACKFILL =================
-- Chạy riêng, KHÔNG nằm trong migration — yêu cầu STREAK-01 có dry-run
-- trước. Script đặt tại dau-viet-db/scripts/backfill-learning-streak.sql
-- (idempotent, dùng INSERT ... ON CONFLICT DO NOTHING).
