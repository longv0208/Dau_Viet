-- Dấu Việt | V64 | Demo content: 4 Bắc-thuộc events → FOUR_STEP lessons + evidence + demo path
-- Issue #54 — Database cleanup & seed 4 bài học demo FOUR_STEP.
-- Bốn sự kiện canonical (slug resolve, không hardcode khi đã tồn tại):
--   1. Khởi nghĩa Hai Bà Trưng (40–43)      → khoi-nghia-hai-ba-trung-40
--   2. Khởi nghĩa Bà Triệu (248)            → history-ba-trieu
--   3. Khởi nghĩa Lý Bí & Vạn Xuân (542–602) → history-ly-bi
--   4. Chiến thắng Bạch Đằng & Ngô Quyền (938–939) → bach-dang-938
--
-- Nguyên tắc an toàn:
--   • Không đụng users/attempts/lesson_versions cũ/published snapshot.
--   • Không xoá; lesson cũ của BT/LB được ARCHIVED (giữ lịch sử, an toàn).
--   • Draft JSON mới gán vào lessons.draft_json — KHÔNG publish bằng SQL;
--     publish thực hiện qua LessonPublishService để SnapshotBuilder nhúng
--     evidence/assets/animation manifest đúng contract.
--   • Learning path mới DEMO_BAC_THUOC tạo ở DRAFT (publish sau khi 4
--     lesson được publish bởi backend, tránh node trỏ tới DRAFT lesson).
--   • Completion policy: event BT/LB tạo policy_version mới trỏ lesson FOUR_STEP.
--   • Idempotent: ON CONFLICT guards + slug/id resolution.
--
-- Evidence ids dùng namespace 64000000-0000-4000-8000-00000000EEEN:
--   EE = event ordinal (01=HBT,02=BT,03=LB,04=BD), N = 1..4.

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';
    tpl_fs   UUID := '63000000-0000-4000-8000-000000000010';  -- FOUR_STEP (V63)

    evt_hbt UUID;
    evt_bt  UUID;
    evt_lb  UUID;
    evt_bd  UUID;

    les_hbt UUID := '64000000-0000-4000-8000-000000000001';
    les_bt  UUID := '64000000-0000-4000-8000-000000000002';
    les_lb  UUID := '64000000-0000-4000-8000-000000000003';
    les_bd  UUID := 'd7b20000-0000-4000-8000-000000000001';  -- canonical BD lesson (existing)

    -- Evidence ids (namespace 64000000-...-0EEEN)
    ev UUID;
    d  JSONB;

    -- Learning path
    path_id  UUID := '64000000-0000-4000-8000-0000000000f0';
    chap_id  UUID := '64000000-0000-4000-8000-0000000000f1';
    path_ver INT   := 1;

    -- Assets (nullable)
    asset_me_linh       UUID;
    asset_doanh_trai    UUID;
    asset_bach_dang_coc UUID;
    asset_tran_dia_coc  UUID;
    asset_ngoquyen_hero UUID;
    asset_thu_phong     UUID;

    sc_bd_prod UUID := 'd7a80000-0000-4000-8000-000000000001';  -- Bạch Đằng production scene
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- Guard: FOUR_STEP template must exist (V63). Nếu chưa chạy V63 → dừng rõ ràng.
    IF NOT EXISTS (SELECT 1 FROM lesson_templates WHERE code='FOUR_STEP') THEN
        RAISE EXCEPTION 'FOUR_STEP template missing — apply V63 first';
    END IF;
    SELECT id INTO tpl_fs FROM lesson_templates WHERE code='FOUR_STEP' LIMIT 1;

    -- Resolve event ids by slug (use existing canonical rows; do NOT create dupes)
    SELECT id INTO evt_hbt FROM historical_events WHERE slug='khoi-nghia-hai-ba-trung-40' LIMIT 1;
    IF evt_hbt IS NULL THEN
        SELECT id INTO evt_hbt FROM historical_events WHERE slug='hai-ba-trung-40' LIMIT 1;
    END IF;
    SELECT id INTO evt_bt  FROM historical_events WHERE slug='history-ba-trieu' LIMIT 1;
    SELECT id INTO evt_lb  FROM historical_events WHERE slug='history-ly-bi' LIMIT 1;
    SELECT id INTO evt_bd  FROM historical_events WHERE slug='bach-dang-938' LIMIT 1;

    IF evt_hbt IS NULL OR evt_bt IS NULL OR evt_lb IS NULL OR evt_bd IS NULL THEN
        RAISE EXCEPTION 'Missing canonical event(s): hbt=%, bt=%, lb=%, bd=%',
            evt_hbt, evt_bt, evt_lb, evt_bd;
    END IF;

    -- Resolve assets (nullable)
    SELECT id INTO asset_me_linh       FROM assets WHERE id='d7a70000-0000-4000-8000-000000000002'::uuid;
    SELECT id INTO asset_bach_dang_coc FROM assets WHERE id='d7a70000-0000-4000-8000-000000000003'::uuid;
    SELECT id INTO asset_tran_dia_coc  FROM assets WHERE id='d7a70000-0000-4000-8000-000000000008'::uuid;
    SELECT id INTO asset_doanh_trai    FROM assets WHERE id='d7a70000-0000-4000-8000-000000000009'::uuid;
    SELECT id INTO asset_thu_phong     FROM assets WHERE id='d7a70000-0000-4000-8000-000000000010'::uuid;
    SELECT id INTO asset_ngoquyen_hero FROM assets WHERE id='d7a70000-0000-4000-8000-000000000011'::uuid;

    -- =========================================================================
    -- 1. EVENT METADATA — chuẩn hoá 4 event canonical (không đổi slug/id)
    -- =========================================================================
    UPDATE historical_events SET
        title='Khởi nghĩa Hai Bà Trưng (40–43)',
        era='Thời kỳ Bắc thuộc',
        period='Năm 40 – 43',
        start_year=40,
        summary='Cuộc khởi nghĩa do Trưng Trắc và Trưng Nhị lãnh đạo năm 40 chống chính quyền Đông Hán; giành chính quyền tự chủ rồi thất bại trước cuộc phản công của Mã Viện năm 42–43.',
        description='Đầu thế kỷ I, chính quyền Đông Hán cai trị vùng đất người Việt bằng nhiều chính sách hà khắc. Năm 40, Trưng Trắc và Trưng Nhị phất cờ khởi nghĩa tại Hát Môn/Mê Linh, nhân dân hưởng ứng, Tô Định phải bỏ chạy. Trưng Trắc lên ngôi Trưng Vương. Năm 42 nhà Hán cử Mã Viện sang đàn áp; đến năm 43 cuộc kháng chiến thất bại. Cuộc khởi nghĩa trở thành biểu tượng tinh thần độc lập và vai trò phụ nữ.',
        updated_at=now()
    WHERE id=evt_hbt;

    UPDATE historical_events SET
        title='Khởi nghĩa Bà Triệu (248)',
        era='Thời kỳ Bắc thuộc',
        period='Năm 248',
        start_year=248,
        summary='Cuộc khởi nghĩa năm 248 do Triệu Thị Trinh (Bà Triệu) và Triệu Quốc Đạt lãnh đạo chống nhà Đông Ngô, bùng nổ tại Cửu Chân; thất bại trước quân Lục Dận nhưng trở thành biểu tượng bất khuất.',
        description='Thế kỷ III, vùng đất người Việt chịu sự cai trị của nhà Đông Ngô. Năm 248, Triệu Thị Trinh cùng anh trai Triệu Quốc Đạt tập hợp nghĩa sĩ tại vùng Núi Nưa — Cửu Chân, đứng lên chống đô hộ. Nhà Đông Ngô cử Lục Dận đàn áp; cuộc khởi nghĩa kết thúc trong năm 248. Theo truyền thống, Bà Triệu tuẫn tiết tại Núi Tùng — trở thành biểu tượng tinh thần bất khuất của phụ nữ Việt.',
        updated_at=now()
    WHERE id=evt_bt;

    UPDATE historical_events SET
        title='Khởi nghĩa Lý Bí và nhà nước Vạn Xuân (542–602)',
        era='Thời kỳ Bắc thuộc',
        period='Năm 542 – 602',
        start_year=542,
        summary='Năm 542 Lý Bí phát động khởi nghĩa chống nhà Lương; năm 544 xưng Lý Nam Đế, đặt quốc hiệu Vạn Xuân. Triệu Quang Phục tiếp tục kháng chiến; nhà nước Vạn Xuân kết thúc năm 602 trước nhà Tùy.',
        description='Thế kỷ VI, nhà Lương cai trị hà khắc tại Giao Châu. Năm 542 Lý Bí phát động khởi nghĩa, đánh bại quân Lương 542–543. Năm 544 Lý Bí lên ngôi Lý Nam Đế, đặt quốc hiệu Vạn Xuân. Năm 545 nhà Lương phản công; Lý Nam Đế qua đời năm 548. Triệu Quang Phục tiếp tục kháng chiến ở Dạ Trạch, thắng quân Lương năm 550. Năm 602 nhà Tùy xâm lược, nhà nước Vạn Xuân kết thúc.',
        updated_at=now()
    WHERE id=evt_lb;

    UPDATE historical_events SET
        title='Chiến thắng Bạch Đằng và sự nghiệp Ngô Quyền (938–939)',
        era='Thời kỳ Bắc thuộc → độc lập',
        period='Năm 937 – 939',
        start_year=938,
        summary='Năm 938, Ngô Quyền lợi dụng địa hình và thủy triều sông Bạch Đằng, bố trí trận địa cọc ngầm đánh bại thủy quân Nam Hán của Lưu Hoằng Tháo; năm 939 xưng vương, mở ra thời kỳ độc lập lâu dài.',
        description='Năm 937 Kiều Công Tiễn sát hại Dương Đình Nghệ rồi cầu cứu nhà Nam Hán. Năm 938 Ngô Quyền tiến ra Bắc, tiêu diệt Kiều Công Tiễn và chuẩn bị chống quân Nam Hán. Ông chọn sông Bạch Đằng làm nơi quyết chiến, lợi dụng quy luật thủy triều và trận địa cọc ngầm. Khi nước triều rút, chiến thuyền Nam Hán mắc cọc, quân ta phản công đại thắng; Lưu Hoằng Tháo tử trận. Năm 939 Ngô Quyền xưng vương, chọn Cổ Loa làm kinh đô.',
        updated_at=now()
    WHERE id=evt_bd;

    -- =========================================================================
    -- 2. EVIDENCE LIBRARY — 16 thẻ (4/event), namespace 64000000-...-0EEEN
    --    evidence_type = 'HISTORICAL_TEXT' (tư liệu biên soạn), reliability
    --    'MEDIUM' — không tự gán HIGH/VERIFIED_PRIMARY cho nội dung biên soạn.
    -- =========================================================================
    INSERT INTO evidences (id, event_id, title, evidence_type, description,
        source_title, source_author, source_citation, reliability, relevance,
        asset_id, status, created_by, created_at, updated_at)
    VALUES
    -- ---- Hai Bà Trưng (01) ----
    ('64000000-0000-4000-8000-000000010101', evt_hbt,
     'HBT-E1 · Chính sách cai trị của Đông Hán', 'HISTORICAL_TEXT',
     'Đầu thế kỷ I, chính quyền Đông Hán cai trị vùng đất người Việt bằng nhiều chính sách hà khắc và bóc lột; thái thú Tô Định cai trị hà khắc khiến sự bất bình của nhân dân gia tăng.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Hai Bà Trưng',
     'MEDIUM', 'Bối cảnh và nguyên nhân bùng nổ khởi nghĩa năm 40',
     asset_me_linh, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000010102', evt_hbt,
     'HBT-E2 · Thắng lợi năm 40 và Trưng Trắc lên ngôi', 'HISTORICAL_TEXT',
     'Năm 40 cuộc khởi nghĩa bùng nổ và nhận được sự hưởng ứng rộng rãi; Tô Định phải bỏ chạy, Trưng Trắc lên ngôi Trưng Vương và xây dựng chính quyền tự chủ.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Hai Bà Trưng',
     'MEDIUM', 'Kết quả thắng lợi ban đầu của cuộc khởi nghĩa',
     asset_doanh_trai, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000010103', evt_hbt,
     'HBT-E3 · Phản công của Mã Viện và thất bại năm 43', 'HISTORICAL_TEXT',
     'Năm 42 quân Đông Hán do Mã Viện chỉ huy tiến sang đàn áp; đến năm 43 cuộc kháng chiến của Hai Bà Trưng thất bại, nền tự chủ kết thúc.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Hai Bà Trưng',
     'MEDIUM', 'Nguyên nhân nền tự chủ không được duy trì',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000010104', evt_hbt,
     'HBT-E4 · Ý nghĩa và vai trò phụ nữ', 'HISTORICAL_TEXT',
     'Cuộc khởi nghĩa Hai Bà Trưng khẳng định ý chí độc lập, sức mạnh đoàn kết và vai trò lãnh đạo của phụ nữ trong lịch sử dân tộc.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Hai Bà Trưng',
     'MEDIUM', 'Ý nghĩa lịch sử và biểu tượng của cuộc khởi nghĩa',
     NULL, 'APPROVED', sys_user, now(), now()),
    -- ---- Bà Triệu (02) ----
    ('64000000-0000-4000-8000-000000020101', evt_bt,
     'BT-E1 · Chính sách cai trị của Đông Ngô ở Cửu Chân', 'HISTORICAL_TEXT',
     'Thế kỷ III, vùng đất người Việt chịu sự cai trị của nhà Đông Ngô; chính sách bóc lột và đàn áp làm gia tăng sự bất bình tại vùng Cửu Chân.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Bà Triệu',
     'MEDIUM', 'Bối cảnh bùng nổ khởi nghĩa năm 248',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000020102', evt_bt,
     'BT-E2 · Bà Triệu và lực lượng khởi nghĩa năm 248', 'HISTORICAL_TEXT',
     'Triệu Thị Trinh cùng anh trai Triệu Quốc Đạt tập hợp nghĩa sĩ chống nhà Đông Ngô; khởi nghĩa bùng nổ tại vùng núi Nưa — Cửu Chân năm 248.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Bà Triệu',
     'MEDIUM', 'Lực lượng và địa điểm phát động khởi nghĩa',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000020103', evt_bt,
     'BT-E3 · Lục Dận đàn áp và kết quả', 'HISTORICAL_TEXT',
     'Nhà Đông Ngô cử Lục Dận đàn áp cuộc khởi nghĩa; cuộc khởi nghĩa kết thúc trong năm 248. Theo truyền thống, Bà Triệu tuẫn tiết tại Núi Tùng.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Bà Triệu',
     'MEDIUM', 'Kết quả quân sự và kết thúc cuộc khởi nghĩa',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000020104', evt_bt,
     'BT-E4 · Ý nghĩa lịch sử và hình tượng Bà Triệu', 'HISTORICAL_TEXT',
     'Dù không thành công về quân sự, cuộc khởi nghĩa Bà Triệu thể hiện ý chí không khuất phục trước ách đô hộ; hình tượng Bà Triệu trở thành biểu tượng lòng yêu nước và tinh thần kiên cường của phụ nữ Việt.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Bà Triệu',
     'MEDIUM', 'Ý nghĩa tinh thần và giá trị biểu tượng',
     NULL, 'APPROVED', sys_user, now(), now()),
    -- ---- Lý Bí / Vạn Xuân (03) ----
    ('64000000-0000-4000-8000-000000030101', evt_lb,
     'LB-E1 · Chính sách cai trị của nhà Lương', 'HISTORICAL_TEXT',
     'Thế kỷ VI, chính quyền nhà Lương cai trị hà khắc tại Giao Châu, tạo nên sự bất bình khiến Lý Bí tập hợp hào kiệt và nhân dân đứng lên.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Lý Bí/Vạn Xuân',
     'MEDIUM', 'Bối cảnh và nguyên nhân khởi nghĩa 542',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000030102', evt_lb,
     'LB-E2 · Thắng lợi khởi nghĩa 542–543', 'HISTORICAL_TEXT',
     'Năm 542 Lý Bí phát động khởi nghĩa và tiếp tục đánh bại quân Lương năm 543, nhanh chóng đánh đổ chính quyền đô hộ ở nhiều nơi.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Lý Bí/Vạn Xuân',
     'MEDIUM', 'Thắng lợi quân sự mở đường thành lập chính quyền',
     asset_doanh_trai, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000030103', evt_lb,
     'LB-E3 · Lý Bí lập nước Vạn Xuân năm 544', 'HISTORICAL_TEXT',
     'Năm 544 Lý Bí lên ngôi hoàng đế, lấy hiệu Lý Nam Đế và đặt quốc hiệu Vạn Xuân — thể hiện khát vọng xây dựng một nhà nước độc lập, tự chủ.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Lý Bí/Vạn Xuân',
     'MEDIUM', 'Bước phát triển từ khởi nghĩa thành nhà nước',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000030104', evt_lb,
     'LB-E4 · Triệu Quang Phục và kết thúc năm 602', 'HISTORICAL_TEXT',
     'Sau khi Lý Nam Đế qua đời năm 548, Triệu Quang Phục tiếp tục kháng chiến ở Dạ Trạch và giành thắng lợi năm 550; đến năm 602 nhà Tùy xâm lược, nhà nước Vạn Xuân kết thúc.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — sự kiện Lý Bí/Vạn Xuân',
     'MEDIUM', 'Giai đoạn tiếp nối và kết thúc của Vạn Xuân',
     NULL, 'APPROVED', sys_user, now(), now()),
    -- ---- Bạch Đằng (04) ----
    ('64000000-0000-4000-8000-000000040101', evt_bd,
     'BD-E1 · Địa hình và thủy triều sông Bạch Đằng', 'HISTORICAL_TEXT',
     'Ngô Quyền chọn khu vực sông Bạch Đằng với đặc điểm thủy triều lên xuống có thể ảnh hưởng lớn tới việc di chuyển của chiến thuyền — mực nước thay đổi theo thời điểm quyết định điều kiện tác chiến.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — chiến thắng Bạch Đằng 938',
     'MEDIUM', 'Điều kiện tự nhiên quyết định lợi thế chiến trường',
     asset_bach_dang_coc, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000040102', evt_bd,
     'BD-E2 · Trận địa cọc ngầm', 'HISTORICAL_TEXT',
     'Ngô Quyền cho chuẩn bị cọc gỗ bịt sắt ở những vị trí hiểm yếu dưới lòng sông, kết hợp bố trí lực lượng mai phục để đón đánh thủy quân Nam Hán.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — chiến thắng Bạch Đằng 938',
     'MEDIUM', 'Yếu tố kỹ thuật trận địa quyết định hiệu quả phục kích',
     asset_tran_dia_coc, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000040103', evt_bd,
     'BD-E3 · Kế sách nhử địch và phản công', 'HISTORICAL_TEXT',
     'Thuyền nhẹ của quân ta khiêu chiến rồi giả rút lui để dẫn quân Nam Hán vào trận địa; khi thủy triều rút, quân ta phản công khiến thuyền địch mắc vào bãi cọc.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — chiến thắng Bạch Đằng 938',
     'MEDIUM', 'Cơ chế phối hợp thủy triều, nhử địch và phản công',
     NULL, 'APPROVED', sys_user, now(), now()),
    ('64000000-0000-4000-8000-000000040104', evt_bd,
     'BD-E4 · Kết quả và ý nghĩa', 'HISTORICAL_TEXT',
     'Quân Nam Hán đại bại, Lưu Hoằng Tháo tử trận. Năm 939 Ngô Quyền xưng vương và xây dựng chính quyền độc lập — chiến thắng Bạch Đằng mở ra thời kỳ độc lập lâu dài.',
     'Tài liệu học tập biên soạn', 'Nhóm nội dung Dấu Việt',
     'Biên soạn từ tài liệu lịch sử Bắc thuộc — chiến thắng Bạch Đằng 938',
     'MEDIUM', 'Hệ quả chính trị và ý nghĩa lịch sử',
     asset_ngoquyen_hero, 'APPROVED', sys_user, now(), now())
    ON CONFLICT (id) DO UPDATE SET
        event_id=EXCLUDED.event_id, title=EXCLUDED.title,
        description=EXCLUDED.description, source_title=EXCLUDED.source_title,
        source_citation=EXCLUDED.source_citation, reliability=EXCLUDED.reliability,
        relevance=EXCLUDED.relevance, asset_id=EXCLUDED.asset_id,
        status=EXCLUDED.status, updated_at=now();

    -- =========================================================================
    -- 3. LESSON 1 — HAI BÀ TRƯNG (FOUR_STEP draft)
    -- =========================================================================
    d := $draft${
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Hai Bà Trưng lãnh đạo khởi nghĩa năm 40 giành lại chính quyền tự chủ",
        "Cuộc phản công của Mã Viện năm 42–43 kết thúc nền tự chủ",
        "Khởi nghĩa khẳng định ý chí độc lập và vai trò lãnh đạo của phụ nữ"
      ],
      "stages": [
        {"id":"discovery","type":"DISCOVERY","title":"Truy tìm Dấu vết","required":true,
         "allowFreeOrder":true,
         "description":"Khám phá bốn dấu vết về khởi nghĩa Hai Bà Trưng năm 40 theo bất kỳ thứ tự nào.",
         "nextStageIds":["hypothesis"],
         "activities":[
          {"id":"clue-context","type":"READ","required":true,"clueType":"CONTEXT",
           "title":"Dưới ách đô hộ Đông Hán",
           "description":"Bối cảnh chính quyền Đông Hán cai trị hà khắc đầu thế kỷ I",
           "coverAssetId":null,
           "instruction":"Đọc bối cảnh bùng nổ khởi nghĩa Hai Bà Trưng",
           "config":{"text":"Đầu thế kỉ I, chính quyền Đông Hán cai trị vùng đất của người Việt bằng nhiều chính sách hà khắc và bóc lột. Sự bất bình của nhân dân ngày càng gia tăng, đặc biệt trước cách cai trị của thái thú Tô Định. Trong hoàn cảnh đó, Trưng Trắc và Trưng Nhị tập hợp lực lượng, đứng lên chống chính quyền đô hộ vào năm 40."}},
          {"id":"clue-characters","type":"MULTIPLE_CHOICE","required":true,"clueType":"CHARACTERS",
           "title":"Hai người lãnh đạo",
           "description":"Xác định hai nhân vật lãnh đạo cuộc khởi nghĩa năm 40",
           "coverAssetId":null,
           "instruction":"Chọn hai người lãnh đạo cuộc khởi nghĩa năm 40",
           "config":{"graded":true,
             "question":"Ai là hai người lãnh đạo cuộc khởi nghĩa năm 40?",
             "options":[
               {"id":"c-a","label":"Bà Triệu và Trưng Trắc"},
               {"id":"c-b","label":"Trưng Trắc và Trưng Nhị"},
               {"id":"c-c","label":"Lý Bí và Triệu Quang Phục"},
               {"id":"c-d","label":"Ngô Quyền và Dương Đình Nghệ"}],
             "correctOptionIds":["c-b"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng! Trưng Trắc và Trưng Nhị lãnh đạo cuộc khởi nghĩa, trở thành những nhân vật tiêu biểu trong lịch sử đấu tranh giành độc lập.","INCORRECT":"Chưa đúng — hãy nhớ lại hai chị em lãnh đạo khởi nghĩa năm 40.","EXHAUSTED":"Đáp án: Trưng Trắc và Trưng Nhị."}},
          {"id":"clue-development","type":"READ","required":true,"clueType":"DEVELOPMENT",
           "title":"Diễn biến khởi nghĩa",
           "description":"Diễn biến từ bùng nổ đến thất bại",
           "coverAssetId":null,
           "instruction":"Đọc diễn biến khởi nghĩa Hai Bà Trưng",
           "config":{"text":"Năm 40, cuộc khởi nghĩa bùng nổ và nhanh chóng nhận được sự hưởng ứng của nhiều lực lượng. Tô Định phải bỏ chạy. Trưng Trắc lên ngôi Trưng Vương và xây dựng chính quyền tự chủ. Năm 42, quân Đông Hán do Mã Viện chỉ huy tiến sang đàn áp. Đến năm 43, cuộc kháng chiến thất bại."}},
          {"id":"clue-significance","type":"MULTIPLE_CHOICE","required":true,"clueType":"SIGNIFICANCE",
           "title":"Ý nghĩa lịch sử",
           "description":"Ý nghĩa của khởi nghĩa Hai Bà Trưng",
           "coverAssetId":null,
           "instruction":"Chọn phát biểu mô tả đúng ý nghĩa lịch sử của khởi nghĩa Hai Bà Trưng",
           "config":{"graded":true,
             "question":"Ý nghĩa quan trọng của cuộc khởi nghĩa Hai Bà Trưng là gì?",
             "options":[
               {"id":"s-a","label":"Khẳng định ý chí độc lập, sức mạnh đoàn kết và vai trò lãnh đạo của phụ nữ trong lịch sử dân tộc"},
               {"id":"s-b","label":"Chấm dứt vĩnh viễn thời kỳ Bắc thuộc"},
               {"id":"s-c","label":"Chỉ là một cuộc nổi loạn địa phương nhỏ, không ảnh hưởng chính trị"},
               {"id":"s-d","label":"Đánh dấu lần đầu tiên người Việt dùng vũ khí bằng đồng"}],
             "correctOptionIds":["s-a"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Chính xác! Khởi nghĩa khẳng định ý chí độc lập và vai trò phụ nữ.","INCORRECT":"Chưa đúng — ý nghĩa lớn nhất là ý chí độc lập và vai trò lãnh đạo của phụ nữ.","EXHAUSTED":"Đáp án: khẳng định ý chí độc lập, sức mạnh đoàn kết và vai trò phụ nữ."}}
         ]},
        {"id":"hypothesis","type":"HYPOTHESIS","title":"Đặt Giả thuyết","required":true,
         "description":"Chọn giả thuyết giải thích đúng nhất kết quả của khởi nghĩa Hai Bà Trưng.",
         "nextStageIds":["verification"],
         "activities":[
          {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true,
           "instruction":"Chọn giả thuyết giải thích đúng nhất kết quả cuộc khởi nghĩa",
           "config":{"prompt":"Nhận định nào giải thích đúng nhất kết quả cuộc khởi nghĩa Hai Bà Trưng?",
             "hypotheses":[
               {"id":"h1","label":"Nghĩa quân được hưởng ứng rộng rãi nên giành thắng lợi năm 40, nhưng không giữ được chính quyền trước cuộc phản công lớn của Đông Hán năm 42–43."},
               {"id":"h2","label":"Cuộc khởi nghĩa duy trì nền độc lập liên tục từ năm 40 đến năm 938."},
               {"id":"h3","label":"Cuộc khởi nghĩa thất bại ngay từ đầu vì không nhận được sự hưởng ứng của nhân dân."}]},
           "feedback":{"COMPLETED":"Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng."}}
         ]},
        {"id":"verification","type":"VERIFICATION","title":"Kiểm chứng Giả thuyết","required":true,
         "description":"Đối chiếu giả thuyết với các tư liệu — chọn bằng chứng hỗ trợ giả thuyết.",
         "nextStageIds":["reconstruction"],
         "activities":[
          {"id":"vf","type":"VERIFICATION","required":true,
           "instruction":"Chọn các tư liệu chứng minh giả thuyết bạn vừa đặt",
           "onPartial":"verification","onContradicted":"hypothesis",
           "config":{
             "expectedHypothesis":"h1",
             "visibleSourceIds":["64000000-0000-4000-8000-000000010101","64000000-0000-4000-8000-000000010102","64000000-0000-4000-8000-000000010103","64000000-0000-4000-8000-000000010104"],
             "requiredEvidenceIds":["64000000-0000-4000-8000-000000010102","64000000-0000-4000-8000-000000010103"],
             "maxAttempts":3},
           "feedback":{"SUPPORTED":"Kiểm chứng thành công! Thắng lợi năm 40 (E2) và thất bại năm 42–43 (E3) cùng chứng minh giả thuyết của bạn.","PARTIAL":"Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy bổ sung tư liệu về cả thắng lợi năm 40 và phản công năm 42–43.","CONTRADICTED":"Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.","COMPLETED":"Kiểm chứng hoàn tất — giả thuyết được chứng minh."}}
         ]},
        {"id":"reconstruction","type":"RECONSTRUCTION","title":"Tái hiện Sự kiện","required":true,
         "description":"Sắp xếp lại trình tự diễn biến khởi nghĩa Hai Bà Trưng theo đúng thời gian.",
         "nextStageIds":[],
         "activities":[
          {"id":"do","type":"DRAG_ORDER","required":true,
           "instruction":"Sắp xếp lại diễn biến khởi nghĩa Hai Bà Trưng theo trình tự thời gian",
           "config":{"items":[
             {"id":"s1","label":"Chính quyền Đông Hán cai trị hà khắc"},
             {"id":"s2","label":"Hai Bà Trưng dựng cờ khởi nghĩa năm 40"},
             {"id":"s3","label":"Nghĩa quân thắng lợi, Trưng Trắc lên ngôi"},
             {"id":"s4","label":"Đông Hán cử Mã Viện phản công năm 42"},
             {"id":"s5","label":"Cuộc kháng chiến thất bại năm 43"}],
             "expectedOrder":["s1","s2","s3","s4","s5"],"maxAttempts":3},
           "feedback":{"COMPLETED":"Xuất sắc! Dù không giữ được nền tự chủ lâu dài, cuộc khởi nghĩa trở thành biểu tượng của tinh thần yêu nước và ý chí giành độc lập.","PARTIAL":"Một số bước đã đúng — chú ý trình tự: đô hộ → dựng cờ → thắng lợi → phản công → thất bại.","INCORRECT":"Thứ tự chưa đúng. Hãy bắt đầu từ chính quyền Đông Hán cai trị hà khắc.","EXHAUSTED":"Đã hết lượt. Trình tự: đô hộ → dựng cờ năm 40 → thắng lợi → Mã Viện phản công 42 → thất bại 43."}}
         ]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }$draft$::jsonb;

    IF asset_me_linh IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,0,coverAssetId}',to_jsonb(asset_me_linh::text),true);
    END IF;
    IF asset_doanh_trai IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,1,coverAssetId}',to_jsonb(asset_doanh_trai::text),true);
    END IF;

    INSERT INTO lessons (id, event_id, template_id, title, central_question,
        objectives_json, draft_json, status, created_by, updated_by)
    VALUES (les_hbt, evt_hbt, tpl_fs,
        'Khởi nghĩa Hai Bà Trưng năm 40',
        'Vì sao cuộc khởi nghĩa Hai Bà Trưng giành thắng lợi năm 40 nhưng nền tự chủ không giữ được sau cuộc phản công của Đông Hán?',
        '["Nắm được bối cảnh đô hộ Đông Hán","Xác định nhân vật lãnh đạo","Theo dõi diễn biến 40–43","Đánh giá ý nghĩa lịch sử"]'::jsonb,
        d, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO UPDATE SET
        event_id=EXCLUDED.event_id, template_id=EXCLUDED.template_id,
        title=EXCLUDED.title, central_question=EXCLUDED.central_question,
        objectives_json=EXCLUDED.objectives_json, draft_json=EXCLUDED.draft_json,
        updated_by=sys_user, updated_at=now();

    -- =========================================================================
    -- 4. LESSON 2 — BÀ TRIỆU (FOUR_STEP draft)
    -- =========================================================================
    d := $draft${
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Cuộc khởi nghĩa Bà Triệu bùng nổ năm 248 chống nhà Đông Ngô",
        "Khởi nghĩa thất bại trước quân Lục Dận nhưng có ý nghĩa tinh thần lớn",
        "Bà Triệu là biểu tượng bất khuất của phụ nữ Việt Nam"
      ],
      "stages": [
        {"id":"discovery","type":"DISCOVERY","title":"Truy tìm Dấu vết","required":true,
         "allowFreeOrder":true,
         "description":"Khám phá bốn dấu vết về khởi nghĩa Bà Triệu năm 248 theo bất kỳ thứ tự nào.",
         "nextStageIds":["hypothesis"],
         "activities":[
          {"id":"clue-context","type":"READ","required":true,"clueType":"CONTEXT",
           "title":"Ách đô hộ Đông Ngô",
           "description":"Bối cảnh cai trị của Đông Ngô thế kỷ III",
           "coverAssetId":null,
           "instruction":"Đọc bối cảnh bùng nổ khởi nghĩa Bà Triệu",
           "config":{"text":"Thế kỷ III, vùng đất của người Việt chịu sự cai trị của nhà Đông Ngô. Chính sách bóc lột và đàn áp làm gia tăng sự bất bình. Năm 248, cuộc khởi nghĩa do Triệu Thị Trinh lãnh đạo bùng nổ tại vùng Cửu Chân."}},
          {"id":"clue-characters","type":"READ","required":true,"clueType":"CHARACTERS",
           "title":"Bà Triệu và nghĩa quân",
           "description":"Triệu Thị Trinh và Triệu Quốc Đạt",
           "coverAssetId":null,
           "instruction":"Tìm hiểu nhân vật Bà Triệu và lực lượng khởi nghĩa",
           "config":{"text":"Triệu Thị Trinh cùng anh trai Triệu Quốc Đạt tập hợp nghĩa sĩ chống nhà Đông Ngô. Bà Triệu nổi tiếng với ý chí mạnh mẽ và khát vọng tự chủ. Trong truyền thống dân gian, bà là biểu tượng của tinh thần bất khuất."}},
          {"id":"clue-development","type":"MULTIPLE_CHOICE","required":true,"clueType":"DEVELOPMENT",
           "title":"Đàn áp của Đông Ngô",
           "description":"Vị tướng được cử đàn áp khởi nghĩa",
           "coverAssetId":null,
           "instruction":"Chọn vị tướng nhà Đông Ngô cử đàn áp khởi nghĩa Bà Triệu",
           "config":{"graded":true,
             "question":"Nhà Đông Ngô cử vị tướng nào đàn áp cuộc khởi nghĩa Bà Triệu?",
             "options":[
               {"id":"d-a","label":"Mã Viện"},
               {"id":"d-b","label":"Lục Dận"},
               {"id":"d-c","label":"Trần Bá Tiên"},
               {"id":"d-d","label":"Lưu Hoằng Tháo"}],
             "correctOptionIds":["d-b"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng! Lục Dận được nhà Đông Ngô cử đàn áp. Cuộc khởi nghĩa kết thúc trong năm 248.","INCORRECT":"Chưa đúng — vị tướng đàn áp là Lục Dận.","EXHAUSTED":"Đáp án: Lục Dận."}},
          {"id":"clue-significance","type":"READ","required":true,"clueType":"SIGNIFICANCE",
           "title":"Ý nghĩa lịch sử",
           "description":"Ý nghĩa của khởi nghĩa Bà Triệu",
           "coverAssetId":null,
           "instruction":"Đọc ý nghĩa của khởi nghĩa Bà Triệu",
           "config":{"text":"Dù không thành công về quân sự, cuộc khởi nghĩa Bà Triệu thể hiện ý chí không khuất phục trước ách đô hộ. Hình tượng Bà Triệu trở thành biểu tượng tiêu biểu của lòng yêu nước và tinh thần kiên cường của phụ nữ Việt Nam."}}
         ]},
        {"id":"hypothesis","type":"HYPOTHESIS","title":"Đặt Giả thuyết","required":true,
         "description":"Chọn giả thuyết giải thích đúng nhất ý nghĩa của khởi nghĩa Bà Triệu.",
         "nextStageIds":["verification"],
         "activities":[
          {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true,
           "instruction":"Chọn giả thuyết giải thích đúng nhất kết quả và ý nghĩa khởi nghĩa",
           "config":{"prompt":"Nhận định nào giải thích đúng nhất kết quả cuộc khởi nghĩa Bà Triệu?",
             "hypotheses":[
               {"id":"h1","label":"Cuộc khởi nghĩa thất bại trước sự đàn áp của Đông Ngô nhưng vẫn khẳng định tinh thần yêu nước, ý chí tự chủ và truyền cảm hứng cho các thế hệ sau."},
               {"id":"h2","label":"Cuộc khởi nghĩa đã chấm dứt thời kì Bắc thuộc vào năm 248."},
               {"id":"h3","label":"Cuộc khởi nghĩa không có ý nghĩa vì không giành được thắng lợi quân sự."}]},
           "feedback":{"COMPLETED":"Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng."}}
         ]},
        {"id":"verification","type":"VERIFICATION","title":"Kiểm chứng Giả thuyết","required":true,
         "description":"Đối chiếu giả thuyết với các tư liệu — chọn bằng chứng hỗ trợ giả thuyết.",
         "nextStageIds":["reconstruction"],
         "activities":[
          {"id":"vf","type":"VERIFICATION","required":true,
           "instruction":"Chọn các tư liệu chứng minh giả thuyết bạn vừa đặt",
           "onPartial":"verification","onContradicted":"hypothesis",
           "config":{
             "expectedHypothesis":"h1",
             "visibleSourceIds":["64000000-0000-4000-8000-000000020101","64000000-0000-4000-8000-000000020102","64000000-0000-4000-8000-000000020103","64000000-0000-4000-8000-000000020104"],
             "requiredEvidenceIds":["64000000-0000-4000-8000-000000020103","64000000-0000-4000-8000-000000020104"],
             "maxAttempts":3},
           "feedback":{"SUPPORTED":"Kiểm chứng thành công! Tư liệu về kết quả đàn áp (E3) và ý nghĩa lịch sử (E4) chứng minh giả thuyết của bạn.","PARTIAL":"Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy bổ sung tư liệu về kết quả đàn áp và ý nghĩa.","CONTRADICTED":"Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.","COMPLETED":"Kiểm chứng hoàn tất — giả thuyết được chứng minh."}}
         ]},
        {"id":"reconstruction","type":"RECONSTRUCTION","title":"Tái hiện Sự kiện","required":true,
         "description":"Sắp xếp lại trình tự diễn biến khởi nghĩa Bà Triệu theo đúng thời gian.",
         "nextStageIds":[],
         "activities":[
          {"id":"do","type":"DRAG_ORDER","required":true,
           "instruction":"Sắp xếp lại diễn biến khởi nghĩa Bà Triệu theo trình tự thời gian",
           "config":{"items":[
             {"id":"s1","label":"Nhà Đông Ngô cai trị hà khắc"},
             {"id":"s2","label":"Bà Triệu và Triệu Quốc Đạt tập hợp lực lượng"},
             {"id":"s3","label":"Khởi nghĩa bùng nổ tại vùng núi Nưa năm 248"},
             {"id":"s4","label":"Nhà Đông Ngô cử Lục Dận đàn áp"},
             {"id":"s5","label":"Cuộc khởi nghĩa thất bại, để lại dấu ấn lịch sử"}],
             "expectedOrder":["s1","s2","s3","s4","s5"],"maxAttempts":3},
           "feedback":{"COMPLETED":"Xuất sắc! Tinh thần bất khuất và khát vọng độc lập của Bà Triệu vẫn được ghi nhớ.","PARTIAL":"Một số bước đã đúng — chú ý trình tự: đô hộ → tập hợp → bùng nổ → đàn áp → thất bại.","INCORRECT":"Thứ tự chưa đúng. Hãy bắt đầu từ chính quyền Đông Ngô cai trị hà khắc.","EXHAUSTED":"Đã hết lượt. Trình tự: đô hộ → tập hợp → bùng nổ 248 → Lục Dận đàn áp → thất bại."}}
         ]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }$draft$::jsonb;

    INSERT INTO lessons (id, event_id, template_id, title, central_question,
        objectives_json, draft_json, status, created_by, updated_by)
    VALUES (les_bt, evt_bt, tpl_fs,
        'Khởi nghĩa Bà Triệu năm 248',
        'Vì sao cuộc khởi nghĩa Bà Triệu thất bại nhưng vẫn có ý nghĩa lớn đối với lịch sử dân tộc?',
        '["Nắm được bối cảnh đô hộ Đông Ngô","Xác định nhân vật Bà Triệu","Theo dõi diễn biến 248","Đánh giá ý nghĩa lịch sử"]'::jsonb,
        d, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO UPDATE SET
        event_id=EXCLUDED.event_id, template_id=EXCLUDED.template_id,
        title=EXCLUDED.title, central_question=EXCLUDED.central_question,
        objectives_json=EXCLUDED.objectives_json, draft_json=EXCLUDED.draft_json,
        updated_by=sys_user, updated_at=now();

    -- =========================================================================
    -- 5. LESSON 3 — LÝ BÍ / VẠN XUÂN (FOUR_STEP draft)
    -- =========================================================================
    d := $draft${
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Lý Bí phát động khởi nghĩa 542 và lập nước Vạn Xuân năm 544",
        "Vạn Xuân là bước từ khởi nghĩa sang xây dựng nhà nước độc lập",
        "Nhà nước Vạn Xuân duy trì đến 602 dưới Triệu Quang Phục"
      ],
      "stages": [
        {"id":"discovery","type":"DISCOVERY","title":"Truy tìm Dấu vết","required":true,
         "allowFreeOrder":true,
         "description":"Khám phá bốn dấu vết về khởi nghĩa Lý Bí và nhà nước Vạn Xuân theo bất kỳ thứ tự nào.",
         "nextStageIds":["hypothesis"],
         "activities":[
          {"id":"clue-context","type":"READ","required":true,"clueType":"CONTEXT",
           "title":"Ách đô hộ nhà Lương",
           "description":"Bối cảnh cai trị của nhà Lương thế kỷ VI",
           "coverAssetId":null,
           "instruction":"Đọc bối cảnh bùng nổ khởi nghĩa Lý Bí",
           "config":{"text":"Thế kỷ VI, chính quyền nhà Lương cai trị hà khắc tại Giao Châu. Lý Bí tập hợp hào kiệt và nhân dân đứng lên khởi nghĩa năm 542, nhanh chóng đánh đổ chính quyền đô hộ ở nhiều nơi."}},
          {"id":"clue-characters","type":"MULTIPLE_CHOICE","required":true,"clueType":"CHARACTERS",
           "title":"Người lên ngôi Vạn Xuân",
           "description":"Xác định người đặt quốc hiệu Vạn Xuân",
           "coverAssetId":null,
           "instruction":"Chọn người lên ngôi hoàng đế và đặt quốc hiệu Vạn Xuân năm 544",
           "config":{"graded":true,
             "question":"Ai là người lên ngôi hoàng đế và đặt quốc hiệu Vạn Xuân năm 544?",
             "options":[
               {"id":"c-a","label":"Triệu Quang Phục"},
               {"id":"c-b","label":"Ngô Quyền"},
               {"id":"c-c","label":"Lý Bí"},
               {"id":"c-d","label":"Trần Bá Tiên"}],
             "correctOptionIds":["c-c"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng! Lý Bí lên ngôi, lấy hiệu Lý Nam Đế và đặt quốc hiệu Vạn Xuân năm 544.","INCORRECT":"Chưa đúng — người lên ngôi là Lý Bí.","EXHAUSTED":"Đáp án: Lý Bí."}},
          {"id":"clue-development","type":"READ","required":true,"clueType":"DEVELOPMENT",
           "title":"Từ khởi nghĩa đến nhà nước",
           "description":"Diễn biến 542–602",
           "coverAssetId":null,
           "instruction":"Đọc diễn biến khởi nghĩa Lý Bí và nhà nước Vạn Xuân",
           "config":{"text":"Sau thắng lợi năm 542–543, Lý Bí thành lập nước Vạn Xuân năm 544. Khi nhà Lương phản công năm 545, cuộc kháng chiến gặp khó khăn. Lý Nam Đế qua đời năm 548. Triệu Quang Phục tiếp tục kháng chiến ở Dạ Trạch, giành thắng lợi năm 550. Đến năm 602, nhà Tùy xâm lược và nhà nước Vạn Xuân kết thúc."}},
          {"id":"clue-significance","type":"MULTIPLE_CHOICE","required":true,"clueType":"SIGNIFICANCE",
           "title":"Ý nghĩa quốc hiệu",
           "description":"Ý nghĩa của tên nước Vạn Xuân",
           "coverAssetId":null,
           "instruction":"Chọn phát biểu mô tả đúng ý nghĩa của quốc hiệu Vạn Xuân",
           "config":{"graded":true,
             "question":"Quốc hiệu Vạn Xuân thể hiện mong muốn gì?",
             "options":[
               {"id":"s-a","label":"Đất nước độc lập và trường tồn"},
               {"id":"s-b","label":"Chinh phục các quốc gia lân cận"},
               {"id":"s-c","label":"Trở thành một quận của nhà Lương"},
               {"id":"s-d","label":"Chấm dứt mọi hoạt động thương mại"}],
             "correctOptionIds":["s-a"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Chính xác! Vạn Xuân thể hiện mong muốn đất nước độc lập và trường tồn.","INCORRECT":"Chưa đúng — quốc hiệu thể hiện mong muốn độc lập trường tồn.","EXHAUSTED":"Đáp án: đất nước độc lập và trường tồn."}}
         ]},
        {"id":"hypothesis","type":"HYPOTHESIS","title":"Đặt Giả thuyết","required":true,
         "description":"Chọn giả thuyết giải thích đúng nhất ý nghĩa việc thành lập Vạn Xuân.",
         "nextStageIds":["verification"],
         "activities":[
          {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true,
           "instruction":"Chọn giả thuyết giải thích đúng nhất ý nghĩa thành lập Vạn Xuân",
           "config":{"prompt":"Vì sao việc Lý Bí thành lập nước Vạn Xuân là một bước phát triển quan trọng?",
             "hypotheses":[
               {"id":"h1","label":"Việc thành lập Vạn Xuân cho thấy cuộc đấu tranh không chỉ nhằm đánh đuổi chính quyền đô hộ, mà còn hướng tới xây dựng một nhà nước độc lập, tự chủ."},
               {"id":"h2","label":"Lý Bí chỉ tổ chức một cuộc nổi dậy ngắn mà không thành lập chính quyền."},
               {"id":"h3","label":"Nước Vạn Xuân được thành lập sau chiến thắng Bạch Đằng năm 938."}]},
           "feedback":{"COMPLETED":"Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng."}}
         ]},
        {"id":"verification","type":"VERIFICATION","title":"Kiểm chứng Giả thuyết","required":true,
         "description":"Đối chiếu giả thuyết với các tư liệu — chọn bằng chứng hỗ trợ giả thuyết.",
         "nextStageIds":["reconstruction"],
         "activities":[
          {"id":"vf","type":"VERIFICATION","required":true,
           "instruction":"Chọn các tư liệu chứng minh giả thuyết bạn vừa đặt",
           "onPartial":"verification","onContradicted":"hypothesis",
           "config":{
             "expectedHypothesis":"h1",
             "visibleSourceIds":["64000000-0000-4000-8000-000000030101","64000000-0000-4000-8000-000000030102","64000000-0000-4000-8000-000000030103","64000000-0000-4000-8000-000000030104"],
             "requiredEvidenceIds":["64000000-0000-4000-8000-000000030102","64000000-0000-4000-8000-000000030103"],
             "maxAttempts":3},
           "feedback":{"SUPPORTED":"Kiểm chứng thành công! Thắng lợi 542–543 (E2) và việc lập Vạn Xuân 544 (E3) chứng minh bước sang xây dựng nhà nước.","PARTIAL":"Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy bổ sung tư liệu về thắng lợi 542–543 và việc lập Vạn Xuân.","CONTRADICTED":"Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.","COMPLETED":"Kiểm chứng hoàn tất — giả thuyết được chứng minh."}}
         ]},
        {"id":"reconstruction","type":"RECONSTRUCTION","title":"Tái hiện Sự kiện","required":true,
         "description":"Sắp xếp lại trình tự diễn biến từ khởi nghĩa đến nhà nước Vạn Xuân.",
         "nextStageIds":[],
         "activities":[
          {"id":"do","type":"DRAG_ORDER","required":true,
           "instruction":"Sắp xếp lại diễn biến từ khởi nghĩa đến nhà nước Vạn Xuân",
           "config":{"items":[
             {"id":"s1","label":"Lý Bí phát động khởi nghĩa năm 542"},
             {"id":"s2","label":"Nghĩa quân tiếp tục đánh bại quân Lương năm 543"},
             {"id":"s3","label":"Thành lập nước Vạn Xuân năm 544"},
             {"id":"s4","label":"Nhà Lương phản công năm 545"},
             {"id":"s5","label":"Triệu Quang Phục tiếp tục kháng chiến, thắng lợi năm 550"},
             {"id":"s6","label":"Nhà Tùy xâm lược, Vạn Xuân kết thúc năm 602"}],
             "expectedOrder":["s1","s2","s3","s4","s5","s6"],"maxAttempts":3},
           "feedback":{"COMPLETED":"Xuất sắc! Nhà nước Vạn Xuân là biểu hiện nổi bật của khát vọng xây dựng quốc gia độc lập, tự chủ.","PARTIAL":"Một số bước đã đúng — chú ý trình tự 542→543→544→545→550→602.","INCORRECT":"Thứ tự chưa đúng. Hãy bắt đầu từ khởi nghĩa năm 542.","EXHAUSTED":"Đã hết lượt. Trình tự: 542 khởi nghĩa → 543 thắng → 544 Vạn Xuân → 545 phản công → 550 Triệu Quang Phục → 602 kết thúc."}}
         ]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }$draft$::jsonb;

    INSERT INTO lessons (id, event_id, template_id, title, central_question,
        objectives_json, draft_json, status, created_by, updated_by)
    VALUES (les_lb, evt_lb, tpl_fs,
        'Khởi nghĩa Lý Bí và nhà nước Vạn Xuân',
        'Vì sao việc Lý Bí thành lập nước Vạn Xuân là một bước phát triển quan trọng của cuộc đấu tranh giành độc lập?',
        '["Nắm được bối cảnh đô hộ nhà Lương","Theo dõi các mốc 542–602","Đánh giá ý nghĩa xây dựng nhà nước"]'::jsonb,
        d, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO UPDATE SET
        event_id=EXCLUDED.event_id, template_id=EXCLUDED.template_id,
        title=EXCLUDED.title, central_question=EXCLUDED.central_question,
        objectives_json=EXCLUDED.objectives_json, draft_json=EXCLUDED.draft_json,
        updated_by=sys_user, updated_at=now();

    -- =========================================================================
    -- 6. LESSON 4 — BẠCH ĐẰNG 938 (FOUR_STEP draft — bài demo trọng tâm)
    --    Animation: gắn animationSceneId của production scene PUBLISHED vào
    --    dấu vết Bối cảnh (khám phá thủy triều) — đúng contract validator.
    -- =========================================================================
    d := $draft${
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Nguyên nhân cuộc xâm lược Nam Hán: Kiều Công Tiễn cầu cứu năm 937",
        "Ngô Quyền kết hợp địa hình, thủy triều, trận địa cọc và kế sách nhử địch",
        "Thắng lợi 938 → Ngô Quyền xưng vương 939 → độc lập lâu dài"
      ],
      "stages": [
        {"id":"discovery","type":"DISCOVERY","title":"Truy tìm Dấu vết","required":true,
         "allowFreeOrder":true,
         "description":"Khám phá bốn dấu vết về chiến thắng Bạch Đằng năm 938 — tìm hiểu vì sao Ngô Quyền biến sông Bạch Đằng thành lợi thế quyết định.",
         "nextStageIds":["hypothesis"],
         "activities":[
          {"id":"clue-context","type":"READ","required":true,"clueType":"CONTEXT",
           "title":"Khám phá chiến trường sông Bạch Đằng",
           "description":"Địa hình cửa sông và quy luật thủy triều",
           "coverAssetId":null,
           "instruction":"Khám phá đặc điểm dòng sông Bạch Đằng và thủy triều",
           "config":{"text":"Sông Bạch Đằng là tuyến đường thủy quan trọng với khu vực cửa sông chịu ảnh hưởng của thủy triều. Mực nước thay đổi theo thời điểm, làm thay đổi điều kiện di chuyển của thuyền chiến. Ngô Quyền nhận thấy có thể khai thác yếu tố tự nhiên này khi chuẩn bị chống quân Nam Hán.",
                     "animationSceneId":"d7a80000-0000-4000-8000-000000000001",
                     "playbackMode":"INTERACTIVE"}},
          {"id":"clue-characters","type":"MULTIPLE_CHOICE","required":true,"clueType":"CHARACTERS",
           "title":"Ngô Quyền trước cuộc xâm lược",
           "description":"Bối cảnh chính trị 937–938",
           "coverAssetId":null,
           "instruction":"Chọn lý do Ngô Quyền phải chuẩn bị đối phó với quân Nam Hán năm 938",
           "config":{"graded":true,
             "question":"Vì sao Ngô Quyền phải chuẩn bị đối phó với quân Nam Hán năm 938?",
             "options":[
               {"id":"c-a","label":"Vì Kiều Công Tiễn cầu cứu nhà Nam Hán sau khi sát hại Dương Đình Nghệ"},
               {"id":"c-b","label":"Vì Ngô Quyền muốn tiến quân chinh phục Nam Hán"},
               {"id":"c-c","label":"Vì nhà Nam Hán đã trao quyền tự chủ cho Ngô Quyền"},
               {"id":"c-d","label":"Vì nhà Lương vừa đưa quân sang Giao Châu"}],
             "correctOptionIds":["c-a"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng! Kiều Công Tiễn cầu cứu Nam Hán sau khi sát hại Dương Đình Nghệ; Ngô Quyền vừa giải quyết tình hình trong nước vừa chuẩn bị chống xâm lược.","INCORRECT":"Chưa đúng — nguyên nhân là Kiều Công Tiễn cầu cứu Nam Hán.","EXHAUSTED":"Đáp án: Kiều Công Tiễn cầu cứu nhà Nam Hán."}},
          {"id":"clue-development","type":"READ","required":true,"clueType":"DEVELOPMENT",
           "title":"Trận địa cọc và bước ngoặt",
           "description":"Trận địa cọc ngầm và thủy triều",
           "coverAssetId":null,
           "instruction":"Đọc về trận địa cọc và cách thủy triều tạo bước ngoặt",
           "config":{"text":"Quân ta chuẩn bị trận địa cọc ngầm trên sông Bạch Đằng. Khi thủy triều lên, cọc bị nước che khuất. Thuyền nhẹ của quân ta nhử đội thuyền Nam Hán tiến vào khu vực phục kích. Khi thủy triều rút, quân ta phản công, khiến thuyền địch rơi vào thế bất lợi."}},
          {"id":"clue-significance","type":"MULTIPLE_CHOICE","required":true,"clueType":"SIGNIFICANCE",
           "title":"Bước ngoặt độc lập",
           "description":"Ý nghĩa lịch sử của chiến thắng",
           "coverAssetId":null,
           "instruction":"Chọn phát biểu mô tả đúng ý nghĩa lịch sử của chiến thắng Bạch Đằng năm 938",
           "config":{"graded":true,
             "question":"Ý nghĩa lịch sử quan trọng nhất của chiến thắng Bạch Đằng năm 938 là gì?",
             "options":[
               {"id":"s-a","label":"Đánh dấu sự ra đời nước Vạn Xuân"},
               {"id":"s-b","label":"Đánh bại Nam Hán, mở ra thời kì độc lập tự chủ lâu dài"},
               {"id":"s-c","label":"Mở đầu cuộc khởi nghĩa Hai Bà Trưng"},
               {"id":"s-d","label":"Đánh dấu việc nhà Đông Ngô chấm dứt cai trị năm 248"}],
             "correctOptionIds":["s-b"],"maxAttempts":2},
           "feedback":{"COMPLETED":"Chính xác! Chiến thắng Bạch Đằng năm 938 mở ra thời kì độc lập lâu dài; năm 939 Ngô Quyền xưng vương.","INCORRECT":"Chưa đúng — ý nghĩa lớn nhất là mở ra thời kì độc lập lâu dài.","EXHAUSTED":"Đáp án: đánh bại Nam Hán, mở ra thời kì độc lập tự chủ lâu dài."}}
         ]},
        {"id":"hypothesis","type":"HYPOTHESIS","title":"Đặt Giả thuyết","required":true,
         "description":"Chọn giả thuyết giải thích hợp lý nhất chiến thắng của Ngô Quyền.",
         "nextStageIds":["verification"],
         "activities":[
          {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true,
           "instruction":"Chọn giả thuyết giải thích hợp lý nhất chiến thắng trên sông Bạch Đằng",
           "config":{"prompt":"Yếu tố nào giải thích hợp lý nhất chiến thắng của Ngô Quyền trên sông Bạch Đằng?",
             "hypotheses":[
               {"id":"h1","label":"Ngô Quyền kết hợp địa hình, thủy triều, trận địa cọc ngầm và kế sách nhử địch để tạo lợi thế quyết định."},
               {"id":"h2","label":"Quân Nam Hán thất bại hoàn toàn chỉ vì gặp bão lớn trước khi tiến vào sông."},
               {"id":"h3","label":"Ngô Quyền chiến thắng chỉ vì quân số lớn hơn, không cần lợi dụng địa hình."},
               {"id":"h4","label":"Việc đóng cọc dưới sông là yếu tố duy nhất giải thích toàn bộ chiến thắng."}]},
           "feedback":{"COMPLETED":"Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng. Lưu ý: giả thuyết chỉ xem xét một yếu tố đơn lẻ là chưa đủ."}}
         ]},
        {"id":"verification","type":"VERIFICATION","title":"Kiểm chứng Giả thuyết","required":true,
         "description":"Đối chiếu giả thuyết với các tư liệu — chọn bằng chứng hỗ trợ giả thuyết.",
         "nextStageIds":["reconstruction"],
         "activities":[
          {"id":"vf","type":"VERIFICATION","required":true,
           "instruction":"Chọn các tư liệu chứng minh giả thuyết bạn vừa đặt",
           "onPartial":"verification","onContradicted":"hypothesis",
           "config":{
             "expectedHypothesis":"h1",
             "visibleSourceIds":["64000000-0000-4000-8000-000000040101","64000000-0000-4000-8000-000000040102","64000000-0000-4000-8000-000000040103","64000000-0000-4000-8000-000000040104"],
             "requiredEvidenceIds":["64000000-0000-4000-8000-000000040101","64000000-0000-4000-8000-000000040102","64000000-0000-4000-8000-000000040103"],
             "maxAttempts":3},
           "feedback":{"SUPPORTED":"Kiểm chứng thành công! Mối liên hệ giữa dòng nước, trận địa cọc và thời điểm phản công đã được chứng minh đầy đủ.","PARTIAL":"Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy bổ sung tư liệu về địa hình/thủy triều, trận địa cọc và kế sách nhử địch.","CONTRADICTED":"Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.","COMPLETED":"Kiểm chứng hoàn tất — giả thuyết được chứng minh."}}
         ]},
        {"id":"reconstruction","type":"RECONSTRUCTION","title":"Tái hiện Sự kiện","required":true,
         "description":"Sắp xếp lại trình tự diễn biến trận Bạch Đằng năm 938 theo đúng diễn tiến.",
         "nextStageIds":[],
         "activities":[
          {"id":"do","type":"DRAG_ORDER","required":true,
           "instruction":"Sắp xếp lại diễn biến trận Bạch Đằng năm 938 theo đúng diễn tiến",
           "config":{"items":[
             {"id":"s1","label":"Ngô Quyền chuẩn bị lực lượng và trận địa cọc trên sông"},
             {"id":"s2","label":"Khi nước dâng che khuất bãi cọc, quân ta dùng thuyền nhẹ nhử quân Nam Hán tiến vào"},
             {"id":"s3","label":"Quân Nam Hán đuổi theo, tiến sâu vào khu vực phục kích"},
             {"id":"s4","label":"Thủy triều rút, quân ta chuyển sang phản công"},
             {"id":"s5","label":"Thuyền địch mắc cọc và chịu đòn tấn công từ quân ta"},
             {"id":"s6","label":"Quân Nam Hán đại bại, Lưu Hoằng Tháo tử trận"}],
             "expectedOrder":["s1","s2","s3","s4","s5","s6"],"maxAttempts":3},
           "feedback":{"COMPLETED":"Em đã tái hiện đúng chiến thắng Bạch Đằng! Sự phối hợp giữa địa hình, thủy triều, trận địa cọc và kế sách nhử địch đã tạo nên thắng lợi năm 938.","PARTIAL":"Một số bước đã đúng — chú ý trình tự: chuẩn bị → nhử địch → địch vào → triều rút phản công → mắc cọc → đại bại.","INCORRECT":"Thứ tự chưa đúng. Hãy bắt đầu từ khâu chuẩn bị lực lượng và trận địa cọc.","EXHAUSTED":"Đã hết lượt. Trình tự: chuẩn bị trận địa → triều lên nhử địch → địch tiến vào → triều rút phản công → mắc cọc → Lưu Hoằng Tháo tử trận."}}
         ]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }$draft$::jsonb;

    IF asset_bach_dang_coc IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,0,coverAssetId}',to_jsonb(asset_bach_dang_coc::text),true);
    END IF;
    IF asset_ngoquyen_hero IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,1,coverAssetId}',to_jsonb(asset_ngoquyen_hero::text),true);
    END IF;
    IF asset_tran_dia_coc IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,2,coverAssetId}',to_jsonb(asset_tran_dia_coc::text),true);
    END IF;
    IF asset_thu_phong IS NOT NULL THEN
        d := jsonb_set(d,'{stages,0,activities,3,coverAssetId}',to_jsonb(asset_thu_phong::text),true);
    END IF;

    UPDATE lessons
    SET event_id=evt_bd, template_id=tpl_fs,
        title='Chiến thắng Bạch Đằng và sự nghiệp Ngô Quyền',
        central_question='Ngô Quyền đã biến điều kiện tự nhiên của sông Bạch Đằng thành lợi thế quyết định để đánh bại thủy quân Nam Hán như thế nào?',
        objectives_json='["Nguyên nhân cuộc xâm lược Nam Hán","Vai trò của Ngô Quyền","Địa hình và thủy triều","Trận địa cọc và kế sách nhử địch","Thắng lợi 938 và xưng vương 939","Ý nghĩa đối với nền độc lập lâu dài"]'::jsonb,
        draft_json=d, updated_by=sys_user, updated_at=now()
    WHERE id = les_bd;

    -- =========================================================================
    -- 7. ARCHIVE các lesson cũ trùng chủ đề (không còn dùng làm demo chính).
    --    Chỉ archive khi: cùng event, không có attempt, và id nằm trong danh
    --    sách lesson cũ đã audit (không quét mù). Giữ nguyên lesson_versions.
    -- =========================================================================
    -- BT/LB/HBT: các lesson HISTORY_INVESTIGATION cũ không còn là demo chính
    -- → ARCHIVE (không xoá, giữ lịch sử). BD tái sử dụng lesson canonical
    -- d7b20000 nên không archive. Chỉ archive khi không có attempt.
    UPDATE lessons l
    SET status='ARCHIVED', updated_by=sys_user, updated_at=now()
    WHERE l.event_id IN (evt_bt, evt_lb, evt_hbt)
      AND l.status='PUBLISHED'
      AND l.id <> ALL (ARRAY[les_bt, les_lb, les_hbt, les_bd])
      AND NOT EXISTS (
        SELECT 1 FROM learner_attempts la
        JOIN lesson_versions lv ON lv.id=la.lesson_version_id
        WHERE lv.lesson_id=l.id);

    -- =========================================================================
    -- 8. COMPLETION POLICY — event cần 1 lesson required.
    --    BT/LB/HBT: archive policy cũ → policy_version mới trỏ lesson FOUR_STEP.
    --    BD đã trỏ đúng lesson canonical (giữ nguyên).
    -- =========================================================================
    UPDATE event_completion_policies
    SET status='ARCHIVED'
    WHERE event_id IN (evt_bt, evt_lb, evt_hbt) AND status='PUBLISHED';

    INSERT INTO event_completion_policies
        (id, event_id, policy_version, status, required_lesson_ids,
         optional_lesson_ids, mastery_threshold, published_at)
    SELECT gen_random_uuid(), e,
           COALESCE((SELECT max(policy_version) FROM event_completion_policies WHERE event_id=e),0)+1,
           'PUBLISHED', to_jsonb(ARRAY[l]), '[]'::jsonb, 70, now()
    FROM (VALUES (evt_bt,les_bt),(evt_lb,les_lb),(evt_hbt,les_hbt)) AS t(e,l)
    WHERE NOT EXISTS (SELECT 1 FROM event_completion_policies p
                      WHERE p.event_id=t.e AND p.status='PUBLISHED'
                        AND p.required_lesson_ids = to_jsonb(ARRAY[t.l]));

    -- =========================================================================
    -- 9. LEARNING PATH — DEMO_BAC_THUOC (DRAFT, publish sau khi 4 lesson
    --    được publish bởi LessonPublishService).
    -- =========================================================================
    INSERT INTO learning_path_versions (id, path_code, version_no, title, description, status)
    VALUES (path_id,'DEMO_BAC_THUOC',1,
            'Hành trình giành độc lập — Bốn dấu mốc lịch sử',
            'Lộ trình demo thời kỳ Bắc thuộc: Hai Bà Trưng → Bà Triệu → Lý Bí/Vạn Xuân → Ngô Quyền/Bạch Đằng.',
            'DRAFT')
    ON CONFLICT (path_code, version_no) DO NOTHING;
    SELECT id INTO path_id FROM learning_path_versions
      WHERE path_code='DEMO_BAC_THUOC' AND version_no=path_ver;

    INSERT INTO learning_path_chapters
        (id, path_version_id, code, title, description, start_year, end_year,
         period_label, sort_order, theme_key)
    VALUES (chap_id, path_id,'NORTHERN_DOMINATION',
            'Bắc thuộc và đấu tranh giành độc lập',
            'Bốn dấu mốc đấu tranh giành độc lập từ năm 40 đến 939.',
            40, 939, 'Năm 40 – 939', 1, 'NORTHERN_DOMINATION')
    ON CONFLICT (path_version_id, code) DO NOTHING;
    SELECT id INTO chap_id FROM learning_path_chapters
      WHERE path_version_id=path_id AND code='NORTHERN_DOMINATION';

    -- Event nodes: 4 sự kiện theo thứ tự thời gian.
    PERFORM 1;
    INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order)
    SELECT gen_random_uuid(), chap_id, path_id, e, s
    FROM (VALUES (evt_hbt,1),(evt_bt,2),(evt_lb,3),(evt_bd,4)) AS t(e,s)
    ON CONFLICT (path_version_id, event_id) DO NOTHING;

    -- Lesson nodes: mỗi event gắn đúng lesson FOUR_STEP chính.
    INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
    SELECT gen_random_uuid(), en.id, en.event_id, t.les, 1
    FROM learning_path_event_nodes en
    JOIN (VALUES (evt_hbt,les_hbt),(evt_bt,les_bt),(evt_lb,les_lb),(evt_bd,les_bd)) AS t(ev,les)
      ON en.event_id = t.ev
    WHERE en.path_version_id = path_id
    ON CONFLICT (event_node_id, lesson_id) DO NOTHING;

END $$;

-- Post-assertions: fail the migration rõ ràng nếu post-conditions sai.
DO $$
BEGIN
    IF (SELECT count(*) FROM evidences WHERE id::text LIKE '64000000-0000-4000-8000-0000000%') < 16 THEN
        RAISE EXCEPTION 'Expected >=16 demo evidences, found %',
            (SELECT count(*) FROM evidences WHERE id::text LIKE '64000000-0000-4000-8000-0000000%');
    END IF;
    IF (SELECT count(*) FROM lessons WHERE template_id IN (SELECT id FROM lesson_templates WHERE code='FOUR_STEP')) < 4 THEN
        RAISE WARNING 'Expected >=4 FOUR_STEP lessons (found %)',
            (SELECT count(*) FROM lessons WHERE template_id IN (SELECT id FROM lesson_templates WHERE code='FOUR_STEP'));
    END IF;
END $$;
