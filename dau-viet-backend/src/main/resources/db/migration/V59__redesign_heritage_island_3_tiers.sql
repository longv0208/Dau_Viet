-- Dấu Việt | V59 | Issue #46 — Thiết kế lại Đảo Di Sản Isometric 2.5D (3 cấp đảo đồng tâm 4x4 / 6x6 / 8x8 & bộ vật phẩm mẫu).
-- Phạm vi:
--   1. island_tier_policies (config_version = 4):
--      - Tier 1: Đảo An Lạc (tier.an_lac) — 4x4 = 16 ô
--      - Tier 2: Đảo Phồn Thịnh (tier.phon_thinh) — 6x6 = 36 ô
--      - Tier 3: Đảo Trường Tồn (tier.truong_ton) — 8x8 = 64 ô
--   2. Layout version 3 PUBLISHED: board isometric 8x8 đồng tâm (16 / 36 / 64 ô buildable).
--      Archive version 2 -> ensureIsland() tự động chuyển đảo cũ sang version 3 và hoàn trả vật phẩm về user_inventory.
--   3. Bổ sung các vật phẩm mẫu từ thiết kế Issue #46 (Cột cờ, Tượng Lý Thái Tổ, Cây đào) và gắn metadata phân loại 5 danh mục.

-- =============================================================================
-- 1. Cập nhật island_tier_policies sang config_version = 4 (16 / 36 / 64 ô)
-- =============================================================================
UPDATE island_tier_policies SET active = false WHERE config_version = 3;

INSERT INTO island_tier_policies
    (id, config_version, tier, slot_count, required_completed_events,
     required_level, active, name_key, stage_label, highlights_json)
VALUES
    (gen_random_uuid(), 4, 1, 16, 0, 1, true,
     'tier.an_lac', 'Đảo An Lạc',
     '["Nhà đình","Cây đa","Giếng cổ","Cột cờ"]'::jsonb),
    (gen_random_uuid(), 4, 2, 36, 0, 2, true,
     'tier.phon_thinh', 'Đảo Phồn Thịnh',
     '["Tượng Lý Thái Tổ","Cây đào","Thuyền","Đèn lồng"]'::jsonb),
    (gen_random_uuid(), 4, 3, 64, 0, 3, true,
     'tier.truong_ton', 'Đảo Trường Tồn',
     '["Khuê Văn Các","Tháp Bút","Thành Cổ Loa","Cọc Bạch Đằng"]'::jsonb);

-- =============================================================================
-- 2. Layout version 3 — board isometric 8x8 đồng tâm (4x4 -> 6x6 -> 8x8)
-- =============================================================================
DO $$
DECLARE
    def_id     UUID := '11100000-1111-4000-8000-000000000001';
    v2_id      UUID := '22200000-2222-4000-8000-000000000002';
    v3_id      UUID := '22200000-2222-4000-8000-000000000003';
    reg_t1     UUID := '33300000-3333-4000-8000-000000000021';
    reg_t2     UUID := '33300000-3333-4000-8000-000000000022';
    reg_t3     UUID := '33300000-3333-4000-8000-000000000023';
    r          INT;
    c          INT;
    slot_idx   INT := 0;
    tier_req   INT;
    reg_code   VARCHAR(48);
    tile_id_v  UUID;
    terrain    VARCHAR(24);
    elev       INT;
