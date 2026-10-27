-- =============================================================================
-- Migration V41: Seed HISTORY_MAIN v2 (Hierarchy ERA -> PERIOD -> Event -> Lesson)
-- Purpose:
--   1. Backfill end_year & date_precision on canonical historical_events.
--   2. Ensure PUBLISHED event_completion_policies exist for all canonical events
--      that have PUBLISHED lessons so they are PLAYABLE on the path.
--   3. Create and publish HISTORY_MAIN version 2 with 4 root ERAs and 5 child
--      PERIODs, attaching all canonical events and all their PUBLISHED lessons.
--   4. Upgrade existing user_learning_path_enrollments to HISTORY_MAIN v2.
-- =============================================================================

DO $$
DECLARE
    v2_id UUID := 'd7e00000-0000-4000-8000-000000000002';

    era1_id UUID := 'd7e20000-0000-4000-8000-000000000001';
    era2_id UUID := 'd7e20000-0000-4000-8000-000000000002';
    era3_id UUID := 'd7e20000-0000-4000-8000-000000000003';
    era4_id UUID := 'd7e20000-0000-4000-8000-000000000004';

    p1_id UUID := 'd7e21000-0000-4000-8000-000000000001';
    p2_id UUID := 'd7e21000-0000-4000-8000-000000000002';
    p3_id UUID := 'd7e21000-0000-4000-8000-000000000003';
    p4_id UUID := 'd7e21000-0000-4000-8000-000000000004';
    p5_id UUID := 'd7e21000-0000-4000-8000-000000000005';

    node_id UUID;
    evt_id UUID;
    les_rec RECORD;
    l_sort INT;
    req_json JSONB;
