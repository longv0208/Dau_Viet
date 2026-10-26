package com.dauviet.path;

import org.springframework.jdbc.core.JdbcTemplate;

public final class LearningPathItFixture {

    private LearningPathItFixture() {}

    public static void ensureDefaultPathSeeded(JdbcTemplate jdbc) {
        Integer eventNodeCount = jdbc.queryForObject(
                """
                SELECT count(en.id)
                FROM learning_path_event_nodes en
                JOIN learning_path_versions v ON v.id = en.path_version_id
                WHERE v.path_code = 'HISTORY_MAIN' AND v.version_no = 1
                """,
                Integer.class);

        Integer canonicalEventsCount = jdbc.queryForObject(
                """
                SELECT count(*)
                FROM historical_events
                WHERE slug IN (
                    'hung-vuong-van-lang',
                    'hai-ba-trung-40',
                    'bach-dang-938',
                    'ly-thai-to-1010',
                    'chien-thang-nhu-nguyet-1077',
                    'chien-dich-dien-bien-phu-1954'
                ) AND status = 'PUBLISHED'
                """,
                Integer.class);

        if (eventNodeCount != null && eventNodeCount >= 6 && canonicalEventsCount != null && canonicalEventsCount >= 6) {
            return;
        }

        // Tái tạo đầy đủ dữ liệu seed chuẩn cho 5 chương, 6 sự kiện canonical và lesson/policy
        jdbc.execute("""
            DO $$
            DECLARE
                v_path_id UUID := 'd7e00000-0000-4000-8000-000000000001';
                c1_id UUID := 'd7e10000-0000-4000-8000-000000000001';
                c2_id UUID := 'd7e10000-0000-4000-8000-000000000002';
                c3_id UUID := 'd7e10000-0000-4000-8000-000000000003';
                c4_id UUID := 'd7e10000-0000-4000-8000-000000000004';
                c5_id UUID := 'd7e10000-0000-4000-8000-000000000005';

                evt_hv UUID := '00000000-0000-0000-0000-000000000005';
                evt_hb UUID := '00000000-0000-0000-0000-000000000002';
                evt_bd UUID := '00000000-0000-0000-0000-000000000001';
                evt_lt UUID := 'd7b00000-0000-4000-8000-000000000003';
                evt_nn UUID := '00000000-0000-0000-0000-000000000004';
                evt_db UUID := '00000000-0000-0000-0000-000000000006';

                tpl_id UUID := 'd7a00000-0000-4000-8000-000000000001';
                les_bd UUID := '10000000-0000-0000-0000-000000000001';
                ver_bd UUID := '10000000-0000-0000-0000-000000000011';
                node_id UUID;
            BEGIN
                -- Bật chế độ replica để cấu hình fixture không bị chặn bởi immutability triggers
                SET session_replication_role = replica;

                -- 1. Lesson Template nếu chưa có
                INSERT INTO lesson_templates (id, code, name, description, preset_json)
                VALUES (tpl_id, 'HISTORY_DEFAULT', 'Mẫu bài học lịch sử mặc định', 'Cấu trúc bài học chuẩn 4 chặng',
                        '{"schemaVersion": 1, "stages": []}'::jsonb)
                ON CONFLICT (code) DO NOTHING;

                -- 2. 6 Canonical Historical Events
                -- 2.1 Hùng Vương - Văn Lang (-700)
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_hv, 'hung-vuong-van-lang', 'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
                    'Thời Hùng Vương - Văn Lang (~2879 - 258 TCN)', 'Khoảng thế kỷ VII TCN', -700,
                    'Thời kỳ dựng nước đầu tiên của dân tộc Việt Nam với 18 đời vua Hùng.',
                    'Thời đại mở nước Văn Lang.', 'Phú Thọ', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 2.2 Hai Bà Trưng (40)
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_hb, 'hai-ba-trung-40', 'Khởi nghĩa Hai Bà Trưng năm 40',
                    'Bắc thuộc lần I', 'Hai Bà Trưng', 40,
                    'Cuộc khởi nghĩa của Hai Bà Trưng đập tan ách thống trị của nhà Đông Hán.',
                    'Mê Linh phất cờ khởi nghĩa.', 'Mê Linh, Hà Nội', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 2.3 Bạch Đằng 938
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_bd, 'bach-dang-938', 'Đại Chiến Bạch Đằng 938',
                    'Thời Ngô - Đinh - Tiền Lê (938 - 1009)', 'Mùa Đông 938 SCN', 938,
                    'Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt tiêu diệt thủy quân Nam Hán.',
                    'Ngô Quyền đánh tan quân Nam Hán.', 'Sông Bạch Đằng', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 2.4 Lý Thái Tổ 1010
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_lt, 'ly-thai-to-1010', 'Định đô Thăng Long năm 1010',
                    'Thời nhà Lý', 'Lý Thái Tổ', 1010,
                    'Lý Thái Tổ dời đô từ Hoa Lư về Đại La và đổi tên thành Thăng Long.',
                    'Dời đô Thăng Long.', 'Hà Nội', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 2.5 Chiến Thắng Như Nguyệt 1077
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_nn, 'chien-thang-nhu-nguyet-1077', 'Chiến Thắng Như Nguyệt 1077',
                    'Thời nhà Lý', 'Mùa Xuân 1077', 1077,
                    'Lý Thường Kiệt lãnh đạo kháng chiến chống Tống trên phòng tuyến sông Như Nguyệt.',
                    'Nam quốc sơn hà.', 'Sông Như Nguyệt', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 2.6 Chiến Dịch Điện Biên Phủ 1954
                INSERT INTO historical_events (
                    id, slug, title, era, period, start_year, summary, description, location, status
                ) VALUES (
                    evt_db, 'chien-dich-dien-bien-phu-1954', 'Chiến Dịch Điện Biên Phủ 1954',
                    'Thời đại Hồ Chí Minh', 'Năm 1954', 1954,
                    'Chiến thắng lừng lẫy năm châu, chấn động địa cầu chấm dứt ách thống trị thực dân Pháp.',
                    'Điện Biên Phủ.', 'Điện Biên', 'PUBLISHED'
                ) ON CONFLICT (id) DO UPDATE SET
                    slug = EXCLUDED.slug, title = EXCLUDED.title, start_year = EXCLUDED.start_year,
                    period = EXCLUDED.period, status = 'PUBLISHED';

                -- 3. Lessons & Versions cho Bạch Đằng 938
                INSERT INTO lessons (
                    id, event_id, template_id, title, central_question, objectives_json,
                    draft_json, status, current_version_id
                ) VALUES (
                    les_bd, evt_bd, tpl_id, 'Trận Bạch Đằng năm 938',
                    'Vì sao Ngô Quyền chọn sông Bạch Đằng làm trận địa quyết định?',
                    '["Hiểu cơ chế thủy triều", "Phân tích trận địa cọc"]'::jsonb,
                    '{"schemaVersion": 1, "stages": []}'::jsonb,
                    'PUBLISHED', ver_bd
                ) ON CONFLICT (id) DO UPDATE SET
                    event_id = EXCLUDED.event_id, status = 'PUBLISHED', current_version_id = ver_bd;

                INSERT INTO lesson_versions (
                    id, lesson_id, version_no, content_json, status, published_at
                ) VALUES (
                    ver_bd, les_bd, 1,
                    '{"schemaVersion": 1, "stages": []}'::jsonb,
                    'PUBLISHED', now()
                ) ON CONFLICT (lesson_id, version_no) DO UPDATE SET
                    status = 'PUBLISHED';

                -- 4. Policy cho Bạch Đằng 938
                INSERT INTO event_completion_policies (
                    id, event_id, policy_version, status, required_lesson_ids, mastery_threshold, published_at
                ) VALUES (
                    gen_random_uuid(), evt_bd, 1, 'PUBLISHED',
                    jsonb_build_array(les_bd::text), 70, now()
                ) ON CONFLICT DO NOTHING;

                -- 5. Learning Path Version
                INSERT INTO learning_path_versions (
                    id, path_code, version_no, title, description, status, published_at
                ) VALUES (
                    v_path_id, 'HISTORY_MAIN', 1, 'Hành trình Lịch sử Việt Nam',
                    'Lộ trình học tập lịch sử Việt Nam chuẩn hóa', 'PUBLISHED', now()
                ) ON CONFLICT (path_code, version_no) DO UPDATE SET
                    title = EXCLUDED.title, status = 'PUBLISHED';

                -- 6. 5 Chapters
                INSERT INTO learning_path_chapters (
                    id, path_version_id, code, title, description, start_year, end_year, period_label, sort_order, theme_key
                ) VALUES
                (c1_id, v_path_id, 'FOUNDING_ERA', 'Buổi đầu dựng nước', 'Thời đại Hùng Vương mở nước', -700, -179, 'Khoảng thế kỷ VII TCN – năm 179 TCN', 1, 'FOUNDING_ERA'),
                (c2_id, v_path_id, 'NORTHERN_DOMINATION', 'Bắc thuộc và đấu tranh giành độc lập', 'Hơn một thiên niên kỷ kiên cường', -179, 938, 'Năm 179 TCN – năm 938', 2, 'NORTHERN_DOMINATION'),
                (c3_id, v_path_id, 'EARLY_INDEPENDENCE', 'Buổi đầu độc lập tự chủ', 'Thời kỳ phục hưng đất nước', 938, 1009, 'Năm 938 – năm 1009', 3, 'EARLY_INDEPENDENCE'),
                (c4_id, v_path_id, 'LY_DYNASTY', 'Thời nhà Lý', 'Triều đại rực rỡ với dời đô Thăng Long', 1009, 1225, 'Năm 1009 – năm 1225', 4, 'LY_DYNASTY'),
                (c5_id, v_path_id, 'ANTI_FRENCH_RESISTANCE', 'Kháng chiến chống thực dân Pháp', 'Chiến thắng Điện Biên Phủ lừng lẫy', 1945, 1954, 'Năm 1945 – năm 1954', 5, 'ANTI_FRENCH_RESISTANCE')
                ON CONFLICT (path_version_id, code) DO UPDATE SET
                    start_year = EXCLUDED.start_year, end_year = EXCLUDED.end_year, sort_order = EXCLUDED.sort_order;

                -- 7. Event Nodes
                -- Xoá các event node cũ của version để tái tạo thứ tự sạch sẽ và nhất quán
                DELETE FROM learning_path_event_nodes WHERE path_version_id = v_path_id;

                -- Chapter 1: Hùng Vương (sort_order = 1)
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (gen_random_uuid(), c1_id, v_path_id, evt_hv, 1);

                -- Chapter 2: Hai Bà Trưng (sort_order = 1) - DUY NHẤT 1 NODE
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (gen_random_uuid(), c2_id, v_path_id, evt_hb, 1);

                -- Chapter 3: Bạch Đằng 938 (sort_order = 1)
                node_id := gen_random_uuid();
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (node_id, c3_id, v_path_id, evt_bd, 1);

                -- Gắn lesson cho Bạch Đằng 938 với sort_order = 1 tường minh
                INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                VALUES (gen_random_uuid(), node_id, evt_bd, les_bd, 1);

                -- Chapter 4: Nhà Lý (Lý Thái Tổ sort_order = 1, Như Nguyệt sort_order = 2)
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (gen_random_uuid(), c4_id, v_path_id, evt_lt, 1);

                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (gen_random_uuid(), c4_id, v_path_id, evt_nn, 2);

                -- Chapter 5: Điện Biên Phủ 1954 (sort_order = 1)
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                VALUES (gen_random_uuid(), c5_id, v_path_id, evt_db, 1);

                -- Trả lại chế độ origin
                SET session_replication_role = origin;
            END $$;
        """);
    }
}
