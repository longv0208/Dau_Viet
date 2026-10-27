-- Dấu Việt | V38 | ISLAND-01 Account Level + Island Tier Level Policy.
-- Phạm vi:
--   1. Bảng account_level_thresholds: cấu hình ngưỡng EXP → Level có version.
--   2. Seed Level 1–5 theo business rules đã chốt.
--   3. Thêm cột required_level vào island_tier_policies.
--   4. Seed config_version=2 với required_level — thay thế logic required_completed_events.
-- Không sửa V32 đã áp dụng; không chạm dữ liệu user; không trừ EXP.

-- ================= account_level_thresholds =================
-- Ngưỡng EXP tích lũy tương ứng với từng Level tài khoản. Cơ chế
-- copy-on-write: thay đổi ngưỡng = config_version+1 (row mới), KHÔNG update
-- ngược — giống island_tier_policies. active=true đánh dấu version đang
-- hiệu lực; partial unique đảm bảo tối đa 1 active version tại một thời điểm.
-- Level được TÍNH từ tổng EXP; EXP KHÔNG bị tiêu hao khi level up.
CREATE TABLE account_level_thresholds (
    id             UUID PRIMARY KEY,
    config_version INTEGER NOT NULL,
    level          INTEGER NOT NULL,
    min_exp        BIGINT  NOT NULL,
    active         BOOLEAN NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_acct_level     CHECK (level   BETWEEN 1 AND 99),
    CONSTRAINT chk_acct_min_exp   CHECK (min_exp >= 0),
    CONSTRAINT ux_acct_level_cfg  UNIQUE (config_version, level)
);
-- Một (config_version, level) active duy nhất tại một thời điểm.
CREATE UNIQUE INDEX ux_acct_level_active
    ON account_level_thresholds(config_version, level) WHERE active;

-- ================= SEED Level 1–5 (config_version=1) =================
-- EXP tích lũy tối thiểu theo business rules ISLAND-01:
--   Level 1 →    0 EXP (mọi user từ đầu)
--   Level 2 →  500 EXP
--   Level 3 → 1200 EXP
--   Level 4 → 2100 EXP
--   Level 5 → 3200 EXP
INSERT INTO account_level_thresholds
    (id, config_version, level, min_exp, active)
VALUES
    (gen_random_uuid(), 1, 1,    0, true),
    (gen_random_uuid(), 1, 2,  500, true),
    (gen_random_uuid(), 1, 3, 1200, true),
    (gen_random_uuid(), 1, 4, 2100, true),
    (gen_random_uuid(), 1, 5, 3200, true);

-- ================= ALTER island_tier_policies =================
-- Thêm required_level: Level tài khoản tối thiểu để nâng lên tier này.
-- NULL = dùng logic cũ required_completed_events (backward compat cho row V32).
-- config_version=2 trở đi sẽ điền required_level và bỏ sự kiện làm điều kiện.
ALTER TABLE island_tier_policies
    ADD COLUMN required_level INTEGER;
ALTER TABLE island_tier_policies
    ADD CONSTRAINT chk_island_required_level
        CHECK (required_level IS NULL OR required_level BETWEEN 1 AND 99);

-- ================= SEED config_version=2: Level-based policy =================
-- Tier 1: Level 1 (0 EXP — mọi user mới đều có)
-- Tier 2: Level 2 (500 EXP)
-- Tier 3: Level 3 (1200 EXP)
-- Đặt active=false cho config_version=1 để chỉ config_version=2 active.
-- Thứ tự: insert config_version=2 trước, rồi deactivate version=1.
INSERT INTO island_tier_policies
    (id, config_version, tier, slot_count, required_completed_events,
     required_level, active)
VALUES
    (gen_random_uuid(), 2, 1,  4, 0, 1, true),
    (gen_random_uuid(), 2, 2,  8, 0, 2, true),
    (gen_random_uuid(), 2, 3, 12, 0, 3, true);

-- Deactivate config_version=1 (V32 seed). Không xóa để bảo tồn lịch sử.
UPDATE island_tier_policies
    SET active = false
    WHERE config_version = 1;
