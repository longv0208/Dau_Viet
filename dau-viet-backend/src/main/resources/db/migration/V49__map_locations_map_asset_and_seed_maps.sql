-- =============================================================================
-- Migration V49: Add map_asset_id to map_locations & seed historical map assets
-- Purpose:
--   1. Add nullable `map_asset_id` column on `map_locations` referencing `assets(id)`
--      so admins can configure/upload a custom map image per heritage location.
--   2. Register the 6 historical map background images in `assets`
--      (served from classpath:seed-assets/maps/*.jpg via AssetService).
--   3. Backfill `map_asset_id`, `cover_asset_id`, `slug`, and `short_summary`
--      for existing heritage locations where missing.
-- =============================================================================

ALTER TABLE map_locations
    ADD COLUMN IF NOT EXISTS map_asset_id UUID REFERENCES assets(id);

CREATE INDEX IF NOT EXISTS idx_map_locations_map_asset
    ON map_locations (map_asset_id);

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    -- Heritage cover assets (from V43)
    asset_den_hung     UUID := 'd7a70000-0000-4000-8000-000000000001';
    asset_me_linh      UUID := 'd7a70000-0000-4000-8000-000000000002';
    asset_bach_dang    UUID := 'd7a70000-0000-4000-8000-000000000003';
    asset_thang_long   UUID := 'd7a70000-0000-4000-8000-000000000004';
    asset_nhu_nguyet   UUID := 'd7a70000-0000-4000-8000-000000000005';
    asset_dien_bien    UUID := 'd7a70000-0000-4000-8000-000000000006';

    -- Historical map assets
    map_van_lang       UUID := 'd7a90000-0000-4000-8000-000000000001';
    map_hai_ba_trung   UUID := 'd7a90000-0000-4000-8000-000000000002';
    map_bach_dang      UUID := 'd7a90000-0000-4000-8000-000000000003';
    map_nhu_nguyet     UUID := 'd7a90000-0000-4000-8000-000000000004';
    map_dien_bien_phu  UUID := 'd7a90000-0000-4000-8000-000000000005';
    map_vietnam_bg     UUID := 'd7a90000-0000-4000-8000-000000000006';
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- 1. Register the 6 historical map images in `assets`
    INSERT INTO assets (id, storage_key, original_filename, mime_type, size_bytes, state, alt_text, created_by)
    VALUES
        (map_van_lang,      'assets/d7a90000-0000-4000-8000-000000000001.jpg', 'map_van_lang.jpg',                      'image/jpeg', 1424956, 'ACTIVE', 'Bản đồ Nước Văn Lang Thời Các Vua Hùng',             sys_user),
        (map_hai_ba_trung,  'assets/d7a90000-0000-4000-8000-000000000002.jpg', 'map_hai_ba_trung.jpg',                  'image/jpeg', 1339554, 'ACTIVE', 'Bản đồ Khởi Nghĩa Hai Bà Trưng (Năm 40)',            sys_user),
        (map_bach_dang,     'assets/d7a90000-0000-4000-8000-000000000003.jpg', 'dv_MAP_ngoquyen_bachdang-base_v01.jpg', 'image/jpeg', 1079580, 'ACTIVE', 'Bản đồ Thủy Chiến Bạch Đằng Giang 938',              sys_user),
        (map_nhu_nguyet,    'assets/d7a90000-0000-4000-8000-000000000004.jpg', 'map_nhu_nguyet.jpg',                    'image/jpeg', 1259087, 'ACTIVE', 'Bản đồ Phòng Tuyến Sông Như Nguyệt 1077',            sys_user),
        (map_dien_bien_phu, 'assets/d7a90000-0000-4000-8000-000000000005.jpg', 'map_dien_bien_phu.jpg',                 'image/jpeg', 1410505, 'ACTIVE', 'Bản đồ Chiến Dịch Điện Biên Phủ 1954',               sys_user),
        (map_vietnam_bg,    'assets/d7a90000-0000-4000-8000-000000000006.jpg', 'vietnam_journey_map_bg.jpg',            'image/jpeg', 1140278, 'ACTIVE', 'Bản đồ Hành Trình Lịch Sử Việt Nam',                 sys_user)
    ON CONFLICT (id) DO UPDATE SET
        original_filename = EXCLUDED.original_filename,
        mime_type = EXCLUDED.mime_type,
        size_bytes = EXCLUDED.size_bytes,
        state = EXCLUDED.state,
        alt_text = EXCLUDED.alt_text;

    -- 2. Backfill map_asset_id on canonical V43 locations
    UPDATE map_locations
    SET map_asset_id = map_van_lang
    WHERE map_asset_id IS NULL
      AND (id IN ('a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002')
           OR event_id = '00000000-0000-0000-0000-000000000005'
           OR slug IN ('khu-di-tich-den-hung', 'lang-co-van-lang-nga-ba-hac'));

    UPDATE map_locations
    SET map_asset_id = map_bach_dang,
        cover_asset_id = COALESCE(cover_asset_id, asset_bach_dang)
    WHERE map_asset_id IS NULL
      AND (id IN (
               'a0000000-0000-0000-0000-000000000003',
               'a0000000-0000-0000-0000-000000000004',
               'a0000000-0000-0000-0000-000000000005',
               '0523555a-d981-4d52-9f44-823d845b3bb1',
               'd53e37a1-4bcf-4600-9d09-0c58bf528297',
               'd977ca7a-8d5b-4f6c-88fe-69f1e70c0e41'
           )
           OR event_id = '00000000-0000-0000-0000-000000000001'
           OR LOWER(title) LIKE '%bạch đằng%'
           OR LOWER(title) LIKE '%nam triệu%');

    UPDATE map_locations
    SET map_asset_id = map_hai_ba_trung,
        cover_asset_id = COALESCE(cover_asset_id, asset_me_linh)
    WHERE map_asset_id IS NULL
      AND (id IN (
               'a0000000-0000-0000-0000-000000000006',
               'a0000000-0000-0000-0000-000000000007',
               '024163f8-6f37-4f21-93e0-cdf9e5cdd6a1',
               '848310dc-a709-472b-80e9-a555fed0d9d3',
               '3ae770ac-c6a7-489a-b912-3e2f7297c90d'
           )
           OR event_id = '00000000-0000-0000-0000-000000000002'
           OR LOWER(title) LIKE '%mê linh%'
           OR LOWER(title) LIKE '%hát môn%'
           OR LOWER(title) LIKE '%sông hát%'
           OR LOWER(title) LIKE '%luy lâu%');

    UPDATE map_locations
    SET map_asset_id = map_nhu_nguyet,
        cover_asset_id = COALESCE(cover_asset_id, asset_nhu_nguyet)
    WHERE map_asset_id IS NULL
      AND (id IN (
               'a0000000-0000-0000-0000-000000000008',
               'a0000000-0000-0000-0000-000000000009'
           )
           OR event_id = '00000000-0000-0000-0000-000000000003'
           OR LOWER(title) LIKE '%như nguyệt%'
           OR LOWER(title) LIKE '%sông cầu%'
           OR LOWER(title) LIKE '%đền xà%');

    UPDATE map_locations
    SET map_asset_id = map_dien_bien_phu,
        cover_asset_id = COALESCE(cover_asset_id, asset_dien_bien)
    WHERE map_asset_id IS NULL
      AND (id IN (
               'a0000000-0000-0000-0000-000000000010',
               'a0000000-0000-0000-0000-000000000011'
           )
           OR event_id = '00000000-0000-0000-0000-000000000004'
           OR LOWER(title) LIKE '%đồi a1%'
           OR LOWER(title) LIKE '%de castries%'
           OR LOWER(title) LIKE '%điện biên%');

    -- 3. Backfill slugs, cover_asset_id, short_summary, and map_asset_id for UNESCO & remaining locations
    UPDATE map_locations
    SET slug = COALESCE(slug, 'khu-trung-tam-hoang-thanh-thang-long'),
        kind = 'ANCIENT_CAPITAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'ce007bbe-e83d-4dc3-b0dc-3a6488f6bba5'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'khu-trung-tam-hoang-thanh-thang-long' AND id <> 'ce007bbe-e83d-4dc3-b0dc-3a6488f6bba5');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'thanh-noi-nha-ho'),
        kind = 'ANCIENT_CAPITAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'c3568481-e5f2-441b-9627-24ef3ab2a15c'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'thanh-noi-nha-ho' AND id <> 'c3568481-e5f2-441b-9627-24ef3ab2a15c');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'la-thanh-nha-ho'),
        kind = 'HERITAGE_SITE',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = '3998db04-ee85-43a1-9d05-4c72db5ef45a'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'la-thanh-nha-ho' AND id <> '3998db04-ee85-43a1-9d05-4c72db5ef45a');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'dan-nam-giao-nha-ho'),
        kind = 'MEMORIAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'edb798a2-8c8a-4315-951e-209178c3f9b0'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'dan-nam-giao-nha-ho' AND id <> 'edb798a2-8c8a-4315-951e-209178c3f9b0');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'khu-den-thap-my-son'),
        kind = 'ARCHAEOLOGICAL_SITE',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_den_hung),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'ea84aa8c-56ce-44bf-bc29-a3131d3f63ef'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'khu-den-thap-my-son' AND id <> 'ea84aa8c-56ce-44bf-bc29-a3131d3f63ef');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'do-thi-co-hoi-an'),
        kind = 'HERITAGE_SITE',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'fce92b6f-9034-46b1-9c1c-d7eca4b65ea8'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'do-thi-co-hoi-an' AND id <> 'fce92b6f-9034-46b1-9c1c-d7eca4b65ea8');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'kinh-thanh-hue'),
        kind = 'ANCIENT_CAPITAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = '94690458-b008-4dbd-87a3-963927f4c03b'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'kinh-thanh-hue' AND id <> '94690458-b008-4dbd-87a3-963927f4c03b');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'chua-thien-mu'),
        kind = 'MEMORIAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = 'c52e4e22-7dad-4b38-8f2c-ddc4de87db1f'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'chua-thien-mu' AND id <> 'c52e4e22-7dad-4b38-8f2c-ddc4de87db1f');

    UPDATE map_locations
    SET slug = COALESCE(slug, 'lang-vua-minh-mang'),
        kind = 'MEMORIAL',
        short_summary = COALESCE(short_summary, description),
        cover_asset_id = COALESCE(cover_asset_id, asset_thang_long),
        map_asset_id = COALESCE(map_asset_id, map_vietnam_bg)
    WHERE id = '43556cc6-5d85-476d-b009-76e8eb47de65'
      AND NOT EXISTS (SELECT 1 FROM map_locations WHERE slug = 'lang-vua-minh-mang' AND id <> '43556cc6-5d85-476d-b009-76e8eb47de65');

    UPDATE map_locations
    SET map_asset_id = map_vietnam_bg
    WHERE map_asset_id IS NULL;
END $$;
