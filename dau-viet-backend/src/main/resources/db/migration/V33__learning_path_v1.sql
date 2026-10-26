-- Dấu Việt | V33 | Learning Path Foundation 2.0 (PATH-01)
-- Lộ trình học tập lịch sử Việt Nam duy nhất: Chương -> Sự kiện -> Bài học
-- Idempotent, immutable published version, không sửa schema bảng cũ.

-- ============================================================================
-- 1. LEARNING PATH VERSIONS
-- ============================================================================
CREATE TABLE learning_path_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_code VARCHAR(64) NOT NULL,
    version_no INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_path_version_status CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    CONSTRAINT ux_learning_path_code_version UNIQUE (path_code, version_no)
);

-- Tối đa 1 phiên bản PUBLISHED hiện hành trên mỗi path_code
CREATE UNIQUE INDEX ux_learning_path_active_published
    ON learning_path_versions (path_code)
    WHERE status = 'PUBLISHED';

CREATE INDEX idx_learning_path_versions_lookup
    ON learning_path_versions (path_code, status);

-- ============================================================================
-- 2. LEARNING PATH CHAPTERS
-- ============================================================================
CREATE TABLE learning_path_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path_version_id UUID NOT NULL REFERENCES learning_path_versions(id) ON DELETE CASCADE,
    code VARCHAR(64) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    start_year INTEGER NOT NULL,
    end_year INTEGER NOT NULL,
    period_label VARCHAR(120) NOT NULL,
    sort_order INTEGER NOT NULL,
    theme_key VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_learning_path_chapter_years CHECK (start_year <= end_year),
    CONSTRAINT ux_path_chapter_version_code UNIQUE (path_version_id, code),
    CONSTRAINT ux_path_chapter_version_sort UNIQUE (path_version_id, sort_order),
    CONSTRAINT ux_path_chapter_id_version UNIQUE (id, path_version_id)
);

CREATE INDEX idx_path_chapters_version_sort
    ON learning_path_chapters (path_version_id, sort_order);

-- ============================================================================
-- 3. LEARNING PATH EVENT NODES
-- ============================================================================
CREATE TABLE learning_path_event_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL,
    path_version_id UUID NOT NULL,
    event_id UUID NOT NULL REFERENCES historical_events(id) ON DELETE CASCADE,
    sort_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_path_event_node_chapter FOREIGN KEY (chapter_id, path_version_id)
        REFERENCES learning_path_chapters(id, path_version_id) ON DELETE CASCADE,
    CONSTRAINT ux_path_event_node_unique_event UNIQUE (path_version_id, event_id),
    CONSTRAINT ux_path_event_node_chapter_sort UNIQUE (chapter_id, sort_order),
    CONSTRAINT ux_path_event_node_id_event UNIQUE (id, event_id)
);

CREATE INDEX idx_path_event_nodes_chapter_sort
    ON learning_path_event_nodes (chapter_id, sort_order);

-- ============================================================================
-- 4. LEARNING PATH LESSON NODES
-- ============================================================================
CREATE TABLE learning_path_lesson_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_node_id UUID NOT NULL,
    event_id UUID NOT NULL,
    lesson_id UUID NOT NULL,
    sort_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_path_lesson_node_event_node FOREIGN KEY (event_node_id, event_id)
        REFERENCES learning_path_event_nodes(id, event_id) ON DELETE CASCADE,
    CONSTRAINT fk_path_lesson_node_lesson FOREIGN KEY (event_id, lesson_id)
        REFERENCES lessons(event_id, id) ON DELETE CASCADE,
    CONSTRAINT ux_path_lesson_node_unique_lesson UNIQUE (event_node_id, lesson_id),
    CONSTRAINT ux_path_lesson_node_sort UNIQUE (event_node_id, sort_order)
);

CREATE INDEX idx_path_lesson_nodes_event_sort
    ON learning_path_lesson_nodes (event_node_id, sort_order);

-- ============================================================================
-- 5. IMMUTABILITY TRIGGER FOR PUBLISHED PATHS
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_published_path_version_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'PUBLISHED' THEN
        -- Cho phép chuyển sang ARCHIVED khi có version mới publish
        IF NEW.status = 'ARCHIVED' AND OLD.path_code = NEW.path_code AND OLD.version_no = NEW.version_no THEN
            RETURN NEW;
        END IF;
        -- Cho phép chạm updated_at nếu không đổi nội dung
        IF OLD.title = NEW.title AND OLD.description IS NOT DISTINCT FROM NEW.description
           AND OLD.path_code = NEW.path_code AND OLD.version_no = NEW.version_no THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'learning_path_versions row in PUBLISHED status is immutable; publish a new version instead';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_learning_path_version_immutable
    BEFORE UPDATE ON learning_path_versions
    FOR EACH ROW EXECUTE FUNCTION prevent_published_path_version_mutation();

