-- Dấu Việt | V44 | ISLAND-03 & ISLAND-04 — Versioned Island Layout System & Admin Builder.
-- Phạm vi:
--   1. Bảng island_layout_definitions: mô tả chủ đề layout (heritage-village, …).
--   2. Bảng island_layout_versions: phiên bản layout có trạng thái DRAFT/PUBLISHED/ARCHIVED, row_version.
--   3. Bảng island_layout_regions: vùng đất của layout, mở dần theo Tier.
--   4. Bảng island_scene_layers: lớp scene (background, water, overlay, …).
--   5. ALTER island_slots: thêm layout_version_id, stable_slot_key, region_code,
--      z_index, anchor_x, anchor_y, width_norm, height_norm, allowed_categories_json.
--      Đổi ux_island_slot sang (layout_version_id, slot_index).
--   6. ALTER user_islands: thêm layout_version_id.
--   7. SEED: heritage-village layout definition + version 1 PUBLISHED + regions + layers.
--   8. Backfill: island_slots heritage-v1 → layout_version_id + stable_slot_key + region_code.
--   9. Backfill: user_islands layout_version_id.
--  10. Thêm NOT NULL constraint lên island_slots.layout_version_id sau backfill.
-- Không sửa V32–V43; không chạm dữ liệu user ngoài backfill layout_version_id.

-- =============================================================================
-- 1. island_layout_definitions
-- =============================================================================
CREATE TABLE island_layout_definitions (
    id          UUID PRIMARY KEY,
    layout_key  VARCHAR(64) NOT NULL,
    name        VARCHAR(128) NOT NULL,
    description TEXT,
    canvas_width  DOUBLE PRECISION NOT NULL DEFAULT 960.0,
    canvas_height DOUBLE PRECISION NOT NULL DEFAULT 720.0,
    theme_key   VARCHAR(64),
    is_default  BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_island_layout_def_key UNIQUE (layout_key),
    CONSTRAINT chk_layout_canvas CHECK (
        canvas_width > 0 AND canvas_height > 0)
);
CREATE UNIQUE INDEX ux_island_layout_def_default
    ON island_layout_definitions(is_default) WHERE is_default;

