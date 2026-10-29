-- =============================================================================
-- Migration V49: Seed Cover Assets for All Published Lessons & Historical Evidences
-- Purpose:
--   1. Register 5 additional historical illustrations in `assets`
--      (d7a70000-0000-4000-8000-000000000007 .. 000000000011) and fix
--      storage_key on d7a70000-0000-4000-8000-000000000001..000000000006.
--   2. Populate `lessons.cover_asset_id` for all published lessons (matched by
--      lesson ID, title, or parent historical_event slug) so LessonListSection
--      and LessonEntryScreen always receive a valid learner-accessible cover image.
--   3. Populate `evidences.asset_id` for historical evidences where null.
-- =============================================================================

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    asset_den_hung       UUID := 'd7a70000-0000-4000-8000-000000000001';
    asset_me_linh        UUID := 'd7a70000-0000-4000-8000-000000000002';
    asset_bach_dang_coc  UUID := 'd7a70000-0000-4000-8000-000000000003';
    asset_thang_long     UUID := 'd7a70000-0000-4000-8000-000000000004';
    asset_nhu_nguyet     UUID := 'd7a70000-0000-4000-8000-000000000005';
    asset_dien_bien      UUID := 'd7a70000-0000-4000-8000-000000000006';
    asset_dong_son_life  UUID := 'd7a70000-0000-4000-8000-000000000007';
    asset_tran_dia_coc   UUID := 'd7a70000-0000-4000-8000-000000000008';
    asset_doanh_trai     UUID := 'd7a70000-0000-4000-8000-000000000009';
    asset_thu_phong      UUID := 'd7a70000-0000-4000-8000-000000000010';
    asset_ngoquyen_hero  UUID := 'd7a70000-0000-4000-8000-000000000011';
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- 1. Register / sync all 11 historical illustration assets in `assets`
    INSERT INTO assets (id, storage_key, original_filename, mime_type, size_bytes, state, alt_text, created_by)
    VALUES
        (asset_den_hung,      'assets/d7a70000-0000-4000-8000-000000000001.jpg', 'den-hung-phong-chau.jpg',              'image/jpeg', 972231,  'ACTIVE', 'Khu di tích Đền Hùng — Phong Châu (Văn Lang)',                     sys_user),
        (asset_me_linh,       'assets/d7a70000-0000-4000-8000-000000000002.jpg', 'me-linh-hai-ba-trung.jpg',             'image/jpeg', 1100342, 'ACTIVE', 'Thành cổ Mê Linh — Đền Hai Bà Trưng (Năm 40)',                     sys_user),
        (asset_bach_dang_coc, 'assets/d7a70000-0000-4000-8000-000000000003.jpg', 'bai-coc-bach-dang.jpg',                'image/jpeg', 991583,  'ACTIVE', 'Bãi cọc Bạch Đằng Giang (Năm 938)',                                sys_user),
        (asset_thang_long,    'assets/d7a70000-0000-4000-8000-000000000004.jpg', 'hoang-thanh-thang-long.jpg',           'image/jpeg', 1105552, 'ACTIVE', 'Hoàng thành Thăng Long — Đoan Môn (Năm 1010)',                     sys_user),
        (asset_nhu_nguyet,    'assets/d7a70000-0000-4000-8000-000000000005.jpg', 'phong-tuyen-nhu-nguyet.jpg',           'image/jpeg', 879793,  'ACTIVE', 'Phòng tuyến sông Như Nguyệt (Năm 1077)',                           sys_user),
        (asset_dien_bien,     'assets/d7a70000-0000-4000-8000-000000000006.jpg', 'doi-a1-dien-bien-phu.jpg',             'image/jpeg', 1060936, 'ACTIVE', 'Đồi A1 & Lòng chảo Mường Thanh — Điện Biên Phủ (1954)',           sys_user),
        (asset_dong_son_life, 'assets/d7a70000-0000-4000-8000-000000000007.jpg', 'lesson_scene_hung_kings_life.jpg',     'image/jpeg', 1246222, 'ACTIVE', 'Đời sống cư dân Văn Lang — Văn hóa Đông Sơn',                      sys_user),
        (asset_tran_dia_coc,  'assets/d7a70000-0000-4000-8000-000000000008.jpg', 'bg_story_tran_dia.jpg',                'image/jpeg', 924937,  'ACTIVE', 'Quân sĩ Đại Việt đóng cọc gỗ dưới lòng sông Bạch Đằng',           sys_user),
        (asset_doanh_trai,    'assets/d7a70000-0000-4000-8000-000000000009.jpg', 'bg_story_doanh_trai.jpg',              'image/jpeg', 990948,  'ACTIVE', 'Hội bàn quân cơ trong doanh trại tướng sĩ Đại Việt',              sys_user),
        (asset_thu_phong,     'assets/d7a70000-0000-4000-8000-000000000010.jpg', 'bg_story_thu_phong.jpg',               'image/jpeg', 1021000, 'ACTIVE', 'Thư phòng khảo cứu cổ thư và di sản lịch sử Việt Nam',            sys_user),
        (asset_ngoquyen_hero, 'assets/d7a70000-0000-4000-8000-000000000011.jpg', 'dv_EVT_ngoquyen_bachdang_hero_v01.jpg','image/jpeg', 1164505, 'ACTIVE', 'Ngô Quyền chỉ huy đại chiến trên sông Bạch Đằng năm 938',          sys_user)
    ON CONFLICT (id) DO UPDATE SET
        storage_key       = EXCLUDED.storage_key,
        original_filename = EXCLUDED.original_filename,
        mime_type         = EXCLUDED.mime_type,
        size_bytes        = EXCLUDED.size_bytes,
        state             = EXCLUDED.state,
        alt_text          = EXCLUDED.alt_text;

    -- 2. Assign thematic cover_asset_id to all lessons based on event slug & lesson title
    UPDATE lessons l
    SET cover_asset_id = CASE
        -- Hai Bà Trưng & Bà Triệu
        WHEN e.slug IN ('khoi-nghia-hai-ba-trung-40', 'hai-ba-trung-40') THEN asset_me_linh
        WHEN e.slug = 'history-ba-trieu' AND LOWER(l.title) LIKE '%so sánh%' THEN asset_doanh_trai
        WHEN e.slug = 'history-ba-trieu' THEN asset_me_linh

        -- Hùng Vương & Văn hóa Đông Sơn
        WHEN e.slug = 'hung-vuong-van-lang' THEN asset_den_hung
        WHEN e.slug = 'history-dong-son' AND LOWER(l.title) LIKE '%trống đồng%' THEN asset_den_hung
        WHEN e.slug = 'history-dong-son' THEN asset_dong_son_life

        -- Lý Bí & Nước Vạn Xuân
        WHEN e.slug = 'history-ly-bi' AND LOWER(l.title) LIKE '%vạn xuân%' THEN asset_thang_long
        WHEN e.slug = 'history-ly-bi' THEN asset_doanh_trai

        -- Bạch Đằng 938 & 1288
        WHEN e.slug = 'bach-dang-938' THEN asset_ngoquyen_hero
        WHEN e.slug = 'history-bach-dang-1288' AND LOWER(l.title) LIKE '%cọc%' THEN asset_tran_dia_coc
        WHEN e.slug = 'history-bach-dang-1288' THEN asset_bach_dang_coc

        -- Thăng Long 1010
        WHEN e.slug IN ('history-thang-long-1010', 'ly-thai-to-1010') AND LOWER(l.title) LIKE '%dời đô%' THEN asset_thang_long
        WHEN e.slug IN ('history-thang-long-1010', 'ly-thai-to-1010') THEN asset_thu_phong

        -- Sông Như Nguyệt 1077
        WHEN e.slug = 'chien-thang-nhu-nguyet-1077' THEN asset_nhu_nguyet

        -- Thành nhà Hồ, Mỹ Sơn, Hội An, Kinh thành Huế
        WHEN e.slug = 'history-thanh-nha-ho' AND LOWER(l.title) LIKE '%kỹ thuật%' THEN asset_thu_phong
        WHEN e.slug = 'history-thanh-nha-ho' THEN asset_thang_long
        WHEN e.slug = 'history-my-son' AND LOWER(l.title) LIKE '%giao lưu%' THEN asset_thu_phong
        WHEN e.slug = 'history-my-son' THEN asset_den_hung
        WHEN e.slug = 'history-hoi-an' THEN asset_thu_phong
        WHEN e.slug = 'history-kinh-thanh-hue' AND LOWER(l.title) LIKE '%nghi lễ%' THEN asset_thu_phong
        WHEN e.slug = 'history-kinh-thanh-hue' THEN asset_thang_long

        -- Điện Biên Phủ 1954
        WHEN e.slug = 'chien-dich-dien-bien-phu-1954' THEN asset_dien_bien

        ELSE asset_den_hung
    END
    FROM historical_events e
    WHERE l.event_id = e.id
      AND l.cover_asset_id IS NULL;

    -- 3. Populate evidences.asset_id where null so evidence cards also display thematic artwork
    UPDATE evidences ev
    SET asset_id = CASE
        WHEN e.slug IN ('khoi-nghia-hai-ba-trung-40', 'hai-ba-trung-40', 'history-ba-trieu') THEN asset_me_linh
        WHEN e.slug IN ('hung-vuong-van-lang', 'history-dong-son') THEN asset_dong_son_life
        WHEN e.slug = 'history-ly-bi' THEN asset_doanh_trai
        WHEN e.slug = 'bach-dang-938' THEN asset_bach_dang_coc
        WHEN e.slug = 'history-bach-dang-1288' THEN asset_tran_dia_coc
        WHEN e.slug IN ('history-thang-long-1010', 'ly-thai-to-1010', 'history-thanh-nha-ho', 'history-kinh-thanh-hue') THEN asset_thang_long
        WHEN e.slug = 'chien-thang-nhu-nguyet-1077' THEN asset_nhu_nguyet
        WHEN e.slug = 'chien-dich-dien-bien-phu-1954' THEN asset_dien_bien
        ELSE asset_thu_phong
    END
    FROM historical_events e
    WHERE ev.event_id = e.id
      AND ev.asset_id IS NULL;
END $$;
