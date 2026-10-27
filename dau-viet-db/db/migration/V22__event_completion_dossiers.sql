-- Dấu Việt | V22 | GAME-04 Event completion policy + historical dossier collection.
-- Schema theo GAMIFICATION_TECHNICAL_CONTRACT §2.4 / §8 / §9 — 5 bảng mới,
-- không đụng bảng cũ. Seed idempotent: events resolve theo slug (giống V20),
-- mọi INSERT ON CONFLICT DO NOTHING, không có user grant nào được gieo.

-- ================= event_completion_policies =================
-- Policy có version cho mỗi event; PUBLISHED là immutable (lesson set +
-- threshold đóng băng tại publish). Thay đổi = policy_version+1.
CREATE TABLE event_completion_policies (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES historical_events(id),
    policy_version INTEGER NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
    required_lesson_ids JSONB NOT NULL,
    optional_lesson_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- smallint để giữ CHECK 0..100; null = event không xét mastered.
    mastery_threshold SMALLINT DEFAULT 70,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_policy_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_policy_threshold CHECK (
        mastery_threshold IS NULL OR mastery_threshold BETWEEN 0 AND 100),
    CONSTRAINT chk_policy_required CHECK (jsonb_typeof(required_lesson_ids) = 'array'),
    CONSTRAINT chk_policy_optional CHECK (jsonb_typeof(optional_lesson_ids) = 'array'),
    CONSTRAINT ux_event_policy_version UNIQUE (event_id, policy_version)
);
-- Tối đa 1 policy PUBLISHED mỗi event (EVT-01).
CREATE UNIQUE INDEX ux_event_policy_published
    ON event_completion_policies(event_id) WHERE status = 'PUBLISHED';
CREATE INDEX idx_event_policy_event ON event_completion_policies(event_id);

-- ================= user_event_progress =================
-- Ledger append-only: một row mỗi (user, event, milestone) — EVT-04/EVT-06.
-- required_snapshot lưu danh sách lesson required tại thời điểm ghi để
-- audit khi admin đổi policy (entitlement không thu hồi, EVT-05).
CREATE TABLE user_event_progress (
    user_id UUID NOT NULL REFERENCES users(id),
    event_id UUID NOT NULL REFERENCES historical_events(id),
    milestone VARCHAR(24) NOT NULL,
    policy_version INTEGER NOT NULL,
    required_snapshot JSONB NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_user_event_milestone CHECK (
        milestone IN ('EVENT_COMPLETED','EVENT_MASTERED')),
    CONSTRAINT chk_user_event_snapshot CHECK (
        jsonb_typeof(required_snapshot) = 'array'),
    CONSTRAINT pk_user_event_progress
        PRIMARY KEY (user_id, event_id, milestone)
);
CREATE INDEX idx_user_event_progress_user ON user_event_progress(user_id, granted_at DESC);
CREATE INDEX idx_user_event_progress_event ON user_event_progress(event_id);

