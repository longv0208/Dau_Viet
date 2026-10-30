-- Dấu Việt | V61 | Issue #50 — Đại tu toàn diện Đảo Di Sản theo thiết kế 9 màn hình (Đảo Nhỏ 6x6 / Đảo Vừa 8x8 / Đảo Lớn 10x10 & bộ công trình 2x2 / 1x1).
-- Phạm vi:
--   1. Mở rộng ràng buộc chk_island_slot_count (island_tier_policies) và chk_island_slot_idx (island_slots) lên 1..256.
--   2. island_tier_policies (config_version = 5):
--      - Tier 1: Đảo Nhỏ (tier.small)   — 6x6   = 36 ô
--      - Tier 2: Đảo Vừa (tier.medium)  — 8x8   = 64 ô
--      - Tier 3: Đảo Lớn (tier.grand)   — 10x10 = 100 ô
--   3. Layout version 4 PUBLISHED: board isometric 10x10 đồng tâm (36 / 64 / 100 ô buildable).
--      Archive version 3 -> ensureIsland() tự động chuyển đảo cũ sang version 4 và hoàn trả vật phẩm về user_inventory.
--   4. Bổ sung & chuẩn hóa danh mục công trình / vật phẩm 2x2 và 1x1 theo thiết kế 9 màn hình (Nhà rông, Đình làng, Chùa cổ, Tháp Chăm, Cây đa, Tre trúc, Cột cờ, Bức tượng).

-- =============================================================================
-- 1. Mở rộng giới hạn slot_count và slot_index lên 256 cho lưới 10x10 (100 ô)
-- =============================================================================
ALTER TABLE island_tier_policies
    DROP CONSTRAINT IF EXISTS chk_island_slot_count,
    ADD CONSTRAINT chk_island_slot_count CHECK (slot_count BETWEEN 1 AND 256);

ALTER TABLE island_slots
    DROP CONSTRAINT IF EXISTS chk_island_slot_idx,
    ADD CONSTRAINT chk_island_slot_idx CHECK (slot_index BETWEEN 1 AND 256);

-- =============================================================================
-- 2. Cập nhật island_tier_policies sang config_version = 5 (36 / 64 / 100 ô)
-- =============================================================================
UPDATE island_tier_policies SET active = false WHERE config_version = 4;

INSERT INTO island_tier_policies
    (id, config_version, tier, slot_count, required_completed_events,
     required_level, active, name_key, stage_label, highlights_json)
VALUES
    (gen_random_uuid(), 5, 1, 36, 0, 1, true,
     'tier.small', 'Đảo Nhỏ',
     '["Nhà rông","Đình làng","Cây đa","Cột cờ"]'::jsonb),
    (gen_random_uuid(), 5, 2, 64, 0, 2, true,
     'tier.medium', 'Đảo Vừa',
     '["Chùa cổ","Tháp Chăm","Tre trúc","Bức tượng"]'::jsonb),
    (gen_random_uuid(), 5, 3, 100, 0, 3, true,
     'tier.grand', 'Đảo Lớn',
     '["Khuê Văn Các","Tháp Bút","Thành Cổ Loa","Cọc Bạch Đằng"]'::jsonb);

-- =============================================================================
-- 3. Layout version 4 — board isometric 10x10 đồng tâm (6x6 -> 8x8 -> 10x10)
-- =============================================================================
DO $$
DECLARE
    def_id     UUID := '11100000-1111-4000-8000-000000000001';
    v3_id      UUID := '22200000-2222-4000-8000-000000000003';
    v4_id      UUID := '22200000-2222-4000-8000-000000000004';
    reg_t1     UUID := '33300000-3333-4000-8000-000000000031';
    reg_t2     UUID := '33300000-3333-4000-8000-000000000032';
    reg_t3     UUID := '33300000-3333-4000-8000-000000000033';
    r          INT;
    c          INT;
    slot_idx   INT := 0;
    tier_req   INT;
    reg_code   VARCHAR(48);
    tile_id_v  UUID;
    terrain    VARCHAR(24);
    elev       INT;
