-- =============================================================================
-- Migration V43: Sync AI Heritage Location Illustrations, Metadata & Media into DB
-- Purpose:
--   1. Register the 6 AI-generated historical heritage illustrations in `assets`
--      (served from classpath:seed-assets/heritage/*.jpg via AssetService).
--   2. Backfill slug, kind, short_summary, cover_asset_id, coordinate_precision,
--      visibility, and unlock_rule_mode for all 11 canonical map_locations
--      and add the 12th canonical location (Hoàng thành Thăng Long — Đoan Môn).
--   3. Sync `map_location_events` and `map_location_media` (with both `asset_id`
--      and `external_url` = '/heritage/*.jpg') so Admin UI and Learner APIs
--      receive complete cover images and rich media from the database.
-- =============================================================================

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    asset_den_hung     UUID := 'd7a70000-0000-4000-8000-000000000001';
    asset_me_linh      UUID := 'd7a70000-0000-4000-8000-000000000002';
    asset_bach_dang    UUID := 'd7a70000-0000-4000-8000-000000000003';
    asset_thang_long   UUID := 'd7a70000-0000-4000-8000-000000000004';
    asset_nhu_nguyet   UUID := 'd7a70000-0000-4000-8000-000000000005';
    asset_dien_bien    UUID := 'd7a70000-0000-4000-8000-000000000006';

    evt_thang_long UUID;
    loc_thang_long UUID := 'a0000000-0000-0000-0000-000000000012';
BEGIN
    -- Ensure system user exists for asset ownership
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- 1. Register 6 AI Heritage Illustration Assets in `assets`
    INSERT INTO assets (id, storage_key, original_filename, mime_type, size_bytes, state, alt_text, created_by)
    VALUES
        (asset_den_hung,   'assets/d7a70000-0000-4000-8000-000000000001.jpg', 'den-hung-phong-chau.jpg',     'image/jpeg', 972231,  'ACTIVE', 'Khu di tích Đền Hùng — Phong Châu (Văn Lang)',            sys_user),
        (asset_me_linh,    'assets/d7a70000-0000-4000-8000-000000000002.jpg', 'me-linh-hai-ba-trung.jpg',    'image/jpeg', 1100342, 'ACTIVE', 'Thành cổ Mê Linh — Đền Hai Bà Trưng (Năm 40)',            sys_user),
        (asset_bach_dang,  'assets/d7a70000-0000-4000-8000-000000000003.jpg', 'bai-coc-bach-dang.jpg',       'image/jpeg', 991583,  'ACTIVE', 'Bãi cọc Bạch Đằng Giang (Năm 938)',                       sys_user),
        (asset_thang_long, 'assets/d7a70000-0000-4000-8000-000000000004.jpg', 'hoang-thanh-thang-long.jpg',  'image/jpeg', 1105552, 'ACTIVE', 'Hoàng thành Thăng Long — Đoan Môn (Năm 1010)',            sys_user),
        (asset_nhu_nguyet, 'assets/d7a70000-0000-4000-8000-000000000005.jpg', 'phong-tuyen-nhu-nguyet.jpg',  'image/jpeg', 879793,  'ACTIVE', 'Phòng tuyến sông Như Nguyệt (Năm 1077)',                  sys_user),
        (asset_dien_bien,  'assets/d7a70000-0000-4000-8000-000000000006.jpg', 'doi-a1-dien-bien-phu.jpg',    'image/jpeg', 1060936, 'ACTIVE', 'Đồi A1 & Lòng chảo Mường Thanh — Điện Biên Phủ (1954)',  sys_user)
    ON CONFLICT (id) DO UPDATE SET
        original_filename = EXCLUDED.original_filename,
        mime_type = EXCLUDED.mime_type,
        size_bytes = EXCLUDED.size_bytes,
        state = EXCLUDED.state,
        alt_text = EXCLUDED.alt_text;

    -- 2. Backfill heritage metadata & cover_asset_id on the 11 existing canonical map_locations
    UPDATE map_locations SET
        slug = 'khu-di-tich-den-hung',
        kind = 'ANCIENT_CAPITAL',
        short_summary = 'Núi Nghĩa Lĩnh, Phong Châu — kinh đô nước Văn Lang thời 18 đời Hùng Vương dựng nước.',
        cover_asset_id = asset_den_hung,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000001';

    UPDATE map_locations SET
        slug = 'lang-co-van-lang-nga-ba-hac',
        kind = 'ARCHAEOLOGICAL_SITE',
        short_summary = 'Nơi hợp lưu sông Hồng, sông Lô và sông Đà — cái nôi văn minh lúa nước Đông Sơn.',
        cover_asset_id = asset_den_hung,
        coordinate_precision = 'APPROXIMATE',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000002';

    UPDATE map_locations SET
        slug = 'ben-bach-dang-tran-dia-coc',
        kind = 'BATTLEFIELD',
        short_summary = 'Cửa sông Bạch Đằng lịch sử — trận địa cọc gỗ bịt sắt của Ngô Quyền năm 938.',
        cover_asset_id = asset_bach_dang,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000003';

    UPDATE map_locations SET
        slug = 'bai-coc-yen-giang-quang-yen',
        kind = 'ARCHAEOLOGICAL_SITE',
        short_summary = 'Chứng tích hàng trăm cọc gỗ lim cắm ngầm dưới lòng sông Bạch Đằng.',
        cover_asset_id = asset_bach_dang,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000004';

    UPDATE map_locations SET
        slug = 'cua-song-nam-trieu',
        kind = 'SCHEMATIC_REGION',
        short_summary = 'Cửa ngõ chiến lược từ biển tiến vào sông Bạch Đằng.',
        cover_asset_id = asset_bach_dang,
        coordinate_precision = 'APPROXIMATE',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000005';

    UPDATE map_locations SET
        slug = 'cua-song-hat-hat-mon',
        kind = 'MEMORIAL',
        short_summary = 'Đền Hát Môn bên cửa sông Hát — nơi Hai Bà Trưng lập đàn tế cờ mùa xuân năm 40.',
        cover_asset_id = asset_me_linh,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = CASE WHEN unlock_lesson_id IS NOT NULL THEN 'ANY' ELSE 'NONE' END
    WHERE id = 'a0000000-0000-0000-0000-000000000006';

    UPDATE map_locations SET
        slug = 'thanh-co-me-linh',
        kind = 'ANCIENT_CAPITAL',
        short_summary = 'Kinh đô Mê Linh của Trưng Nữ Vương sau khi thu phục 65 thành trì Lĩnh Ngoại.',
        cover_asset_id = asset_me_linh,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000007';

    UPDATE map_locations SET
        slug = 'phong-tuyen-song-nhu-nguyet',
        kind = 'BATTLEFIELD',
        short_summary = 'Phòng tuyến lũy tre và thành đất bên bờ sông Cầu chặn đứng 30 vạn quân Tống năm 1077.',
        cover_asset_id = asset_nhu_nguyet,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = CASE WHEN unlock_lesson_id IS NOT NULL THEN 'ANY' ELSE 'NONE' END
    WHERE id = 'a0000000-0000-0000-0000-000000000008';

    UPDATE map_locations SET
        slug = 'den-xa-nam-quoc-son-ha',
        kind = 'MEMORIAL',
        short_summary = 'Đền Trương Hống - Trương Hát bên sông Như Nguyệt nơi vang lên bài thơ thần Nam Quốc Sơn Hà.',
        cover_asset_id = asset_nhu_nguyet,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000009';

    UPDATE map_locations SET
        slug = 'cu-diem-doi-a1-dien-bien-phu',
        kind = 'BATTLEFIELD',
        short_summary = 'Cứ điểm then chốt quyết định thắng lợi Chiến dịch Điện Biên Phủ năm 1954.',
        cover_asset_id = asset_dien_bien,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = CASE WHEN unlock_lesson_id IS NOT NULL THEN 'ANY' ELSE 'NONE' END
    WHERE id = 'a0000000-0000-0000-0000-000000000010';

    UPDATE map_locations SET
        slug = 'ham-tuong-de-castries-muong-thanh',
        kind = 'HERITAGE_SITE',
        short_summary = 'Sở chỉ huy tập đoàn cứ điểm Điện Biên Phủ nơi lá cờ Quyết chiến Quyết thắng tung bay chiều 7/5/1954.',
        cover_asset_id = asset_dien_bien,
        coordinate_precision = 'EXACT',
        visibility = 'ALWAYS_VISIBLE',
        unlock_rule_mode = 'NONE'
    WHERE id = 'a0000000-0000-0000-0000-000000000011';

    -- 3. Insert 12th canonical heritage location: Hoàng thành Thăng Long — Đoan Môn (1010)
    SELECT id INTO evt_thang_long FROM (
        SELECT id, 1 AS p FROM historical_events WHERE slug = 'ly-thai-to-1010'
        UNION ALL
        SELECT id, 2 AS p FROM historical_events WHERE slug = 'history-thang-long-1010'
        ORDER BY p ASC LIMIT 1
    ) sub;

    INSERT INTO map_locations (
        id, event_id, slug, title, short_summary, description,
        kind, latitude, longitude, coordinate_precision, visibility,
        unlock_rule_mode, cover_asset_id, display_order, status, published_at
    ) VALUES (
        loc_thang_long,
        evt_thang_long,
        'hoang-thanh-thang-long',
        'Hoàng Thành Thăng Long — Đoan Môn',
        'Kinh đô Đại Việt từ mùa thu năm Canh Tuất (1010) khi vua Lý Thái Tổ ban Chiếu dời đô.',
        'Trung tâm chính trị, văn hóa của quốc gia Đại Việt suốt hơn một thiên niên kỷ lịch sử từ thời nhà Lý, nhà Trần đến nhà Lê.',
        'ANCIENT_CAPITAL',
        21.0352,
        105.8403,
        'EXACT',
        'ALWAYS_VISIBLE',
        'NONE',
        asset_thang_long,
        1,
        'PUBLISHED',
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        slug = EXCLUDED.slug,
        title = EXCLUDED.title,
        short_summary = EXCLUDED.short_summary,
        description = EXCLUDED.description,
        kind = EXCLUDED.kind,
        cover_asset_id = EXCLUDED.cover_asset_id,
        status = EXCLUDED.status;

    IF evt_thang_long IS NOT NULL THEN
        INSERT INTO map_location_events (location_id, event_id, role, sort_order)
        VALUES (loc_thang_long, evt_thang_long, 'PRIMARY', 1)
        ON CONFLICT (location_id, event_id) DO NOTHING;
    END IF;

    -- 4. Seed rich media (`map_location_media`) for all 12 heritage locations
    --    linking both `asset_id` (backend /api/v1/assets/{id}/content) and `external_url` (/heritage/*.jpg)
    INSERT INTO map_location_media (id, location_id, media_type, title, caption, asset_id, external_url, visibility, sort_order)
    SELECT
        m.id, m.location_id, 'IMAGE_2D', m.title, m.caption, m.asset_id, m.external_url, m.visibility, m.sort_order
    FROM (
        VALUES
            ('d7a80000-0000-4000-8000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'Toàn cảnh Khu di tích Đền Hùng — Núi Nghĩa Lĩnh', 'Đền Hùng trên núi Nghĩa Lĩnh, Phong Châu — trung tâm nước Văn Lang thời các Vua Hùng.', asset_den_hung, '/heritage/den-hung-phong-chau.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid, 'Không gian Văn Lang & Ngã Ba Hạc', 'Vùng hợp lưu ba con sông lớn nơi hình thành nền văn minh lúa nước Đông Sơn.', asset_den_hung, '/heritage/den-hung-phong-chau.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000003'::uuid, 'a0000000-0000-0000-0000-000000000003'::uuid, 'Trận địa cọc Bạch Đằng Giang năm 938', 'Hàng cọc gỗ lim bịt sắt nhô lên giữa sóng nước cửa sông Bạch Đằng khi thủy triều rút.', asset_bach_dang, '/heritage/bai-coc-bach-dang.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000004'::uuid, 'a0000000-0000-0000-0000-000000000004'::uuid, 'Di tích Bãi cọc Yên Giang — Quảng Yên', 'Chứng tích trận địa cọc ngầm được bảo tồn tại vùng cửa sông Bạch Đằng.', asset_bach_dang, '/heritage/bai-coc-bach-dang.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000005'::uuid, 'a0000000-0000-0000-0000-000000000005'::uuid, 'Cửa sông Nam Triệu nhìn về Bạch Đằng Giang', 'Cửa biển chiến lược nơi đoàn thuyền Nam Hán tiến vào trận địa mai phục.', asset_bach_dang, '/heritage/bai-coc-bach-dang.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000006'::uuid, 'a0000000-0000-0000-0000-000000000006'::uuid, 'Hội thề Hát Môn — Khởi nghĩa Hai Bà Trưng năm 40', 'Đoàn voi chiến và cờ đại nghĩa của Hai Bà Trưng bên dòng sông Hát.', asset_me_linh, '/heritage/me-linh-hai-ba-trung.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000007'::uuid, 'a0000000-0000-0000-0000-000000000007'::uuid, 'Thành cổ Mê Linh — Kinh đô Trưng Nữ Vương', 'Trung tâm chỉ huy nghĩa quân Mê Linh thời Hai Bà Trưng dựng nền tự chủ.', asset_me_linh, '/heritage/me-linh-hai-ba-trung.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000008'::uuid, 'a0000000-0000-0000-0000-000000000008'::uuid, 'Phòng tuyến sông Như Nguyệt năm 1077', 'Lũy tre dày và thành đất ven bờ nam sông Cầu của Thái úy Lý Thường Kiệt.', asset_nhu_nguyet, '/heritage/phong-tuyen-nhu-nguyet.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000009'::uuid, 'a0000000-0000-0000-0000-000000000009'::uuid, 'Đền Xà bên bờ sông Như Nguyệt', 'Không gian linh thiêng nơi bài thơ thần Nam Quốc Sơn Hà khích lệ tướng sĩ Đại Việt.', asset_nhu_nguyet, '/heritage/phong-tuyen-nhu-nguyet.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000010'::uuid, 'a0000000-0000-0000-0000-000000000010'::uuid, 'Cứ điểm Đồi A1 — Điện Biên Phủ 1954', 'Ngọn đồi lịch sử nhìn xuống cánh đồng Mường Thanh trong Chiến dịch Điện Biên Phủ.', asset_dien_bien, '/heritage/doi-a1-dien-bien-phu.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000011'::uuid, 'a0000000-0000-0000-0000-000000000011'::uuid, 'Trung tâm Mường Thanh & Hầm De Castries', 'Toàn cảnh lòng chảo Điện Biên Phủ nơi chiến dịch kết thúc thắng lợi ngày 7/5/1954.', asset_dien_bien, '/heritage/doi-a1-dien-bien-phu.jpg', 'PUBLIC_PREVIEW', 0),
            ('d7a80000-0000-4000-8000-000000000012'::uuid, loc_thang_long,                                  'Đoan Môn — Hoàng thành Thăng Long năm 1010', 'Cổng Đoan Môn uy nghiêm của kinh thành Thăng Long thời nhà Lý.', asset_thang_long, '/heritage/hoang-thanh-thang-long.jpg', 'PUBLIC_PREVIEW', 0)
    ) AS m(id, location_id, title, caption, asset_id, external_url, visibility, sort_order)
    WHERE EXISTS (SELECT 1 FROM map_locations loc WHERE loc.id = m.location_id)
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        caption = EXCLUDED.caption,
        asset_id = EXCLUDED.asset_id,
        external_url = EXCLUDED.external_url,
        visibility = EXCLUDED.visibility;
END $$;
