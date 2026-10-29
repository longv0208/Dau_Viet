-- Dấu Việt | V51 | ISLAND-10 — Đồng bộ Đảo Di Sản & Thao tác Bài trí theo thiết kế Web.
-- Phạm vi (issue #37):
--   1. Gỡ ux_user_island_item (UNIQUE user_id,item_id) — cho phép đặt nhiều bản sao.
--   2. Chuẩn hóa 3 cấp đảo: 12 / 28 / 56 ô, unlock theo Account Level (giữ V38).
--   3. Layout version 2 PUBLISHED: board isometric 8x7 = 56 tile + 56 slot
--      tier_required 1/2/3 + regions/layers. Version 1 -> ARCHIVED.
--   4. island_tier_policies + name_key / stage_label / highlights_json (metadata 3 tier).
--   5. item_catalog: bật placeable=true + render_key cho HISTORICAL_REPLICA/DIGITAL_EDITION.
-- Không backfill placements: upgrade xóa sạch placements -> item về user_inventory.

-- =============================================================================
-- 1. Gỡ UNIQUE "1 item 1 slot" trên đảo (cho phép đặt nhiều bản sao)
-- =============================================================================
ALTER TABLE user_island_placements
    DROP CONSTRAINT IF EXISTS ux_user_island_item;

-- =============================================================================
-- 2. Chuẩn hóa 3 cấp đảo 12 / 28 / 56 ô — giữ cơ chế Level (V38)
-- =============================================================================
-- Thêm metadata hiển thị cho 3 tier (dùng cho tiers[] trong IslandResponse).
ALTER TABLE island_tier_policies
    ADD COLUMN IF NOT EXISTS name_key VARCHAR(48),
    ADD COLUMN IF NOT EXISTS stage_label VARCHAR(128),
    ADD COLUMN IF NOT EXISTS highlights_json JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Deactivate config_version=2 (Level-based 4/8/12 slot).
UPDATE island_tier_policies SET active = false WHERE config_version = 2;

-- config_version=3: 12/28/56 ô, unlock theo Account Level 1/2/3.
INSERT INTO island_tier_policies
    (id, config_version, tier, slot_count, required_completed_events,
     required_level, active, name_key, stage_label, highlights_json)
VALUES
    (gen_random_uuid(), 3, 1, 12, 0, 1, true,
     'tier.small', 'Giai đoạn Sơ Khai',
     '["Lều trại thám tử","Bến thuyền gỗ","Bếp lửa trại","Cây chuối cảnh"]'::jsonb),
    (gen_random_uuid(), 3, 2, 28, 0, 2, true,
     'tier.medium', 'Giai đoạn Định Cư',
     '["Nhà sàn Hùng Vương","Trống đồng Đông Sơn","Cờ Hai Bà Trưng","Vườn thảo mộc"]'::jsonb),
    (gen_random_uuid(), 3, 3, 56, 0, 3, true,
     'tier.grand', 'Giai đoạn Toàn Bích',
     '["Hồ chiến tích Bạch Đằng","Đền danh tướng","Thành xoắn Cổ Loa","Chiến thuyền Rồng"]'::jsonb);

-- =============================================================================
-- 3. Layout version 2 — board isometric 8x7 = 56 ô
-- =============================================================================
DO $$
DECLARE
    def_id     UUID := '11100000-1111-4000-8000-000000000001';
    v1_id      UUID := '22200000-2222-4000-8000-000000000001';
    v2_id      UUID := '22200000-2222-4000-8000-000000000002';
    reg_t1     UUID := '33300000-3333-4000-8000-000000000011';
    reg_t2     UUID := '33300000-3333-4000-8000-000000000012';
    reg_t3     UUID := '33300000-3333-4000-8000-000000000013';
    r          INT;
    c          INT;
    slot_idx   INT := 0;
    tier_req   INT;
    reg_code   VARCHAR(48);
    tile_id_v  UUID;
    terrain    VARCHAR(24);
    visual     VARCHAR(64);
BEGIN
    -- 3a. Archive version 1, publish version 2
    UPDATE island_layout_versions
        SET status = 'ARCHIVED', archived_at = now(), updated_at = now()
        WHERE id = v1_id;

    INSERT INTO island_layout_versions
        (id, definition_id, version_number, status, row_version, published_at)
    VALUES
        (v2_id, def_id, 2, 'PUBLISHED', 0, now());

    -- 3b. Board 8 hàng x 7 cột = 56 ô (tile thoi 128x64 theo quy ước FE)
    INSERT INTO island_layout_boards
        (layout_version_id, grid_rows, grid_columns, tile_width, tile_height,
         board_origin_x, board_origin_y, projection_type, connectivity_required)
    VALUES
        (v2_id, 8, 7, 128.0, 64.0, 0.0, 0.0, 'ISOMETRIC', true);

    -- 3c. Regions: TIER_1 = 12 ô (r<3), TIER_2 = thêm 16 ô (r<5), TIER_3 = 28 ô còn lại
    INSERT INTO island_layout_regions
        (id, layout_version_id, region_code, unlock_tier, label, bounds_json, sort_order)
    VALUES
        (reg_t1, v2_id, 'TIER_1', 1, 'Bãi Cỏ Sơ Khai',
         '{"x":0.10,"y":0.05,"width":0.80,"height":0.30}'::jsonb, 1),
        (reg_t2, v2_id, 'TIER_2', 2, 'Đồi Định Cư',
         '{"x":0.05,"y":0.30,"width":0.90,"height":0.35}'::jsonb, 2),
        (reg_t3, v2_id, 'TIER_3', 3, 'Toàn Bích Di Sản',
         '{"x":0.05,"y":0.60,"width":0.90,"height":0.35}'::jsonb, 3);

    -- 3d. Scene layers cho v2 (nước + đảo + overlay + item)
    INSERT INTO island_scene_layers
        (id, layout_version_id, layer_key, layer_type, render_order, asset_ref, visibility_rule_json)
    VALUES
        (gen_random_uuid(), v2_id, 'water_bg', 'ANIMATED_WATER', 0, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v2_id, 'island_base', 'STATIC_IMAGE', 10,
         'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v2_id, 'water_ripple', 'AMBIENT_OVERLAY', 20, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v2_id, 'region_overlay', 'REGION_OVERLAY', 25, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v2_id, 'item_layer', 'ITEM_LAYER', 30, null,
         '{"minTier":1,"maxTier":3}'::jsonb);

    -- 3e. 56 tiles: hàng 0..7, cột 0..6. Phân tier + terrain theo hàng.
    FOR r IN 0..7 LOOP
        FOR c IN 0..6 LOOP
            slot_idx := slot_idx + 1;
            tile_id_v := gen_random_uuid();

            -- Gán tier theo hàng: r<3 -> T1, r<5 -> T2, else T3
            IF r < 3 THEN
                tier_req := 1;
                reg_code := 'TIER_1';
            ELSIF r < 5 THEN
                tier_req := 2;
                reg_code := 'TIER_2';
            ELSE
                tier_req := 3;
                reg_code := 'TIER_3';
            END IF;

            -- Terrain: viền đảo = SAND, lõi = GRASS, đường giữa = PATH, nước lác đảo
            terrain := 'GRASS';
            visual  := NULL;
            IF r = 0 OR r = 7 OR c = 0 OR c = 6 THEN
                terrain := 'SAND';
            ELSIF (r = 3 AND c BETWEEN 1 AND 5) THEN
                terrain := 'PATH';   -- đường mòn ngang giữa đảo
            ELSIF (r = 5 AND c = 3) THEN
                terrain := 'WATER';  -- hồ nước nhỏ T3
                visual  := 'scenery.lake_small';
            END IF;

            INSERT INTO island_tiles
                (id, layout_version_id, tile_key, row_index, col_index,
                 terrain_type, region_code, unlock_tier, buildable, visual_key, elevation)
            VALUES
                (tile_id_v, v2_id, 'tile_' || r || '_' || c, r, c,
                 terrain, reg_code, tier_req,
                 (terrain IN ('GRASS','PATH','SAND')), -- buildable trên đất
                 visual, 0);

            -- Mỗi tile buildable host 1 slot (allowed mọi loại item đã placeable)
            IF terrain IN ('GRASS','PATH','SAND') THEN
                INSERT INTO island_slots
                    (id, layout_code, layout_version_id, slot_index, tier_required,
                     coord_x, coord_y, stable_slot_key, region_code, tile_id,
                     z_index, anchor_x, anchor_y, width_norm, height_norm,
                     allowed_categories_json)
                VALUES
                    (gen_random_uuid(), 'heritage-village', v2_id, slot_idx, tier_req,
                     0.08 + (c::float / 6) * 0.84,   -- spread 8%..92% canvas
                     0.10 + (r::float / 7) * 0.78,
                     'slot_' || slot_idx, reg_code, tile_id_v,
                     slot_idx * 10, 0.5, 1.0, 0.10, 0.12,
                     '["DECOR","MO_HINH","HISTORICAL_REPLICA","DIGITAL_EDITION"]'::jsonb);
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- =============================================================================
-- 4. item_catalog — bật placeable cho bảo vật lịch sử & phiên bản số mô hình
-- =============================================================================
-- Chỉ bật cho item đã có trong catalog (không tạo mới). COMMEMORATIVE_BADGE
-- giữ placeable=false vì AdminItemService cấm loại này lên đảo.
UPDATE item_catalog
SET placeable = true,
    render_key = CASE code
        WHEN 'MO_HINH_TRONG_DONG_DONG_SON' THEN 'replica.trong_dong_dong_son'
        WHEN 'MO_HINH_THANH_NHA_HO'        THEN 'replica.thanh_nha_ho'
        WHEN 'MO_HINH_CHUA_MY_SON'         THEN 'replica.chua_my_son'
        WHEN 'PHIEN_BAN_SO_COC_BACH_DANG'  THEN 'replica.coc_bach_dang'
        WHEN 'PHIEN_BAN_SO_CO_LOA'         THEN 'replica.co_loa'
        WHEN 'PHIEN_BAN_SO_PHO_HOI_AN'     THEN 'replica.pho_hoi_an'
        ELSE render_key
    END,
    updated_at = now()
WHERE item_type IN ('HISTORICAL_REPLICA','DIGITAL_EDITION')
  AND active = true
  AND code IN (
      'MO_HINH_TRONG_DONG_DONG_SON',
      'MO_HINH_THANH_NHA_HO',
      'MO_HINH_CHUA_MY_SON',
      'PHIEN_BAN_SO_COC_BACH_DANG',
      'PHIEN_BAN_SO_CO_LOA',
      'PHIEN_BAN_SO_PHO_HOI_AN');