BEGIN
    -- 2a. Archive version 2, publish version 3
    UPDATE island_layout_versions
        SET status = 'ARCHIVED', archived_at = now(), updated_at = now()
        WHERE id = v2_id;

    INSERT INTO island_layout_versions
        (id, definition_id, version_number, status, row_version, published_at)
    VALUES
        (v3_id, def_id, 3, 'PUBLISHED', 0, now());

    -- 2b. Board 8x8 = 64 ô đồng tâm
    INSERT INTO island_layout_boards
        (layout_version_id, grid_rows, grid_columns, tile_width, tile_height,
         board_origin_x, board_origin_y, projection_type, connectivity_required)
    VALUES
        (v3_id, 8, 8, 128.0, 64.0, 0.0, 0.0, 'ISOMETRIC', true);

    -- 2c. Regions đồng tâm: TIER_1 (4x4 = 16 ô), TIER_2 (6x6 = 36 ô), TIER_3 (8x8 = 64 ô)
    INSERT INTO island_layout_regions
        (id, layout_version_id, region_code, unlock_tier, label, bounds_json, sort_order)
    VALUES
        (reg_t1, v3_id, 'TIER_1', 1, 'Đảo An Lạc',
         '{"x":0.25,"y":0.25,"width":0.50,"height":0.50}'::jsonb, 1),
        (reg_t2, v3_id, 'TIER_2', 2, 'Đảo Phồn Thịnh',
         '{"x":0.125,"y":0.125,"width":0.75,"height":0.75}'::jsonb, 2),
        (reg_t3, v3_id, 'TIER_3', 3, 'Đảo Trường Tồn',
         '{"x":0.0,"y":0.0,"width":1.0,"height":1.0}'::jsonb, 3);

    -- 2d. Scene layers cho v3
    INSERT INTO island_scene_layers
        (id, layout_version_id, layer_key, layer_type, render_order, asset_ref, visibility_rule_json)
    VALUES
        (gen_random_uuid(), v3_id, 'water_bg', 'ANIMATED_WATER', 0, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v3_id, 'island_base', 'STATIC_IMAGE', 10,
         'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v3_id, 'water_ripple', 'AMBIENT_OVERLAY', 20, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v3_id, 'region_overlay', 'REGION_OVERLAY', 25, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v3_id, 'item_layer', 'ITEM_LAYER', 30, null,
         '{"minTier":1,"maxTier":3}'::jsonb);

    -- 2e. 64 tiles & 64 buildable slots đồng tâm
    FOR r IN 0..7 LOOP
        FOR c IN 0..7 LOOP
            slot_idx := slot_idx + 1;
            tile_id_v := gen_random_uuid();

            IF (r BETWEEN 2 AND 5) AND (c BETWEEN 2 AND 5) THEN
                tier_req := 1;
                reg_code := 'TIER_1';
            ELSIF (r BETWEEN 1 AND 6) AND (c BETWEEN 1 AND 6) THEN
                tier_req := 2;
                reg_code := 'TIER_2';
            ELSE
                tier_req := 3;
                reg_code := 'TIER_3';
            END IF;

            terrain := 'GRASS';
            elev := 0;

            -- Bậc thềm đá trung tâm cho công trình chính (elevation = 1)
            IF (r BETWEEN 2 AND 3) AND (c BETWEEN 2 AND 3) THEN
                terrain := 'DIRT';
                elev := 1;
            ELSIF (r = 4 AND c BETWEEN 1 AND 6) OR (c = 4 AND r BETWEEN 1 AND 6) THEN
                terrain := 'PATH';
            ELSIF (r = 0 OR r = 7) AND (c = 0 OR c = 7) THEN
                terrain := 'STONE';
            END IF;

            INSERT INTO island_tiles
                (id, layout_version_id, tile_key, row_index, col_index,
                 terrain_type, region_code, unlock_tier, buildable, visual_key, elevation)
            VALUES
                (tile_id_v, v3_id, 'tile_' || r || '_' || c, r, c,
                 terrain, reg_code, tier_req, true, null, elev);

            INSERT INTO island_slots
                (id, layout_code, layout_version_id, slot_index, tier_required,
                 coord_x, coord_y, stable_slot_key, region_code, tile_id,
                 z_index, anchor_x, anchor_y, width_norm, height_norm,
                 allowed_categories_json)
            VALUES
                (gen_random_uuid(), 'heritage-village', v3_id, slot_idx, tier_req,
                 0.08 + (c::float / 7.0) * 0.84,
                 0.08 + (r::float / 7.0) * 0.84,
                 'slot_' || slot_idx, reg_code, tile_id_v,
                 slot_idx * 10, 0.5, 1.0, 0.12, 0.14,
                 '["DECOR","MO_HINH","HISTORICAL_REPLICA","DIGITAL_EDITION"]'::jsonb);
        END LOOP;
    END LOOP;
END $$;

-- =============================================================================
-- 3. Bổ sung vật phẩm mẫu theo thiết kế Issue #46 & chuẩn hóa danh mục
-- =============================================================================
INSERT INTO item_catalog (
    id, code, name, description, category, item_type, rarity,
    placeable, render_key, source_metadata, active
)
VALUES
    ('d7d00000-0000-4000-8000-000000000013', 'DECOR_COT_CO',
     'Cột cờ truyền thống',
     'Cột cờ lễ hội thêu hoa văn cổ truyền tung bay trên Đảo Di Sản.',
     'DECOR', 'DECOR', 'UNCOMMON',
     TRUE, 'decor.cot_co',
     '{"note":"Vật phẩm trang trí Đảo Di Sản","islandCategory":"DECORATION","footprintScale":1.0}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000014', 'DECOR_TUONG_LY_THAI_TO',
     'Tượng Lý Thái Tổ',
     'Mô hình tượng đài vua Lý Thái Tổ cầm Chiếu dời đô trang trí Đảo Di Sản.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.tuong_ly_thai_to',
     '{"note":"Mô hình trang trí Đảo Di Sản","islandCategory":"DECORATION","footprintScale":1.15}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000015', 'DECOR_CAY_DAO',
     'Cây đào cổ thụ',
     'Cây đào mùa xuân nở hoa hồng thắm điểm tô sắc xuân cho Đảo Di Sản.',
     'DECOR', 'DECOR', 'UNCOMMON',
     TRUE, 'decor.cay_dao',
     '{"note":"Vật phẩm trang trí Đảo Di Sản","islandCategory":"TREE","footprintScale":1.25}'::jsonb,
     TRUE)
ON CONFLICT (code) DO UPDATE
SET placeable = TRUE,
    render_key = COALESCE(item_catalog.render_key, EXCLUDED.render_key),
    source_metadata = COALESCE(item_catalog.source_metadata, '{}'::jsonb) || EXCLUDED.source_metadata,
    updated_at = now();

INSERT INTO island_shop_items (item_id, price_points, active, sort_order)
SELECT c.id, v.price, TRUE, v.sort_order
FROM item_catalog c
JOIN (VALUES
    ('DECOR_COT_CO',           160, 13),
    ('DECOR_CAY_DAO',          190, 14),
    ('DECOR_TUONG_LY_THAI_TO', 260, 15)
) AS v(code, price, sort_order) ON v.code = c.code
ON CONFLICT (item_id) DO NOTHING;