-- ============================================================================
-- 6. SEED V1 LEARNING PATH (HISTORY_MAIN)
-- ============================================================================
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
    -- 6.1 Path Version 1
    INSERT INTO learning_path_versions (
        id, path_code, version_no, title, description, status, published_at, created_at, updated_at
    ) VALUES (
        v_path_id,
        'HISTORY_MAIN',
        1,
        'Hành trình Lịch sử Việt Nam',
        'Lộ trình học tập lịch sử Việt Nam chuẩn hóa: từ buổi đầu dựng nước tới thời đại Hồ Chí Minh',
        'PUBLISHED',
        now(),
        now(),
        now()
    ) ON CONFLICT (path_code, version_no) DO NOTHING;

    -- Lấy ID thật của version nếu đã tồn tại
    SELECT id INTO v_path_id FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND version_no = 1;

    -- 6.2 5 Chương lịch sử
    INSERT INTO learning_path_chapters (
        id, path_version_id, code, title, description, start_year, end_year, period_label, sort_order, theme_key
    ) VALUES
    (
        c1_id, v_path_id, 'FOUNDING_ERA',
        'Buổi đầu dựng nước',
        'Thời đại Hùng Vương mở nước, văn hóa Đông Sơn và nền văn minh sông Hồng.',
        -700, -179, 'Khoảng thế kỷ VII TCN – năm 179 TCN', 1, 'FOUNDING_ERA'
    ),
    (
        c2_id, v_path_id, 'NORTHERN_DOMINATION',
        'Bắc thuộc và đấu tranh giành độc lập',
        'Hơn một thiên niên kỷ kiên cường bảo tồn văn hóa và bền bỉ đấu tranh chống ách đô hộ phương Bắc.',
        -179, 938, 'Năm 179 TCN – năm 938', 2, 'NORTHERN_DOMINATION'
    ),
    (
        c3_id, v_path_id, 'EARLY_INDEPENDENCE',
        'Buổi đầu độc lập tự chủ',
        'Thời kỳ phục hưng đất nước sau chiến thắng Bạch Đằng, đặt nền móng thể chế quốc gia độc lập.',
        938, 1009, 'Năm 938 – năm 1009', 3, 'EARLY_INDEPENDENCE'
    ),
    (
        c4_id, v_path_id, 'LY_DYNASTY',
        'Thời nhà Lý',
        'Triều đại rực rỡ với quyết định dời đô về Thăng Long và chiến công bảo vệ giang sơn trên sông Như Nguyệt.',
        1009, 1225, 'Năm 1009 – năm 1225', 4, 'LY_DYNASTY'
    ),
    (
        c5_id, v_path_id, 'ANTI_FRENCH_RESISTANCE',
        'Kháng chiến chống thực dân Pháp',
        'Cuộc trường kỳ kháng chiến toàn dân, toàn diện kết thúc bằng chiến thắng Điện Biên Phủ lừng lẫy địa cầu.',
        1945, 1954, 'Năm 1945 – năm 1954', 5, 'ANTI_FRENCH_RESISTANCE'
    ) ON CONFLICT (path_version_id, code) DO NOTHING;

    -- 6.3 Gắn sự kiện & bài học vào từng chương

    -- Chương I: Hùng Vương / Văn Lang
    SELECT id INTO evt_id FROM historical_events WHERE slug = 'hung-vuong-van-lang' LIMIT 1;
    IF evt_id IS NOT NULL THEN
        node_id := gen_random_uuid();
        INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
        VALUES (node_id, c1_id, v_path_id, evt_id, 1)
        ON CONFLICT (path_version_id, event_id) DO NOTHING;
    END IF;

    -- Chương II: Khởi nghĩa Hai Bà Trưng (chọn canonical: ưu tiên hai-ba-trung-40, fallback khoi-nghia-hai-ba-trung-40)
    SELECT id INTO evt_id FROM (
        SELECT id, 1 as priority FROM historical_events WHERE slug = 'hai-ba-trung-40'
        UNION ALL
        SELECT id, 2 as priority FROM historical_events WHERE slug = 'khoi-nghia-hai-ba-trung-40'
        ORDER BY priority ASC
        LIMIT 1
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

    -- Chương III: Đại Chiến Bạch Đằng 938
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

    -- Chương IV: Thời nhà Lý
    -- 4.1 Lý Thái Tổ dời đô (ưu tiên ly-thai-to-1010, fallback history-thang-long-1010)
    SELECT id INTO evt_id FROM (
        SELECT id, 1 as priority FROM historical_events WHERE slug = 'ly-thai-to-1010'
        UNION ALL
        SELECT id, 2 as priority FROM historical_events WHERE slug = 'history-thang-long-1010'
        ORDER BY priority ASC
        LIMIT 1
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

    -- 4.2 Chiến Thắng Như Nguyệt 1077
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

    -- Chương V: Chiến Dịch Điện Biên Phủ 1954
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
