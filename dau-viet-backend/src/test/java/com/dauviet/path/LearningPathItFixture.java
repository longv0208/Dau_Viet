package com.dauviet.path;

import org.springframework.jdbc.core.JdbcTemplate;

public final class LearningPathItFixture {

    private LearningPathItFixture() {}

    public static void ensureDefaultPathSeeded(JdbcTemplate jdbc) {
        Integer count = jdbc.queryForObject(
                "SELECT count(*) FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND status = 'PUBLISHED'",
                Integer.class);
        if (count != null && count > 0) {
            return;
        }

        // Tái tạo seed V1 nếu bảng đã bị clean bởi IT trước
        jdbc.execute("""
            DO $$
            DECLARE
                v_path_id UUID := 'd7e00000-0000-4000-8000-000000000001';
                c1_id UUID := 'd7e10000-0000-4000-8000-000000000001';
                c2_id UUID := 'd7e10000-0000-4000-8000-000000000002';
                c3_id UUID := 'd7e10000-0000-4000-8000-000000000003';
                c4_id UUID := 'd7e10000-0000-4000-8000-000000000004';
                c5_id UUID := 'd7e10000-0000-4000-8000-000000000005';
                node_id UUID;
                evt_id UUID;
                les_rec RECORD;
                l_sort INT;
            BEGIN
                INSERT INTO learning_path_versions (
                    id, path_code, version_no, title, description, status, published_at
                ) VALUES (
                    v_path_id, 'HISTORY_MAIN', 1, 'Hành trình Lịch sử Việt Nam',
                    'Lộ trình học tập lịch sử Việt Nam chuẩn hóa', 'PUBLISHED', now()
                ) ON CONFLICT (path_code, version_no) DO NOTHING;

                SELECT id INTO v_path_id FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND version_no = 1;

                INSERT INTO learning_path_chapters (
                    id, path_version_id, code, title, description, start_year, end_year, period_label, sort_order, theme_key
                ) VALUES
                (c1_id, v_path_id, 'FOUNDING_ERA', 'Buổi đầu dựng nước', 'Thời đại Hùng Vương mở nước', -700, -179, 'Khoảng thế kỷ VII TCN – năm 179 TCN', 1, 'FOUNDING_ERA'),
                (c2_id, v_path_id, 'NORTHERN_DOMINATION', 'Bắc thuộc và đấu tranh giành độc lập', 'Hơn một thiên niên kỷ kiên cường', -179, 938, 'Năm 179 TCN – năm 938', 2, 'NORTHERN_DOMINATION'),
                (c3_id, v_path_id, 'EARLY_INDEPENDENCE', 'Buổi đầu độc lập tự chủ', 'Thời kỳ phục hưng đất nước', 938, 1009, 'Năm 938 – năm 1009', 3, 'EARLY_INDEPENDENCE'),
                (c4_id, v_path_id, 'LY_DYNASTY', 'Thời nhà Lý', 'Triều đại rực rỡ với dời đô Thăng Long', 1009, 1225, 'Năm 1009 – năm 1225', 4, 'LY_DYNASTY'),
                (c5_id, v_path_id, 'ANTI_FRENCH_RESISTANCE', 'Kháng chiến chống thực dân Pháp', 'Chiến thắng Điện Biên Phủ lừng lẫy', 1945, 1954, 'Năm 1945 – năm 1954', 5, 'ANTI_FRENCH_RESISTANCE')
                ON CONFLICT (path_version_id, code) DO NOTHING;

                -- Chương I: Hùng Vương
                SELECT id INTO evt_id FROM historical_events WHERE slug = 'hung-vuong-van-lang' LIMIT 1;
                IF evt_id IS NOT NULL THEN
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (gen_random_uuid(), c1_id, v_path_id, evt_id, 1)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;
                END IF;

                -- Chương II: Hai Bà Trưng (ưu tiên hai-ba-trung-40)
                SELECT id INTO evt_id FROM (
                    SELECT id, 1 as priority FROM historical_events WHERE slug = 'hai-ba-trung-40'
                    UNION ALL
                    SELECT id, 2 as priority FROM historical_events WHERE slug = 'khoi-nghia-hai-ba-trung-40'
                    ORDER BY priority ASC LIMIT 1
                ) sub;
                IF evt_id IS NOT NULL THEN
                    node_id := gen_random_uuid();
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (node_id, c2_id, v_path_id, evt_id, 1)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;

                    SELECT id INTO node_id FROM learning_path_event_nodes WHERE path_version_id = v_path_id AND event_id = evt_id;
                    l_sort := 1;
                    FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' ORDER BY created_at ASC LOOP
                        INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                        VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
                        ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
                        l_sort := l_sort + 1;
                    END LOOP;
                END IF;

                -- Chương III: Bạch Đằng 938
                SELECT id INTO evt_id FROM historical_events WHERE slug = 'bach-dang-938' LIMIT 1;
                IF evt_id IS NOT NULL THEN
                    node_id := gen_random_uuid();
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (node_id, c3_id, v_path_id, evt_id, 1)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;

                    SELECT id INTO node_id FROM learning_path_event_nodes WHERE path_version_id = v_path_id AND event_id = evt_id;
                    l_sort := 1;
                    FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' ORDER BY created_at ASC LOOP
                        INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                        VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
                        ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
                        l_sort := l_sort + 1;
                    END LOOP;
                END IF;

                -- Chương IV: Nhà Lý
                SELECT id INTO evt_id FROM (
                    SELECT id, 1 as priority FROM historical_events WHERE slug = 'ly-thai-to-1010'
                    UNION ALL
                    SELECT id, 2 as priority FROM historical_events WHERE slug = 'history-thang-long-1010'
                    ORDER BY priority ASC LIMIT 1
                ) sub;
                IF evt_id IS NOT NULL THEN
                    node_id := gen_random_uuid();
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (node_id, c4_id, v_path_id, evt_id, 1)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;

                    SELECT id INTO node_id FROM learning_path_event_nodes WHERE path_version_id = v_path_id AND event_id = evt_id;
                    l_sort := 1;
                    FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' ORDER BY created_at ASC LOOP
                        INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                        VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
                        ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
                        l_sort := l_sort + 1;
                    END LOOP;
                END IF;

                SELECT id INTO evt_id FROM historical_events WHERE slug = 'chien-thang-nhu-nguyet-1077' LIMIT 1;
                IF evt_id IS NOT NULL THEN
                    node_id := gen_random_uuid();
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (node_id, c4_id, v_path_id, evt_id, 2)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;

                    SELECT id INTO node_id FROM learning_path_event_nodes WHERE path_version_id = v_path_id AND event_id = evt_id;
                    l_sort := 1;
                    FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' ORDER BY created_at ASC LOOP
                        INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                        VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
                        ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
                        l_sort := l_sort + 1;
                    END LOOP;
                END IF;

                -- Chương V: Điện Biên Phủ 1954
                SELECT id INTO evt_id FROM historical_events WHERE slug = 'chien-dich-dien-bien-phu-1954' LIMIT 1;
                IF evt_id IS NOT NULL THEN
                    node_id := gen_random_uuid();
                    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
                    VALUES (node_id, c5_id, v_path_id, evt_id, 1)
                    ON CONFLICT (path_version_id, event_id) DO NOTHING;

                    SELECT id INTO node_id FROM learning_path_event_nodes WHERE path_version_id = v_path_id AND event_id = evt_id;
                    l_sort := 1;
                    FOR les_rec IN SELECT id FROM lessons WHERE event_id = evt_id AND status = 'PUBLISHED' ORDER BY created_at ASC LOOP
                        INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                        VALUES (gen_random_uuid(), node_id, evt_id, les_rec.id, l_sort)
                        ON CONFLICT (event_node_id, lesson_id) DO NOTHING;
                        l_sort := l_sort + 1;
                    END LOOP;
                END IF;

            END $$;
        """);
    }
}