BEGIN
    -- 3a. Archive version 3, publish version 4
    UPDATE island_layout_versions
        SET status = 'ARCHIVED', archived_at = now(), updated_at = now()
        WHERE id = v3_id;

    INSERT INTO island_layout_versions
        (id, definition_id, version_number, status, row_version, published_at)
    VALUES
        (v4_id, def_id, 4, 'PUBLISHED', 0, now());

    -- 3b. Board 10x10 = 100 ô đồng tâm
    INSERT INTO island_layout_boards
        (layout_version_id, grid_rows, grid_columns, tile_width, tile_height,
         board_origin_x, board_origin_y, projection_type, connectivity_required)
    VALUES
        (v4_id, 10, 10, 128.0, 64.0, 0.0, 0.0, 'ISOMETRIC', true);

    -- 3c. Regions đồng tâm: TIER_1 (6x6 = 36 ô), TIER_2 (8x8 = 64 ô), TIER_3 (10x10 = 100 ô)
    INSERT INTO island_layout_regions
        (id, layout_version_id, region_code, unlock_tier, label, bounds_json, sort_order)
    VALUES
        (reg_t1, v4_id, 'TIER_1', 1, 'Đảo Nhỏ',
         '{"x":0.20,"y":0.20,"width":0.60,"height":0.60}'::jsonb, 1),
        (reg_t2, v4_id, 'TIER_2', 2, 'Đảo Vừa',
         '{"x":0.10,"y":0.10,"width":0.80,"height":0.80}'::jsonb, 2),
        (reg_t3, v4_id, 'TIER_3', 3, 'Đảo Lớn',
         '{"x":0.0,"y":0.0,"width":1.0,"height":1.0}'::jsonb, 3);

    -- 3d. Scene layers cho v4
    INSERT INTO island_scene_layers
        (id, layout_version_id, layer_key, layer_type, render_order, asset_ref, visibility_rule_json)
    VALUES
        (gen_random_uuid(), v4_id, 'water_bg', 'ANIMATED_WATER', 0, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v4_id, 'island_base', 'STATIC_IMAGE', 10,
         'assets/images/dv_ISL_generic_island-base-tiers_v01.jpg',
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v4_id, 'water_ripple', 'AMBIENT_OVERLAY', 20, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v4_id, 'region_overlay', 'REGION_OVERLAY', 25, null,
         '{"minTier":1,"maxTier":3}'::jsonb),
        (gen_random_uuid(), v4_id, 'item_layer', 'ITEM_LAYER', 30, null,
         '{"minTier":1,"maxTier":3}'::jsonb);

    -- 3e. 100 tiles & 100 buildable slots đồng tâm
    FOR r IN 0..9 LOOP
        FOR c IN 0..9 LOOP
            slot_idx := slot_idx + 1;
            tile_id_v := gen_random_uuid();

            IF (r BETWEEN 2 AND 7) AND (c BETWEEN 2 AND 7) THEN
                tier_req := 1;
                reg_code := 'TIER_1';
            ELSIF (r BETWEEN 1 AND 8) AND (c BETWEEN 1 AND 8) THEN
                tier_req := 2;
                reg_code := 'TIER_2';
            ELSE
                tier_req := 3;
                reg_code := 'TIER_3';
            END IF;

            terrain := 'GRASS';
            elev := 0;

            -- Bậc thềm trung tâm cho công trình 2x2 (elevation = 1)
            IF (r BETWEEN 3 AND 4) AND (c BETWEEN 3 AND 4) THEN
                terrain := 'DIRT';
                elev := 1;
            ELSIF (r = 5 AND c BETWEEN 1 AND 8) OR (c = 5 AND r BETWEEN 1 AND 8) THEN
                terrain := 'PATH';
            ELSIF (r = 0 OR r = 9) AND (c = 0 OR c = 9) THEN
                terrain := 'STONE';
            END IF;

            INSERT INTO island_tiles
                (id, layout_version_id, tile_key, row_index, col_index,
                 terrain_type, region_code, unlock_tier, buildable, visual_key, elevation)
            VALUES
                (tile_id_v, v4_id, 'tile_' || r || '_' || c, r, c,
                 terrain, reg_code, tier_req, true, null, elev);

            INSERT INTO island_slots
                (id, layout_code, layout_version_id, slot_index, tier_required,
                 coord_x, coord_y, stable_slot_key, region_code, tile_id,
                 z_index, anchor_x, anchor_y, width_norm, height_norm,
                 allowed_categories_json)
            VALUES
                (gen_random_uuid(), 'heritage-village', v4_id, slot_idx, tier_req,
                 0.06 + (c::float / 9.0) * 0.88,
                 0.06 + (r::float / 9.0) * 0.88,
                 'slot_' || slot_idx, reg_code, tile_id_v,
                 slot_idx * 10, 0.5, 1.0, 0.10, 0.12,
                 '["DECOR","MO_HINH","HISTORICAL_REPLICA","DIGITAL_EDITION"]'::jsonb);
        END LOOP;
    END LOOP;
END $$;

