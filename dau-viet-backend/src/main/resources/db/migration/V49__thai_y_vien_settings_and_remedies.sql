-- Dấu Việt | V49 | GAME-07 (Issue #28) Viện Thái Y: Cấu hình Thể lực
-- & Danh mục Vật phẩm Hồi phục.
-- Cho phép Admin điều chỉnh quy tắc Thể lực và CRUD vật phẩm Viện Thái Y
-- trực tiếp từ Web Admin (/thai-y-vien).

-- ================= 1. energy_policy_settings =================
-- Singleton row (id = 1) lưu chính sách Thể lực đang áp dụng toàn hệ thống.
-- max_energy bị giới hạn <= 100 để khớp với CHECK constraint
-- chk_user_energy_range (0..100) của V21.
CREATE TABLE energy_policy_settings (
    id SMALLINT PRIMARY KEY DEFAULT 1,
    enabled BOOLEAN NOT NULL DEFAULT true,
    max_energy INTEGER NOT NULL DEFAULT 100,
    incorrect_penalty INTEGER NOT NULL DEFAULT 10,
    recovery_amount INTEGER NOT NULL DEFAULT 5,
    recovery_interval_seconds INTEGER NOT NULL DEFAULT 900,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_energy_policy_singleton CHECK (id = 1),
    CONSTRAINT chk_energy_policy_max CHECK (max_energy BETWEEN 1 AND 100),
    CONSTRAINT chk_energy_policy_penalty CHECK (incorrect_penalty BETWEEN 1 AND 100),
    CONSTRAINT chk_energy_policy_rec_amt CHECK (recovery_amount BETWEEN 1 AND 100),
    CONSTRAINT chk_energy_policy_rec_int CHECK (recovery_interval_seconds BETWEEN 60 AND 86400)
);

INSERT INTO energy_policy_settings
    (id, enabled, max_energy, incorrect_penalty, recovery_amount, recovery_interval_seconds)
VALUES
    (1, true, 100, 10, 5, 900)
ON CONFLICT (id) DO NOTHING;

-- ================= 2. energy_remedies =================
-- Danh mục vật phẩm / liệu pháp hồi phục Thể lực tại Viện Thái Y (M-28).
-- points_cost = 0 tương ứng với gói Miễn phí (chỉ giới hạn bởi cooldown_seconds).
CREATE TABLE energy_remedies (
    id UUID PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    title VARCHAR(160) NOT NULL,
    description TEXT NOT NULL,
    rarity VARCHAR(24) NOT NULL DEFAULT 'COMMON',
    icon_key VARCHAR(80) NOT NULL DEFAULT 'energy_nuoc_voi',
    asset_id UUID REFERENCES assets(id),
    energy_gain INTEGER NOT NULL,
    points_cost BIGINT NOT NULL DEFAULT 0,
    cooldown_seconds INTEGER NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ux_energy_remedies_code UNIQUE (code),
    CONSTRAINT chk_energy_remedy_rarity CHECK (rarity IN ('COMMON', 'UNCOMMON', 'RARE', 'EPIC')),
    CONSTRAINT chk_energy_remedy_gain CHECK (energy_gain BETWEEN 1 AND 100),
    CONSTRAINT chk_energy_remedy_cost CHECK (points_cost >= 0),
    CONSTRAINT chk_energy_remedy_cooldown CHECK (cooldown_seconds >= 0)
);

CREATE INDEX idx_energy_remedies_active_sort
    ON energy_remedies(active, sort_order ASC, created_at ASC);

-- ================= 3. SEED 4 Vật phẩm Phương án B =================
INSERT INTO energy_remedies
    (id, code, title, description, rarity, icon_key, energy_gain, points_cost, cooldown_seconds, active, sort_order)
VALUES
    ('e7e00000-0000-4000-8000-000000000001', 'NUOC_VOI',
     'Nước Vối Tĩnh Tâm',
     'Bát nước vối ấm lành tính giúp sĩ tử thư giãn gân cốt, bồi bổ miễn phí mỗi ngày.',
     'COMMON', 'energy_nuoc_voi', 20, 0, 86400, true, 1),
    ('e7e00000-0000-4000-8000-000000000002', 'TRA_SEN',
     'Trà Sen Tây Hồ',
     'Trà sen ướp hương thơm ngát giúp tinh thần minh mẫn tức thì.',
     'UNCOMMON', 'energy_tra_sen', 30, 30, 14400, true, 2),
    ('e7e00000-0000-4000-8000-000000000003', 'NAM_LINH_CHI',
     'Nấm Linh Chi Ngự Dược',
     'Thảo dược đại bổ triều đình bồi bổ nguyên khí, chống mỏi mệt.',
     'RARE', 'energy_linh_chi', 50, 55, 43200, true, 3),
    ('e7e00000-0000-4000-8000-000000000004', 'SAM_NGOC_LINH',
     'Sâm Ngọc Linh Hoàng Gia',
     'Bảo vật sâm rừng nghìn năm phục hồi 100% sinh lực tức thì.',
     'EPIC', 'energy_sam_ngoc_linh', 100, 90, 86400, true, 4)
ON CONFLICT (code) DO NOTHING;