-- =============================================================================
-- 2. island_layout_versions
-- =============================================================================
CREATE TABLE island_layout_versions (
    id               UUID PRIMARY KEY,
    definition_id    UUID NOT NULL REFERENCES island_layout_definitions(id),
    version_number   INTEGER NOT NULL,
    status           VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
    row_version      BIGINT NOT NULL DEFAULT 0,
    published_at     TIMESTAMPTZ,
    archived_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_island_layout_version UNIQUE (definition_id, version_number),
    CONSTRAINT chk_island_layout_status CHECK (
        status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED'))
);
-- Tối đa 1 PUBLISHED version mỗi definition tại một thời điểm.
CREATE UNIQUE INDEX ux_island_layout_version_published
    ON island_layout_versions(definition_id) WHERE status = 'PUBLISHED';

-- =============================================================================
-- 3. island_layout_regions
-- =============================================================================
-- Vùng đất trong layout — mở theo Tier. bounds_json mô tả hình chữ nhật
-- tương đối {x, y, width, height} để Flutter vẽ overlay khoá/mở.
-- region_code unique trong một version (TIER_1, TIER_2, TIER_3, …).
CREATE TABLE island_layout_regions (
    id              UUID PRIMARY KEY,
    layout_version_id UUID NOT NULL REFERENCES island_layout_versions(id),
    region_code     VARCHAR(48) NOT NULL,
    unlock_tier     INTEGER NOT NULL,
    label           VARCHAR(128),
    bounds_json     JSONB,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_island_region UNIQUE (layout_version_id, region_code),
    CONSTRAINT chk_island_region_tier CHECK (unlock_tier BETWEEN 1 AND 9)
);

-- =============================================================================
-- 4. island_scene_layers
-- =============================================================================
-- Lớp scene (background, water, island-base, overlay, …) cấu thành canvas.
-- Flutter đọc danh sách này để render từng lớp theo render_order ASC.
-- layer_type: STATIC_IMAGE, ANIMATED_WATER, REGION_OVERLAY, ITEM_LAYER, …
-- asset_ref: đường dẫn asset (relative) hoặc URL — null nếu layer dùng code.
-- visibility_rule_json: điều kiện hiển thị lớp {minTier, maxTier, …} — null = luôn hiện.
CREATE TABLE island_scene_layers (
    id                   UUID PRIMARY KEY,
    layout_version_id    UUID NOT NULL REFERENCES island_layout_versions(id),
    layer_key            VARCHAR(64) NOT NULL,
    layer_type           VARCHAR(32) NOT NULL,
    render_order         INTEGER NOT NULL DEFAULT 0,
    asset_ref            VARCHAR(255),
    visibility_rule_json JSONB,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_island_scene_layer UNIQUE (layout_version_id, layer_key),
    CONSTRAINT chk_scene_layer_type CHECK (layer_type IN (
        'STATIC_IMAGE', 'ANIMATED_WATER', 'REGION_OVERLAY',
        'ITEM_LAYER', 'AMBIENT_OVERLAY', 'FALLBACK_GRAPHICS'))
);

-- =============================================================================
-- 5. ALTER island_slots — thêm layout versioning + rendering metadata
-- =============================================================================
ALTER TABLE island_slots
    ADD COLUMN layout_version_id UUID REFERENCES island_layout_versions(id),
    ADD COLUMN stable_slot_key   VARCHAR(48),
    ADD COLUMN region_code       VARCHAR(48),
    ADD COLUMN z_index           INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN anchor_x          DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    ADD COLUMN anchor_y          DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    ADD COLUMN width_norm        DOUBLE PRECISION NOT NULL DEFAULT 0.10,
    ADD COLUMN height_norm       DOUBLE PRECISION NOT NULL DEFAULT 0.12,
    ADD COLUMN allowed_categories_json JSONB NOT NULL DEFAULT '["DECOR"]'::jsonb;

-- =============================================================================
-- 6. ALTER user_islands — lưu layout version được dùng khi tạo đảo
-- =============================================================================
ALTER TABLE user_islands
    ADD COLUMN layout_version_id UUID REFERENCES island_layout_versions(id);

-- =============================================================================
-- 7. SEED: heritage-village layout definition + version 1 + regions + layers
-- =============================================================================
DO $$
DECLARE
    def_id     UUID := '11100000-1111-4000-8000-000000000001';
    ver_id     UUID := '22200000-2222-4000-8000-000000000001';
    reg_t1_id  UUID := '33300000-3333-4000-8000-000000000001';
    reg_t2_id  UUID := '33300000-3333-4000-8000-000000000002';
    reg_t3_id  UUID := '33300000-3333-4000-8000-000000000003';
BEGIN
    -- 7a. Definition
    INSERT INTO island_layout_definitions
        (id, layout_key, name, description,
         canvas_width, canvas_height, theme_key, is_default)
    VALUES
        (def_id,
         'heritage-village',
         'Làng Di Sản',
         'Layout làng Việt cổ 2.5D isometric — chủ đề mặc định của Đảo Di Sản.',
         960.0, 720.0, 'heritage', true);

    -- 7b. Version 1 PUBLISHED
    INSERT INTO island_layout_versions
        (id, definition_id, version_number, status, row_version, published_at)
    VALUES
        (ver_id, def_id, 1, 'PUBLISHED', 0, now());

    -- 7c. Regions (mở theo Tier, bao phủ đúng toạ độ các slot Tier 1..3 của V32)
    INSERT INTO island_layout_regions
        (id, layout_version_id, region_code, unlock_tier, label, bounds_json, sort_order)
    VALUES
        (reg_t1_id, ver_id, 'TIER_1', 1, 'Khu Trung Tâm',
         '{"x":0.05,"y":0.08,"width":0.90,"height":0.44}'::jsonb, 1),
        (reg_t2_id, ver_id, 'TIER_2', 2, 'Khu Mở Rộng',
         '{"x":0.05,"y":0.38,"width":0.90,"height":0.40}'::jsonb, 2),
        (reg_t3_id, ver_id, 'TIER_3', 3, 'Khu Cao Cấp',
         '{"x":0.05,"y":0.62,"width":0.90,"height":0.34}'::jsonb, 3);

    -- 7d. Scene layers
    INSERT INTO island_scene_layers
        (id, layout_version_id, layer_key, layer_type, render_order, asset_ref, visibility_rule_json)
    VALUES
        (gen_random_uuid(), ver_id, 'water_bg', 'ANIMATED_WATER', 0, null, '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), ver_id, 'island_base', 'STATIC_IMAGE', 10,
         'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg', '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), ver_id, 'water_ripple', 'AMBIENT_OVERLAY', 20, null, '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), ver_id, 'region_overlay', 'REGION_OVERLAY', 25, null, '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), ver_id, 'item_layer', 'ITEM_LAYER', 30, null, '{"minTier":1,"maxTier":3}'::jsonb);
END $$;

-- =============================================================================
-- 8. Backfill island_slots (heritage-v1 → layout_version_id + metadata)
-- =============================================================================
UPDATE island_slots
SET
    layout_version_id = '22200000-2222-4000-8000-000000000001',
    stable_slot_key   = 'slot_' || slot_index,
    region_code       = CASE tier_required
                            WHEN 1 THEN 'TIER_1'
                            WHEN 2 THEN 'TIER_2'
                            WHEN 3 THEN 'TIER_3'
                            ELSE        'TIER_' || tier_required
                        END,
    z_index           = slot_index * 10
WHERE layout_code = 'heritage-v1';

-- =============================================================================
-- 9. Backfill user_islands — gán layout_version_id cho đảo đang dùng heritage-v1
-- =============================================================================
UPDATE user_islands
SET layout_version_id = '22200000-2222-4000-8000-000000000001'
WHERE layout_code = 'heritage-v1'
  AND layout_version_id IS NULL;

-- =============================================================================
-- 10. Constraints & Indexes sau backfill
-- =============================================================================
ALTER TABLE island_slots
    ALTER COLUMN layout_version_id SET NOT NULL,
    ALTER COLUMN stable_slot_key SET NOT NULL;

ALTER TABLE island_slots
    DROP CONSTRAINT IF EXISTS ux_island_slot,
    ADD CONSTRAINT ux_island_slot_version_index UNIQUE (layout_version_id, slot_index),
    ADD CONSTRAINT ux_island_slot_version_key UNIQUE (layout_version_id, stable_slot_key);

CREATE INDEX idx_island_slots_layout_version
    ON island_slots(layout_version_id, slot_index);

CREATE INDEX idx_island_scene_layers_version
    ON island_scene_layers(layout_version_id, render_order);

CREATE INDEX idx_island_layout_regions_version
    ON island_layout_regions(layout_version_id, sort_order);