-- =============================================================================
-- 4. Bổ sung & chuẩn hóa bộ công trình 2x2 và vật phẩm 1x1 theo mẫu 9 màn hình
-- =============================================================================
INSERT INTO item_catalog (
    id, code, name, description, category, item_type, rarity,
    placeable, render_key, source_metadata, active
)
VALUES
    ('d7d00000-0000-4000-8000-000000000016', 'DECOR_NHA_RONG',
     'Nhà rông',
     'Biểu tượng văn hóa cộng đồng của người Việt.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.nha_rong',
     '{"note":"Công trình Đảo Di Sản","islandCategory":"BUILDING","footprintWidth":2,"footprintHeight":2,"footprintScale":1.52}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000017', 'DECOR_CHUA_CO',
     'Chùa cổ',
     'Ngôi chùa cổ thanh tịnh mang đậm dấu ấn kiến trúc truyền thống Việt Nam.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.chua_co',
     '{"note":"Công trình Đảo Di Sản","islandCategory":"BUILDING","footprintWidth":2,"footprintHeight":2,"footprintScale":1.50}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000018', 'DECOR_THAP_CHAM',
     'Tháp Chăm',
     'Tuyệt tác kiến trúc gạch nung Chămpa cổ đại trên Đảo Di Sản.',
     'DECOR', 'DECOR', 'EPIC',
     TRUE, 'decor.thap_cham',
     '{"note":"Công trình Đảo Di Sản","islandCategory":"BUILDING","footprintWidth":2,"footprintHeight":2,"footprintScale":1.48}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000019', 'DECOR_TRE_TRUC',
     'Tre trúc',
     'Lũy tre xanh kiên cường gắn liền với làng quê và lịch sử dân tộc.',
     'DECOR', 'DECOR', 'COMMON',
     TRUE, 'decor.tre_truc',
     '{"note":"Cây cối Đảo Di Sản","islandCategory":"TREE","footprintWidth":1,"footprintHeight":1,"footprintScale":1.24}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000008', 'DECOR_DINH_LANG',
     'Đình làng',
     'Ngôi đình cổ kính với mái đao cong vút, trung tâm sinh hoạt văn hóa của làng quê Việt.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.dinh_lang',
     '{"note":"Công trình Đảo Di Sản","islandCategory":"BUILDING","footprintWidth":2,"footprintHeight":2,"footprintScale":1.50}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000001', 'DECOR_CAY_DA',
     'Cây đa cổ thụ',
     'Biểu tượng của làng quê Việt Nam, nơi gắn kết cộng đồng và lưu giữ nhiều câu chuyện lịch sử.',
     'DECOR', 'DECOR', 'COMMON',
     TRUE, 'decor.cay_da',
     '{"note":"Cây cối Đảo Di Sản","islandCategory":"TREE","footprintWidth":2,"footprintHeight":2,"footprintScale":1.48}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000013', 'DECOR_COT_CO',
     'Cột cờ',
     'Cột cờ truyền thống tung bay tự hào trên Đảo Di Sản.',
     'DECOR', 'DECOR', 'UNCOMMON',
     TRUE, 'decor.cot_co',
     '{"note":"Trang trí Đảo Di Sản","islandCategory":"DECORATION","footprintWidth":1,"footprintHeight":1,"footprintScale":1.08}'::jsonb,
     TRUE),
    ('d7d00000-0000-4000-8000-000000000014', 'DECOR_TUONG_LY_THAI_TO',
     'Bức tượng',
     'Bức tượng lịch sử tôn vinh các bậc tiền nhân dựng nước và giữ nước.',
     'DECOR', 'DECOR', 'RARE',
     TRUE, 'decor.tuong_ly_thai_to',
     '{"note":"Trang trí Đảo Di Sản","islandCategory":"DECORATION","footprintWidth":1,"footprintHeight":1,"footprintScale":1.10}'::jsonb,
     TRUE)
ON CONFLICT (code) DO UPDATE
SET placeable = TRUE,
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    render_key = COALESCE(item_catalog.render_key, EXCLUDED.render_key),
    source_metadata = COALESCE(item_catalog.source_metadata, '{}'::jsonb) || EXCLUDED.source_metadata,
    updated_at = now();

INSERT INTO island_shop_items (item_id, price_points, active, sort_order)
SELECT c.id, v.price, TRUE, v.sort_order
FROM item_catalog c
JOIN (VALUES
    ('DECOR_NHA_RONG',         120, 16),
    ('DECOR_CHUA_CO',          180, 17),
    ('DECOR_THAP_CHAM',        200, 18),
    ('DECOR_TRE_TRUC',          40, 19),
    ('DECOR_DINH_LANG',        150, 20),
    ('DECOR_CAY_DA',            50, 21),
    ('DECOR_COT_CO',            60, 22),
    ('DECOR_TUONG_LY_THAI_TO',  80, 23)
) AS v(code, price, sort_order) ON v.code = c.code
ON CONFLICT (item_id) DO NOTHING;
