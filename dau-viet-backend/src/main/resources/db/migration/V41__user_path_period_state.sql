-- =============================================================================
-- Migration V40: User Learning Path Period State (Touch & Per-Period Resume)
-- Purpose:
--   Track the learner's last interacted PERIOD chapter on a learning path so the
--   client can resume at the learner's chosen historical period while allowing
--   parallel exploration across periods.
-- =============================================================================

CREATE TABLE IF NOT EXISTS user_path_period_state (
    user_id            UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    path_code          VARCHAR(64) NOT NULL,
    period_chapter_id  UUID        NOT NULL REFERENCES learning_path_chapters(id) ON DELETE CASCADE,
    last_touched_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, path_code, period_chapter_id)
);

CREATE INDEX IF NOT EXISTS idx_user_path_period_last_touched
    ON user_path_period_state (user_id, path_code, last_touched_at DESC);