BEGIN
    -- Idempotency guard: if HISTORY_MAIN v2 already exists, skip.
    IF EXISTS (SELECT 1 FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND version_no = 2) THEN
        RETURN;
    END IF;

    -- 1. Enrich canonical historical_events with end_year and date_precision
    UPDATE historical_events
    SET end_year = -258, date_precision = 'CENTURY'
    WHERE slug = 'hung-vuong-van-lang';

    UPDATE historical_events
    SET end_year = 43, date_precision = 'EXACT'
    WHERE slug IN ('hai-ba-trung-40', 'khoi-nghia-hai-ba-trung-40');

    UPDATE historical_events
    SET end_year = 938, date_precision = 'EXACT'
    WHERE slug = 'bach-dang-938';

    UPDATE historical_events
    SET end_year = 1010, date_precision = 'EXACT'
    WHERE slug IN ('ly-thai-to-1010', 'history-thang-long-1010');

    UPDATE historical_events
    SET end_year = 1077, date_precision = 'EXACT'
    WHERE slug = 'chien-thang-nhu-nguyet-1077';

    UPDATE historical_events
    SET end_year = 1954, date_precision = 'EXACT'
    WHERE slug = 'chien-dich-dien-bien-phu-1954';

    -- 2. Create DRAFT version 2 of HISTORY_MAIN
    INSERT INTO learning_path_versions (
        id, path_code, version_no, title, description, status, published_at, created_at, updated_at
    ) VALUES (
        v2_id,
        'HISTORY_MAIN',
        2,
        'Hành trình Lịch sử Việt Nam',
        'Lộ trình lịch sử Việt Nam phân cấp Đại thời kỳ (ERA) và Thời kỳ (PERIOD), mở khóa tuần tự theo từng thời kỳ',
        'DRAFT',
        NULL,
        now(),
        now()
    );

    -- 3. Insert 4 Root ERA nodes (parent_id = NULL, node_type = 'ERA')
    INSERT INTO learning_path_chapters (
        id, path_version_id, parent_id, node_type, code, title, description,
        start_year, end_year, period_label, sort_order, theme_key
    ) VALUES
    (
        era1_id, v2_id, NULL, 'ERA', 'ERA_ANCIENT',
        'Thời đại Dựng nước',
        'Từ văn minh sông Hồng thời Hùng Vương dựng nước Văn Lang đến nước Âu Lạc.',
        -2879, -179, 'Khoảng TK VII TCN – 179 TCN', 1, 'FOUNDING_ERA'
    ),
    (
        era2_id, v2_id, NULL, 'ERA', 'ERA_NORTHERN_DOMINATION',
        'Thời kỳ Bắc thuộc và Đấu tranh giành độc lập',
        'Hơn một thiên niên kỷ bền bỉ giữ gìn bản sắc và vùng lên khởi nghĩa giành quyền tự chủ.',
        -179, 938, '179 TCN – 938', 2, 'NORTHERN_DOMINATION'
    ),
    (
        era3_id, v2_id, NULL, 'ERA', 'ERA_FEUDAL_INDEPENDENCE',
        'Thời kỳ Phong kiến Độc lập Tự chủ',
        'Kỷ nguyên độc lập tự chủ từ chiến thắng Bạch Đằng năm 938 qua các triều đại Ngô, Đinh, Tiền Lê, Lý, Trần, Lê.',
        938, 1858, '938 – 1858', 3, 'EARLY_INDEPENDENCE'
    ),
    (
        era4_id, v2_id, NULL, 'ERA', 'ERA_MODERN',
        'Thời kỳ Cận - Hiện đại',
        'Đấu tranh bảo vệ Tổ quốc và giành độc lập dân tộc trong thời đại mới.',
        1858, 1975, '1858 – 1975', 4, 'ANTI_FRENCH_RESISTANCE'
    );

    -- 4. Insert 5 Child PERIOD nodes (parent_id = era_id, node_type = 'PERIOD')
    INSERT INTO learning_path_chapters (
        id, path_version_id, parent_id, node_type, code, title, description,
        start_year, end_year, period_label, sort_order, theme_key
    ) VALUES
    (
        p1_id, v2_id, era1_id, 'PERIOD', 'FOUNDING_ERA',
        'Buổi đầu dựng nước',
        'Thời đại Hùng Vương mở nước, văn hóa Đông Sơn và nền văn minh sông Hồng.',
        -700, -179, 'Khoảng thế kỷ VII TCN – năm 179 TCN', 1, 'FOUNDING_ERA'
    ),
    (
        p2_id, v2_id, era2_id, 'PERIOD', 'NORTHERN_DOMINATION',
        'Bắc thuộc và đấu tranh giành độc lập',
        'Hơn một thiên niên kỷ kiên cường bảo tồn văn hóa và bền bỉ đấu tranh chống ách đô hộ phương Bắc.',
        -179, 938, 'Năm 179 TCN – năm 938', 1, 'NORTHERN_DOMINATION'
    ),
    (
        p3_id, v2_id, era3_id, 'PERIOD', 'EARLY_INDEPENDENCE',
        'Buổi đầu độc lập tự chủ',
        'Thời kỳ phục hưng đất nước sau chiến thắng Bạch Đằng, đặt nền móng thể chế quốc gia độc lập.',
        938, 1009, 'Năm 938 – năm 1009', 1, 'EARLY_INDEPENDENCE'
    ),
    (
        p4_id, v2_id, era3_id, 'PERIOD', 'LY_DYNASTY',
        'Thời nhà Lý',
        'Triều đại rực rỡ với quyết định dời đô về Thăng Long và chiến công bảo vệ giang sơn trên sông Như Nguyệt.',
        1009, 1225, 'Năm 1009 – năm 1225', 2, 'LY_DYNASTY'
    ),
    (
        p5_id, v2_id, era4_id, 'PERIOD', 'ANTI_FRENCH_RESISTANCE',
        'Kháng chiến chống thực dân Pháp',
        'Cuộc trường kỳ kháng chiến toàn dân, toàn diện kết thúc bằng chiến thắng Điện Biên Phủ lừng lẫy địa cầu.',
        1945, 1954, 'Năm 1945 – năm 1954', 1, 'ANTI_FRENCH_RESISTANCE'
    );

    -- 5. Attach canonical events and all PUBLISHED lessons to each PERIOD
    -- 5.1 FOUNDING_ERA: hung-vuong-van-lang
    SELECT id INTO evt_id FROM historical_events WHERE slug = 'hung-vuong-van-lang' LIMIT 1;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p1_id, v2_id, evt_id, 1, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    -- 5.2 NORTHERN_DOMINATION: hai-ba-trung-40 / khoi-nghia-hai-ba-trung-40
    SELECT id INTO evt_id FROM (
        SELECT id, 1 AS priority FROM historical_events WHERE slug = 'hai-ba-trung-40'
        UNION ALL
        SELECT id, 2 AS priority FROM historical_events WHERE slug = 'khoi-nghia-hai-ba-trung-40'
        ORDER BY priority ASC LIMIT 1
    ) sub;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p2_id, v2_id, evt_id, 1, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    -- 5.3 EARLY_INDEPENDENCE: bach-dang-938
    SELECT id INTO evt_id FROM historical_events WHERE slug = 'bach-dang-938' LIMIT 1;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p3_id, v2_id, evt_id, 1, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    -- 5.4 LY_DYNASTY: ly-thai-to-1010 & chien-thang-nhu-nguyet-1077
    SELECT id INTO evt_id FROM (
        SELECT id, 1 AS priority FROM historical_events WHERE slug = 'ly-thai-to-1010'
        UNION ALL
        SELECT id, 2 AS priority FROM historical_events WHERE slug = 'history-thang-long-1010'
        ORDER BY priority ASC LIMIT 1
    ) sub;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p4_id, v2_id, evt_id, 1, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    SELECT id INTO evt_id FROM historical_events WHERE slug = 'chien-thang-nhu-nguyet-1077' LIMIT 1;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p4_id, v2_id, evt_id, 2, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    -- 5.5 ANTI_FRENCH_RESISTANCE: chien-dich-dien-bien-phu-1954
    SELECT id INTO evt_id FROM historical_events WHERE slug = 'chien-dich-dien-bien-phu-1954' LIMIT 1;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
        VALUES (node_id, p5_id, v2_id, evt_id, 1, 'REQUIRED');

        l_sort := 1;
        FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' AND current_version_id IS NOT NULL ORDER BY created_at ASC, id ASC LOOP
            INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
            VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
            ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
            l_sort := l_sort + 1;
        END LOOP;
    END IF;

    -- 6. Ensure every event in v2 that has attached lessons has participation_type = 'REQUIRED'
    --    and a PUBLISHED event_completion_policy; events without lessons use 'EXPLORATION_ONLY'
    UPDATE learning_path_event_nodes en
    SET participation_type = 'EXPLORATION_ONLY'
    WHERE en.path_version_id = v2_id
      AND NOT EXISTS (
          SELECT 1 FROM learning_path_lesson_nodes ln WHERE ln.event_node_id = en.id
      );

    FOR les_rec IN
        SELECT en.id AS event_node_id, en.event_id
        FROM learning_path_event_nodes en
        WHERE en.path_version_id = v2_id
    LOOP
        SELECT jsonb_agg(ln.lesson_id::text ORDER BY ln.sort_order ASC)
        INTO req_json
        FROM learning_path_lesson_nodes ln
        WHERE ln.event_node_id = les_rec.event_node_id;

        IF req_json IS NOT NULL AND jsonb_array_length(req_json) > 0 THEN
            IF NOT EXISTS (
                SELECT 1 FROM event_completion_policies
                WHERE event_id = les_rec.event_id AND status = 'PUBLISHED'
            ) THEN
                INSERT INTO event_completion_policies (
                    id, event_id, policy_version, status, required_lesson_ids, mastery_threshold, published_at
                ) VALUES (
                    gen_random_uuid(),
                    les_rec.event_id,
                    COALESCE((SELECT MAX(policy_version) FROM event_completion_policies WHERE event_id = les_rec.event_id), 0) + 1,
                    'PUBLISHED',
                    req_json,
                    70,
                    now()
                );
            END IF;
        END IF;
    END LOOP;

    -- 7. Archive previous PUBLISHED version of HISTORY_MAIN and publish v2
    UPDATE learning_path_versions
    SET status = 'ARCHIVED', updated_at = now()
    WHERE path_code = 'HISTORY_MAIN' AND status = 'PUBLISHED' AND id <> v2_id;

    UPDATE learning_path_versions
    SET status = 'PUBLISHED', published_at = now(), updated_at = now()
    WHERE id = v2_id;

    -- 8. Upgrade existing enrollments to v2
    UPDATE user_learning_path_enrollments
    SET path_version_id = v2_id, updated_at = now()
    WHERE path_code = 'HISTORY_MAIN';
END $$;