-- ================= historical_dossiers =================
-- Catalog canonical nhân vật/địa điểm/hiện vật/bối cảnh (Lớp B).
-- source_json giữ citation + asset pin — archive asset không mất nội dung
-- đã mở (§8.3). canonical_code là khóa dedup toàn cục.
CREATE TABLE historical_dossiers (
    id UUID PRIMARY KEY,
    canonical_code VARCHAR(120) NOT NULL UNIQUE,
    dossier_type VARCHAR(16) NOT NULL,
    title VARCHAR(255) NOT NULL,
    summary TEXT,
    description TEXT,
    source_json JSONB,
    asset_id UUID REFERENCES assets(id),
    status VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
    dossier_version INTEGER NOT NULL DEFAULT 1,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_dossier_type CHECK (
        dossier_type IN ('PERSON','LOCATION','ARTIFACT','CONTEXT')),
    CONSTRAINT chk_dossier_status CHECK (
        status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_dossier_source CHECK (
        source_json IS NULL OR jsonb_typeof(source_json) = 'object')
);
CREATE INDEX idx_dossiers_type ON historical_dossiers(dossier_type);
CREATE INDEX idx_dossiers_status ON historical_dossiers(status);

-- ================= event_dossiers =================
-- Quan hệ chính thức duy nhất sinh unlock — không so khớp tên/tag (QA-16).
CREATE TABLE event_dossiers (
    event_id UUID NOT NULL REFERENCES historical_events(id),
    dossier_id UUID NOT NULL REFERENCES historical_dossiers(id),
    unlock_on VARCHAR(24) NOT NULL DEFAULT 'EVENT_COMPLETED',
    sort_order INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_event_dossier_unlock CHECK (unlock_on IN ('EVENT_COMPLETED')),
    CONSTRAINT pk_event_dossiers PRIMARY KEY (event_id, dossier_id)
);
CREATE INDEX idx_event_dossiers_dossier ON event_dossiers(dossier_id);

-- ================= user_dossier_unlocks =================
-- Quyền mở hồ sơ, unique theo canonical dossier (§8.3). event_id +
-- dossier_version giữ provenance lần mở đầu tiên (ITEM-03).
CREATE TABLE user_dossier_unlocks (
    user_id UUID NOT NULL REFERENCES users(id),
    dossier_id UUID NOT NULL REFERENCES historical_dossiers(id),
    event_id UUID NOT NULL REFERENCES historical_events(id),
    dossier_version INTEGER NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_user_dossier_unlocks PRIMARY KEY (user_id, dossier_id)
);
CREATE INDEX idx_user_dossier_unlocks_user ON user_dossier_unlocks(user_id, granted_at DESC);
CREATE INDEX idx_user_dossier_unlocks_event ON user_dossier_unlocks(event_id);

-- ================= SEED: policies + dossiers cho 3 sự kiện mẫu =================
-- Events resolve theo SLUG (đã tồn tại từ V20 hoặc EventSeedRunner) — không
-- dựa vào UUID cố định. required_lesson_ids lấy lesson PUBLISHED đầu tiên của
-- từng event (demo 1 bài/sự kiện — KHÔNG phải quy tắc mặc định, service đọc
-- thẳng từ bảng). Mọi insert ON CONFLICT DO NOTHING → chạy lại an toàn.
DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    evt_bd UUID;
    evt_hb UUID;
    evt_lt UUID;

    les_bd UUID;
    les_hb UUID;
    les_lt UUID;

    pol_bd UUID := 'd7c00000-0000-4000-8000-000000000001';
    pol_hb UUID := 'd7c00000-0000-4000-8000-000000000002';
    pol_lt UUID := 'd7c00000-0000-4000-8000-000000000003';

    dos_ngoquyen   UUID := 'd7c10000-0000-4000-8000-000000000001';
    dos_trungtrac  UUID := 'd7c10000-0000-4000-8000-000000000002';
    dos_trungnhi   UUID := 'd7c10000-0000-4000-8000-000000000003';
    dos_lythaito   UUID := 'd7c10000-0000-4000-8000-000000000004';
    dos_bachdang   UUID := 'd7c10000-0000-4000-8000-000000000005';
    dos_melinh     UUID := 'd7c10000-0000-4000-8000-000000000006';
    dos_hoalu      UUID := 'd7c10000-0000-4000-8000-000000000007';
    dos_cocgo      UUID := 'd7c10000-0000-4000-8000-000000000008';
BEGIN
    -- Events: resolve id thật theo slug (row có thể do EventSeedRunner tạo
    -- trước với UUID khác các hằng V20 — giống hệt cơ chế V20).
    SELECT id INTO evt_bd FROM historical_events WHERE slug = 'bach-dang-938';
    SELECT id INTO evt_hb FROM historical_events WHERE slug = 'hai-ba-trung-40';
    SELECT id INTO evt_lt FROM historical_events WHERE slug = 'ly-thai-to-1010';

    -- Required lesson = lesson PUBLISHED đầu tiên của event (nếu có). Chính
    -- sách chỉ có nghĩa khi trỏ tới bài học thật — event chưa có lesson thì
    -- bỏ qua, không seed policy rỗng.
    IF evt_bd IS NOT NULL THEN
        SELECT l.id INTO les_bd FROM lessons l
         WHERE l.event_id = evt_bd AND l.status = 'PUBLISHED'
         ORDER BY l.created_at ASC LIMIT 1;
    END IF;
    IF evt_hb IS NOT NULL THEN
        SELECT l.id INTO les_hb FROM lessons l
         WHERE l.event_id = evt_hb AND l.status = 'PUBLISHED'
         ORDER BY l.created_at ASC LIMIT 1;
    END IF;
    IF evt_lt IS NOT NULL THEN
        SELECT l.id INTO les_lt FROM lessons l
         WHERE l.event_id = evt_lt AND l.status = 'PUBLISHED'
         ORDER BY l.created_at ASC LIMIT 1;
    END IF;

    -- 1 policy PUBLISHED / event; ON CONFLICT (event_id, policy_version)
    -- DO NOTHING → tái chạy không đụng policy đang sống.
    IF les_bd IS NOT NULL THEN
        INSERT INTO event_completion_policies
            (id, event_id, policy_version, status, required_lesson_ids,
             optional_lesson_ids, mastery_threshold, published_at)
        VALUES (pol_bd, evt_bd, 1, 'PUBLISHED',
                to_jsonb(ARRAY[les_bd]), '[]'::jsonb, 70, now())
        ON CONFLICT (event_id, policy_version) DO NOTHING;
    END IF;
    IF les_hb IS NOT NULL THEN
        INSERT INTO event_completion_policies
            (id, event_id, policy_version, status, required_lesson_ids,
             optional_lesson_ids, mastery_threshold, published_at)
        VALUES (pol_hb, evt_hb, 1, 'PUBLISHED',
                to_jsonb(ARRAY[les_hb]), '[]'::jsonb, 70, now())
        ON CONFLICT (event_id, policy_version) DO NOTHING;
    END IF;
    IF les_lt IS NOT NULL THEN
        INSERT INTO event_completion_policies
            (id, event_id, policy_version, status, required_lesson_ids,
             optional_lesson_ids, mastery_threshold, published_at)
        VALUES (pol_lt, evt_lt, 1, 'PUBLISHED',
                to_jsonb(ARRAY[les_lt]), '[]'::jsonb, 70, now())
        ON CONFLICT (event_id, policy_version) DO NOTHING;
    END IF;

    -- ---------- Dossiers canonical (citation thật, không asset giả) ----------
    INSERT INTO historical_dossiers
        (id, canonical_code, dossier_type, title, summary, description,
         source_json, asset_id, status, dossier_version, created_by)
    VALUES
        (dos_ngoquyen, 'ngo-quyen', 'PERSON', 'Ngô Quyền',
         'Thủ lĩnh trận Bạch Đằng 938, mở kỷ nguyên độc lập.',
         'Ngô Quyền (897–944), người Ái Châu. Năm 938 ông lợi dụng thủy triều '
         'trên sông Bạch Đằng phối hợp bãi cọc ngầm để đánh bại thủy quân Nam '
         'Hán, chấm dứt hơn một nghìn năm Bắc thuộc và lên ngôi vua năm 939.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên",'
         '"citation":"Ngoại kỷ, quyển 5, kỷ Ngô Quyền","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_trungtrac, 'trung-trac', 'PERSON', 'Trưng Trắc',
         'Nữ tướng khởi xướng khởi nghĩa Hai Bà Trưng năm 40.',
         'Trưng Trắc, con gái Lạc tướng Mê Linh. Năm 40 bà cùng em gái Trưng '
         'Nhị phất cờ khởi nghĩa chống ách đô hộ nhà Hán; 65 thành trì hưởng '
         'ứng, bà được suy tôn làm Trưng Nữ Vương.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên",'
         '"citation":"Ngoại kỷ, quyển 3, kỷ Trưng Nữ Vương","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_trungnhi, 'trung-nhi', 'PERSON', 'Trưng Nhị',
         'Phó tướng đồng hành cùng Trưng Trắc trong khởi nghĩa năm 40.',
         'Trưng Nhị, em gái Trưng Trắc, cùng chị lãnh đạo khởi nghĩa năm 40 '
         'từ Mê Linh đánh chiếm Luy Lâu — trung tâm cai trị của nhà Hán ở '
         'Giao Chỉ.',
         '{"source":{"title":"Đại Việt sử ký toàn thư","author":"Ngô Sĩ Liên",'
         '"citation":"Ngoại kỷ, quyển 3, kỷ Trưng Nữ Vương","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_lythaito, 'ly-thai-to', 'PERSON', 'Lý Thái Tổ',
         'Hoàng đế khai sáng nhà Lý, ban Chiếu dời đô năm 1010.',
         'Lý Công Uẩn (974–1028) lên ngôi năm 1009 lập nhà Lý. Năm 1010 ông '
         'ban Chiếu dời đô, chuyển kinh đô từ Hoa Lư về Đại La và đổi tên '
         'thành Thăng Long — nền móng trung tâm chính trị lâu dài.',
         '{"source":{"title":"Đại Việt sử ký toàn thư",'
         '"citation":"Bản kỷ, quyển 2, kỷ Lý Thái Tổ","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_bachdang, 'song-bach-dang', 'LOCATION', 'Sông Bạch Đằng',
         'Trận địa thủy chiến quyết định năm 938.',
         'Cửa sông Bạch Đằng (Quảng Ninh) có chế độ bán nhật triều mạnh — '
         'Ngô Quyền tận dụng nhịp con nước để giấu bãi cọc rồi chặn đánh khi '
         'triều rút.',
         '{"source":{"title":"Viện Hàn lâm KHXH&NV",'
         '"citation":"Tư liệu địa hình cửa sông Bạch Đằng","reliability":"MEDIUM"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_melinh, 'me-linh', 'LOCATION', 'Mê Linh — Luy Lâu',
         'Quê hương Hai Bà Trưng và trung tâm quyền lực Hán tại Giao Chỉ.',
         'Mê Linh là đất phát khởi của khởi nghĩa năm 40; Luy Lâu là thủ phủ '
         'đô hộ của nhà Hán mà quân khởi nghĩa chiếm được.',
         '{"source":{"title":"Ban quản lý di tích Mê Linh",'
         '"citation":"Di tích đền Hai Bà Trưng, Mê Linh","reliability":"MEDIUM"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_hoalu, 'hoa-lu-dai-la', 'LOCATION', 'Hoa Lư — Đại La',
         'Hai kinh đô đánh dấu bước chuyển trung tâm quyền lực năm 1010.',
         'Hoa Lư hiểm trở nhưng chật hẹp; Đại La nằm giữa đồng bằng Bắc Bộ, '
         'thuận đường thủy — Lý Thái Tổ chọn đây làm kinh đô mới và đổi tên '
         'Thăng Long.',
         '{"source":{"title":"Đại Việt sử ký toàn thư",'
         '"citation":"Bản kỷ, quyển 2, kỷ Lý Thái Tổ","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user),
        (dos_cocgo, 'coc-go-bach-dang', 'ARTIFACT', 'Bãi cọc gỗ Bạch Đằng',
         'Hiện vật khảo cổ chứng minh trận địa cọc ngầm.',
         'Các bãi cọc gỗ khai quật tại Yên Giang – Vạn Yên có niên đại phù hợp '
         'giai đoạn trận Bạch Đằng 938, củng cố mô tả sử liệu về trận thủy '
         'chiến.',
         '{"source":{"title":"Bảo tàng Lịch sử Quốc gia",'
         '"citation":"Hiện vật bãi cọc Bạch Đằng (khai quật Yên Giang)",'
         '"url":"https://baotanglichsuquocgia.vn","reliability":"HIGH"}}'::jsonb,
         NULL, 'PUBLISHED', 1, sys_user)
    ON CONFLICT (canonical_code) DO NOTHING;

    -- ---------- Liên kết event ↔ dossier (unlock_on EVENT_COMPLETED) ----------
    IF evt_bd IS NOT NULL THEN
        INSERT INTO event_dossiers (event_id, dossier_id, unlock_on, sort_order)
        VALUES
            (evt_bd, dos_ngoquyen, 'EVENT_COMPLETED', 1),
            (evt_bd, dos_bachdang, 'EVENT_COMPLETED', 2),
            (evt_bd, dos_cocgo, 'EVENT_COMPLETED', 3)
        ON CONFLICT (event_id, dossier_id) DO NOTHING;
    END IF;
    IF evt_hb IS NOT NULL THEN
        INSERT INTO event_dossiers (event_id, dossier_id, unlock_on, sort_order)
        VALUES
            (evt_hb, dos_trungtrac, 'EVENT_COMPLETED', 1),
            (evt_hb, dos_trungnhi, 'EVENT_COMPLETED', 2),
            (evt_hb, dos_melinh, 'EVENT_COMPLETED', 3)
        ON CONFLICT (event_id, dossier_id) DO NOTHING;
    END IF;
    IF evt_lt IS NOT NULL THEN
        INSERT INTO event_dossiers (event_id, dossier_id, unlock_on, sort_order)
        VALUES
            (evt_lt, dos_lythaito, 'EVENT_COMPLETED', 1),
            (evt_lt, dos_hoalu, 'EVENT_COMPLETED', 2)
        ON CONFLICT (event_id, dossier_id) DO NOTHING;
    END IF;
END $$;
