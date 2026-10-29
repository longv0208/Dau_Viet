-- Dấu Việt | V51 | Upgrade 4 published lessons to the 4-phase learning chain (Issue #35)
-- Phases:
--   0. Bối cảnh lịch sử (CONTEXT -> READ)
--   1. Khám phá 4 Dấu Vết (EVIDENCE -> EVIDENCE_SELECT, graded:true, 4 groups: Hiện vật / Địa hình / Nhân vật / Cổ thư)
--   2. Đặt giả thuyết & Kiểm chứng (HYPOTHESIS -> HYPOTHESIS_CHOICE, VERIFICATION -> VERIFICATION)
--   3. Dựng lại sự kiện (RECONSTRUCTION -> DRAG_ORDER, maxAttempts:3)
--   4. Kết luận CER (CONCLUSION -> CER_CHOICE, acceptedCombos, maxAttempts:3)
--
-- Idempotent: ON CONFLICT guards on users, evidences, lesson_versions;
-- trg_lesson_versions_immutable disabled during migration and re-enabled at the end.

ALTER TABLE lesson_versions DISABLE TRIGGER trg_lesson_versions_immutable;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    -- Canonical Lesson IDs (existing rows from V20 & V29)
    les_bd  UUID := 'd7b20000-0000-4000-8000-000000000001';
    les_hbt UUID := '10000000-0000-0000-0000-000000000002';
    les_nn  UUID := '10000000-0000-0000-0000-000000000003';
    les_dbp UUID := '10000000-0000-0000-0000-000000000004';

    -- Event IDs (resolved from lessons / historical_events)
    evt_bd  UUID;
    evt_hbt UUID;
    evt_nn  UUID;
    evt_dbp UUID;

    -- New Lesson Version v2 IDs
    ver_bd_v2  UUID := '51000000-0000-4000-8000-000000000001';
    ver_hbt_v2 UUID := '51000000-0000-4000-8000-000000000002';
    ver_nn_v2  UUID := '51000000-0000-4000-8000-000000000003';
    ver_dbp_v2 UUID := '51000000-0000-4000-8000-000000000004';

    -- Optional thematic asset IDs (seeded in V50)
    asset_me_linh       UUID;
    asset_bach_dang_coc UUID;
    asset_nhu_nguyet    UUID;
    asset_dien_bien     UUID;
    asset_tran_dia_coc  UUID;
    asset_doanh_trai    UUID;
    asset_thu_phong     UUID;
    asset_ngoquyen_hero UUID;

    -- Draft JSON payloads
    d_bd  JSONB;
    d_hbt JSONB;
    d_nn  JSONB;
    d_dbp JSONB;
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- Resolve owning event_id from existing lessons (with slug/UUID fallback)
    SELECT event_id INTO evt_bd FROM lessons WHERE id = les_bd;
    IF evt_bd IS NULL THEN
        SELECT id INTO evt_bd FROM historical_events WHERE slug = 'bach-dang-938' LIMIT 1;
    END IF;

    SELECT event_id INTO evt_hbt FROM lessons WHERE id = les_hbt;
    IF evt_hbt IS NULL THEN
        SELECT id INTO evt_hbt FROM historical_events WHERE id = '00000000-0000-0000-0000-000000000002'::uuid;
    END IF;

    SELECT event_id INTO evt_nn FROM lessons WHERE id = les_nn;
    IF evt_nn IS NULL THEN
        SELECT id INTO evt_nn FROM historical_events WHERE id = '00000000-0000-0000-0000-000000000003'::uuid;
    END IF;

    SELECT event_id INTO evt_dbp FROM lessons WHERE id = les_dbp;
    IF evt_dbp IS NULL THEN
        SELECT id INTO evt_dbp FROM historical_events WHERE id = '00000000-0000-0000-0000-000000000004'::uuid;
    END IF;

    -- Resolve thematic assets if present (from V50)
    SELECT id INTO asset_me_linh       FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000002'::uuid;
    SELECT id INTO asset_bach_dang_coc FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000003'::uuid;
    SELECT id INTO asset_nhu_nguyet    FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000005'::uuid;
    SELECT id INTO asset_dien_bien     FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000006'::uuid;
    SELECT id INTO asset_tran_dia_coc  FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000008'::uuid;
    SELECT id INTO asset_doanh_trai    FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000009'::uuid;
    SELECT id INTO asset_thu_phong     FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000010'::uuid;
    SELECT id INTO asset_ngoquyen_hero FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000011'::uuid;

    -- =========================================================================
    -- 1. UPSERT 16 GROUP EVIDENCES (4 per lesson: Hiện vật / Địa hình / Nhân vật / Cổ thư)
    -- =========================================================================
    INSERT INTO evidences (
        id, event_id, title, evidence_type, description,
        source_title, source_author, source_citation,
        reliability, relevance, asset_id, status, created_by, created_at, updated_at
    ) VALUES
    -- 1.1 Bạch Đằng 938 (evt_bd)
    (
        '51000000-0000-4000-8000-000000000101'::uuid,
        evt_bd,
        '[Hiện vật] Cọc gỗ lim bịt sắt khai quật tại bãi cọc Bạch Đằng',
        'HISTORICAL_TEXT',
        'Hệ thống cọc gỗ lim vát nhọn đầu, bịt sắt đóng ngầm dưới lòng sông Bạch Đằng nhằm đâm thủng và chặn đứng chiến thuyền lớn của quân Nam Hán khi thủy triều rút.',
        'Bảo tàng Lịch sử Quốc gia',
        'Viện Khảo cổ học',
        'Hồ sơ di tích bãi cọc Yên Giang — Quảng Yên, Quảng Ninh',
        'HIGH',
        'Hiện vật khảo cổ xác thực trận địa cọc ngầm trên sông Bạch Đằng',
        asset_tran_dia_coc,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000102'::uuid,
        evt_bd,
        '[Địa hình] Cửa sông Bạch Đằng và chế độ nhật triều vịnh Bắc Bộ',
        'HISTORICAL_TEXT',
        'Cửa sông Bạch Đằng có lòng sông rộng, hai bờ rừng rậm hiểm trở và biên độ nhật triều chênh lệch 3–4m; khi triều lên mênh mông che kín bãi cọc, khi triều rút nước chảy xiết.',
        'Viện Sử học & Địa chí Quảng Ninh',
        NULL,
        'Khảo cứu địa hình quân sự cửa sông Bạch Đằng thế kỷ X',
        'HIGH',
        'Điều kiện tự nhiên quyết định thời cơ nhử địch và phản công',
        asset_bach_dang_coc,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000103'::uuid,
        evt_bd,
        '[Nhân vật] Ngô Quyền và mưu kế nhử thủy quân Lưu Hoằng Tháo',
        'HISTORICAL_TEXT',
        'Ngô Quyền nhận định Lưu Hoằng Tháo là tướng trẻ kiêu ngạo, dẫn quân đi xa mỏi mệt; ông sai thuyền nhẹ ra khiêu chiến rồi giả thua nhử địch vượt qua bãi cọc đúng lúc triều đang dâng.',
        'Đại Việt sử ký toàn thư',
        'Ngô Sĩ Liên',
        'Ngoại kỷ, Quyển V — Kỷ nhà Ngô',
        'HIGH',
        'Vai trò chỉ huy và nghệ thuật nắm bắt tâm lý tướng giặc của Ngô Quyền',
        asset_ngoquyen_hero,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000104'::uuid,
        evt_bd,
        '[Cổ thư] Đại Việt sử ký toàn thư chép diễn biến đại thắng Bạch Đằng',
        'HISTORICAL_TEXT',
        'Sử cũ ghi: "Quyền sai người lấy gỗ vạt nhọn đầu, bịt sắt, đóng ngầm ở trước cửa biển... Thủy triều rút rất gấp, thuyền giặc vướng vào cọc mà lật úp, rối loạn tan vỡ, Hoằng Tháo chết trận."',
        'Đại Việt sử ký toàn thư — Kỷ nhà Ngô',
        'Ngô Sĩ Liên',
        'Đại Việt sử ký toàn thư, Ngoại kỷ Quyển V',
        'HIGH',
        'Tư liệu chính sử ghi chép toàn cảnh kết cục trận Bạch Đằng năm 938',
        asset_thu_phong,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),

    -- 1.2 Khởi nghĩa Hai Bà Trưng năm 40 (evt_hbt)
    (
        '51000000-0000-4000-8000-000000000201'::uuid,
        evt_hbt,
        '[Hiện vật] Trống đồng Mê Linh và vũ khí đồng thau thời Hai Bà Trưng',
        'HISTORICAL_TEXT',
        'Trống đồng cùng giáo, lao, dao găm đồng thau tìm thấy tại vùng Mê Linh — biểu tượng quyền lực của thủ lĩnh Lạc tướng và hiệu lệnh tập hợp nghĩa quân khắp các bộ lạc.',
        'Bảo tàng Lịch sử Quốc gia',
        'Viện Khảo cổ học',
        'Sưu tập hiện vật văn hóa Đông Sơn muộn — Mê Linh, Hà Nội',
        'HIGH',
        'Hiện vật minh chứng nền tảng văn hóa và sức mạnh quân sự bản địa Lạc Việt',
        asset_me_linh,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000202'::uuid,
        evt_hbt,
        '[Địa hình] Cửa sông Hát (Hát Môn), căn cứ Mê Linh và trị sở Luy Lâu',
        'HISTORICAL_TEXT',
        'Cửa sông Hát (nơi sông Đáy tách khỏi sông Hồng) kết nối đường thủy từ căn cứ Mê Linh tiến đánh Cổ Loa và bao vây thẳng trị sở Luy Lâu của chính quyền Đông Hán.',
        'Ban Quản lý Di tích Đền Hai Bà Trưng',
        NULL,
        'Hồ sơ di tích quốc gia đặc biệt Đền Hai Bà Trưng (Mê Linh) và Đền Hát Môn',
        'HIGH',
        'Không gian địa chiến lược giúp nghĩa quân cơ động thần tốc hạ 65 thành trì',
        asset_me_linh,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000203'::uuid,
        evt_hbt,
        '[Nhân vật] Trưng Trắc, Trưng Nhị và mạng lưới nữ tướng Lạc Việt',
        'HISTORICAL_TEXT',
        'Trưng Trắc và Trưng Nhị thuộc dòng dõi Lạc tướng Mê Linh, cùng các nữ tướng Lê Chân, Thánh Thiên, Phùng Thị Chính hiệu triệu hào kiệt và nhân dân bốn quận đồng loạt nổi dậy.',
        'Việt Điện U Linh Tập & Thần tích Hai Bà Trưng',
        'Lý Tế Xuyên',
        'Việt Điện U Linh Tập — Truyện Trưng Thánh Vương',
        'HIGH',
        'Vai trò lãnh đạo của Hai Bà Trưng và sự đồng lòng của các thủ lĩnh Lạc Việt',
        asset_doanh_trai,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000204'::uuid,
        evt_hbt,
        '[Cổ thư] Lời thề Hát Môn và ghi chép 65 thành trì hưởng ứng',
        'HISTORICAL_TEXT',
        'Thiên Nam Ngữ Lục và Đại Việt Sử Ký Toàn Thư ghi lại bốn câu thề tại Hát Môn: "Một xin rửa sạch quốc thù / Hai xin đem lại nghiệp xưa họ Hùng" cùng sự kiện 65 thành Lĩnh Ngoại đều quy phục.',
        'Đại Việt Sử Ký Toàn Thư & Thiên Nam Ngữ Lục',
        'Ngô Sĩ Liên',
        'Đại Việt Sử Ký Toàn Thư, Ngoại kỷ Quyển III — Kỷ Trưng Nữ Vương',
        'HIGH',
        'Tư liệu cổ thư khẳng định mục tiêu tối thượng là khôi phục độc lập dân tộc',
        asset_thu_phong,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),

    -- 1.3 Chiến tuyến sông Như Nguyệt năm 1077 (evt_nn)
    (
        '51000000-0000-4000-8000-000000000301'::uuid,
        evt_nn,
        '[Hiện vật] Lũy đất và bãi cọc tre phòng tuyến sông Như Nguyệt',
        'HISTORICAL_TEXT',
        'Hệ thống lũy đất cao đắp dọc bờ nam kết hợp hàng rào cọc tre đóng dày nhiều lớp dưới bến sông Như Nguyệt tạo thành bức tường thành kiên cố chặn kỵ binh và bộ binh Tống.',
        'Viện Lịch sử Quân sự Việt Nam',
        NULL,
        'Khảo sát di tích phòng tuyến Như Nguyệt — Yên Phong, Bắc Ninh',
        'HIGH',
        'Bằng chứng vật chất về công trình phòng ngự quy mô lớn của quân dân nhà Lý',
        asset_nhu_nguyet,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000302'::uuid,
        evt_nn,
        '[Địa hình] Sông Như Nguyệt (sông Cầu) — hào nước tự nhiên che chở Thăng Long',
        'HISTORICAL_TEXT',
        'Sông Như Nguyệt chặn ngang mọi ngả đường bộ từ biên giới phía bắc tiến về kinh thành Thăng Long; bến đò Như Nguyệt và vùng Tam Giang là điểm quyết chiến chiến lược.',
        'Khâm định Việt sử Thông giám Cương mục',
        'Quốc sử quán triều Nguyễn',
        'Chính biên, Quyển III — Kỷ nhà Lý',
        'HIGH',
        'Giá trị địa quân sự của dòng sông Như Nguyệt trong thế trận bảo vệ kinh đô',
        asset_nhu_nguyet,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000303'::uuid,
        evt_nn,
        '[Nhân vật] Thái úy Lý Thường Kiệt và nghệ thuật chủ động phòng ngự - phản công',
        'HISTORICAL_TEXT',
        'Thái úy Lý Thường Kiệt vừa dùng thủy bộ phối hợp bẻ gãy các đợt vượt sông của Quách Quỳ, vừa dùng đòn tâm lý chiến làm rệu rã sĩ khí địch trước khi tung đòn đêm tập kích quyết định.',
        'Đại Việt Sử Ký Toàn Thư',
        'Ngô Sĩ Liên',
        'Bản kỷ, Quyển III — Kỷ Lý Nhân Tông (1077)',
        'HIGH',
        'Tài thao lược quân sự kết hợp thế trận phòng thủ vững chắc và thời cơ phản công',
        asset_doanh_trai,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000304'::uuid,
        evt_nn,
        '[Cổ thư] Bài thơ thần Nam Quốc Sơn Hà trong Việt Điện U Linh Tập',
        'HISTORICAL_TEXT',
        'Đêm khuya tại đền thờ Trương Hống, Trương Hát bên sông Như Nguyệt vang lên bài thơ: "Nam quốc sơn hà Nam đế cư / Tiệt nhiên định phận tại thiên thư", làm tinh thần quân Lý bừng lên mạnh mẽ.',
        'Việt Điện U Linh Tập & Đại Việt Sử Ký Toàn Thư',
        'Lý Tế Xuyên',
        'Việt Điện U Linh Tập — Truyện Hựu Thuận Vũ Vương & Minh Thánh Vương',
        'HIGH',
        'Cổ thư ghi nhận bản Tuyên ngôn Độc lập đầu tiên và sức mạnh chiến tranh tâm lý',
        asset_thu_phong,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),

    -- 1.4 Chiến dịch Điện Biên Phủ năm 1954 (evt_dbp)
    (
        '51000000-0000-4000-8000-000000000401'::uuid,
        evt_dbp,
        '[Hiện vật] Pháo lựu 105mm và hệ thống giao thông hào vây lấn Điện Biên Phủ',
        'MILITARY_DOCUMENT',
        'Hàng chục khẩu pháo 105mm được bộ đội kéo bằng tay vào hầm pháo kiên cố trên sườn núi, kết hợp hơn 200km hào giao thông và chiến hào vây lấn siết chặt từng cứ điểm địch.',
        'Bảo tàng Chiến thắng Lịch sử Điện Biên Phủ',
        NULL,
        'Hồ sơ hiện vật Pháo lựu 105mm và sơ đồ mạng lưới chiến hào Mường Thanh',
        'HIGH',
        'Hiện vật minh chứng cách khắc chế ưu thế pháo binh và không quân của tập đoàn cứ điểm',
        asset_dien_bien,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000402'::uuid,
        evt_dbp,
        '[Địa hình] Lòng chảo Mường Thanh và cụm cứ điểm Đồi A1 — hầm De Castries',
        'MILITARY_DOCUMENT',
        'Điện Biên Phủ là thung lũng lòng chảo rộng lớn bốn bề núi cao bao bọc; quân Pháp bố trí 49 cứ điểm chia thành 3 phân khu, lấy sân bay Mường Thanh và Đồi A1 làm điểm tựa trung tâm.',
        'Viện Lịch sử Quân sự Việt Nam',
        NULL,
        'Tổng kết Chiến dịch Điện Biên Phủ 1954 — Địa hình và bố phòng của địch',
        'HIGH',
        'Đặc điểm địa hình lòng chảo giải thích vì sao đánh nhanh dễ thương vong, vây lấn sẽ cô lập địch',
        asset_dien_bien,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000403'::uuid,
        evt_dbp,
        '[Nhân vật] Đại tướng Võ Nguyên Giáp và quyết định lịch sử ngày 26/1/1954',
        'MILITARY_DOCUMENT',
        'Thực hiện lời dặn của Chủ tịch Hồ Chí Minh "Chắc thắng mới đánh, không chắc thắng không đánh", Đại tướng Võ Nguyên Giáp quyết đoán hoãn nổ súng ngày 26/1/1954 để bảo toàn lực lượng.',
        'Hồi ký Điện Biên Phủ — Điểm hẹn lịch sử',
        'Đại tướng Võ Nguyên Giáp',
        'Võ Nguyên Giáp, Điện Biên Phủ — Điểm hẹn lịch sử, NXB Quân đội Nhân dân',
        'HIGH',
        'Bản lĩnh chỉ huy đặt sinh mệnh chiến sĩ và thắng lợi chắc chắn lên trên hết',
        asset_doanh_trai,
        'APPROVED',
        sys_user,
        now(),
        now()
    ),
    (
        '51000000-0000-4000-8000-000000000404'::uuid,
        evt_dbp,
        '[Cổ thư] Nghị quyết Đảng ủy Mặt trận chuyển sang Đánh chắc, tiến chắc',
        'MILITARY_DOCUMENT',
        'Văn kiện Đảng ủy và Bộ Chỉ huy chiến dịch ngày 26/1/1954 xác định: địch đã tăng cường công sự vững chắc, ta chuyển từ "Đánh nhanh, giải quyết nhanh" sang "Đánh chắc, tiến chắc", bóc dỡ từng cứ điểm.',
        'Văn kiện Quân sự Đảng — Chiến dịch Điện Biên Phủ',
        'Đảng ủy Mặt trận Điện Biên Phủ',
        'Biên bản Hội nghị Đảng ủy Mặt trận tại Mường Phăng, ngày 26/01/1954',
        'HIGH',
        'Tư liệu gốc xác nhận lý do và nội dung chuyển phương châm tác chiến chiến dịch',
        asset_thu_phong,
        'APPROVED',
        sys_user,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        event_id        = EXCLUDED.event_id,
        title           = EXCLUDED.title,
        evidence_type   = EXCLUDED.evidence_type,
        description     = EXCLUDED.description,
        source_title    = EXCLUDED.source_title,
        source_author   = EXCLUDED.source_author,
        source_citation = EXCLUDED.source_citation,
        reliability     = EXCLUDED.reliability,
        relevance       = EXCLUDED.relevance,
        asset_id        = COALESCE(EXCLUDED.asset_id, evidences.asset_id),
        status          = EXCLUDED.status,
        updated_at      = now();

    -- =========================================================================
    -- 2. BUILD 4-PHASE DRAFT JSON FOR ALL 4 LESSONS
    -- =========================================================================

    -- 2.1 Lesson 1: Trận Bạch Đằng năm 938
    d_bd := $draft$ {
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh lịch sử",
          "required": true,
          "nextStageIds": ["discovery"],
          "activities": [
            {
              "id": "intro",
              "type": "READ",
              "required": true,
              "instruction": "Đọc bối cảnh trận Bạch Đằng năm 938",
              "config": {
                "text": "Năm 938, quân Nam Hán kéo thủy quân vào sông Bạch Đằng. Ngô Quyền chuẩn bị trận đánh dựa trên địa hình cửa sông và quy luật thủy triều."
              }
            }
          ]
        },
        {
          "id": "discovery",
          "type": "EVIDENCE",
          "title": "Khám phá 4 Dấu Vết",
          "required": true,
          "requiredEvidenceIds": [
            "51000000-0000-4000-8000-000000000101",
            "51000000-0000-4000-8000-000000000102",
            "51000000-0000-4000-8000-000000000103",
            "51000000-0000-4000-8000-000000000104",
            "d7b10000-0000-4000-8000-000000000001",
            "d7b10000-0000-4000-8000-000000000002",
            "d7b10000-0000-4000-8000-000000000003"
          ],
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "es",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "instruction": "Khám phá và chọn đủ 4 nhóm dấu vết cốt lõi (Hiện vật, Địa hình, Nhân vật, Cổ thư) lý giải chiến thắng Bạch Đằng năm 938",
              "config": {
                "graded": true,
                "visibleEvidenceIds": [
                  "51000000-0000-4000-8000-000000000101",
                  "51000000-0000-4000-8000-000000000102",
                  "51000000-0000-4000-8000-000000000103",
                  "51000000-0000-4000-8000-000000000104",
                  "d7b10000-0000-4000-8000-000000000001",
                  "d7b10000-0000-4000-8000-000000000002",
                  "d7b10000-0000-4000-8000-000000000003"
                ],
                "acceptedEvidenceIds": [
                  "51000000-0000-4000-8000-000000000101",
                  "51000000-0000-4000-8000-000000000102",
                  "51000000-0000-4000-8000-000000000103",
                  "51000000-0000-4000-8000-000000000104"
                ],
                "minRequired": 2,
                "maxAttempts": 3,
                "remedialAttempts": 1
              },
              "feedback": {
                "COMPLETED": "Chính xác! Bạn đã thu thập trọn vẹn 4 nhóm dấu vết: Hiện vật cọc gỗ lim, Địa hình nhật triều, Nhân vật Ngô Quyền và Cổ thư Đại Việt sử ký toàn thư.",
                "PARTIAL": "Bạn đã tìm được một số dấu vết đúng nhưng vẫn chưa đủ 4 nhóm dấu vết cốt lõi ([Hiện vật], [Địa hình], [Nhân vật], [Cổ thư]).",
                "INCORRECT": "Lựa chọn chưa chính xác. Hãy ưu tiên chọn 4 dấu vết đại diện cho Hiện vật, Địa hình, Nhân vật và Cổ thư.",
                "EXHAUSTED": "Đã hết lượt thử. Hệ thống ghi nhận bộ dấu vết cốt lõi về bãi cọc ngầm, thủy triều, mưu kế Ngô Quyền và sử liệu cổ."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt giả thuyết",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Từ 4 dấu vết đã khám phá, hãy chọn giả thuyết hợp lý nhất giải thích vì sao Ngô Quyền đánh bại hạm đội Nam Hán",
              "config": {
                "prompt": "Giả thuyết nào phản ánh đúng bản chất nghệ thuật quân sự của Ngô Quyền tại sông Bạch Đằng năm 938?",
                "priorEvidenceSource": "es",
                "hypotheses": [
                  {
                    "id": "h-tide",
                    "label": "Ngô Quyền thắng nhờ kết hợp trận địa cọc ngầm, quy luật nhật triều và mưu nhử địch đúng thời điểm",
                    "text": "Ngô Quyền thắng nhờ kết hợp trận địa cọc ngầm, quy luật nhật triều và mưu nhử địch đúng thời điểm"
                  },
                  {
                    "id": "h-number",
                    "label": "Ngô Quyền thắng vì sở hữu hạm đội chiến thuyền lớn hơn và quân số áp đảo quân Nam Hán",
                    "text": "Ngô Quyền thắng vì sở hữu hạm đội chiến thuyền lớn hơn và quân số áp đảo quân Nam Hán"
                  },
                  {
                    "id": "h-storm",
                    "label": "Thủy quân Nam Hán tự tan vỡ do gặp bão lớn ngoài cửa biển trước khi vào sông Bạch Đằng",
                    "text": "Thủy quân Nam Hán tự tan vỡ do gặp bão lớn ngoài cửa biển trước khi vào sông Bạch Đằng"
                  }
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết của bạn để chuyển sang bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phù hợp với dữ kiện lịch sử.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Kiểm chứng",
          "required": true,
          "nextStageIds": ["reconstruct"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Đối chiếu giả thuyết đã chọn với các dấu vết thu thập được từ bước Khám phá",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
                "evidenceSource": "es",
                "expectedHypothesis": "h-tide",
                "visibleSourceIds": [
                  "51000000-0000-4000-8000-000000000101",
                  "51000000-0000-4000-8000-000000000102",
                  "51000000-0000-4000-8000-000000000103",
                  "51000000-0000-4000-8000-000000000104"
                ],
                "requiredEvidenceIds": [
                  "51000000-0000-4000-8000-000000000101",
                  "51000000-0000-4000-8000-000000000102"
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "SUPPORTED": "Kiểm chứng thành công! Giả thuyết về thế trận cọc ngầm và thủy triều hoàn toàn khớp với hiện vật cọc gỗ lim và địa hình cửa sông.",
                "PARTIAL": "Giả thuyết đúng hướng nhưng bộ bằng chứng thu thập còn thiếu. Hãy rà soát lại các dấu vết cốt lõi.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp với bãi cọc và thủy triều.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh bởi bằng chứng.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Thủy triều dâng che cọc và rút nhanh làm thuyền Nam Hán mắc cọc chính là mấu chốt chiến thắng."
              }
            }
          ]
        },
        {
          "id": "reconstruct",
          "type": "RECONSTRUCTION",
          "title": "Dựng lại sự kiện",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "do",
              "type": "DRAG_ORDER",
              "required": true,
              "instruction": "Sắp xếp lại trình tự diễn biến trận Bạch Đằng năm 938 theo đúng diễn tiến thời gian",
              "config": {
                "items": [
                  {"id": "s1", "label": "Đóng cọc gỗ lim bịt sắt ngầm ở cửa sông Bạch Đằng"},
                  {"id": "s2", "label": "Cho thuyền nhẹ ra khiêu chiến nhử quân Nam Hán vào sông"},
                  {"id": "s3", "label": "Thủy triều dâng cao che kín toàn bộ bãi cọc ngầm"},
                  {"id": "s4", "label": "Ngô Quyền phát lệnh dốc toàn lực phản công chặn đánh"},
                  {"id": "s5", "label": "Thủy triều rút gấp, chiến thuyền giặc va vào cọc vỡ đắm"},
                  {"id": "s6", "label": "Quân Nam Hán đại bại, tướng Lưu Hoằng Tháo tử trận"}
                ],
                "expectedOrder": ["s1", "s2", "s3", "s4", "s5", "s6"],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Xuất sắc! Bạn đã dựng lại chính xác toàn bộ diễn biến trận thủy chiến Bạch Đằng năm 938.",
                "PARTIAL": "Một số bước đã đúng vị trí, hãy chú ý trình tự: đóng cọc → nhử địch khi triều lên → phản công khi triều rút.",
                "INCORRECT": "Thứ tự diễn biến chưa đúng. Hãy bắt đầu từ khâu chuẩn bị bãi cọc trước khi quân Nam Hán tiến vào.",
                "EXHAUSTED": "Đã hết lượt sắp xếp. Trình tự chuẩn: Đóng cọc → Nhử địch → Triều lên che cọc → Phản công → Triều rút thuyền mắc cọc → Địch tan vỡ."
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Kết luận CER",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "cer",
              "type": "CER_CHOICE",
              "required": true,
              "instruction": "Hoàn thành lập luận lịch sử (Claim — Evidence — Reasoning) về nguyên nhân chiến thắng Bạch Đằng năm 938",
              "config": {
                "claims": [
                  {"id": "c-tide", "text": "Chiến thắng Bạch Đằng là kết quả của nghệ thuật lợi dụng địa hình cửa sông, quy luật thủy triều và thế trận cọc ngầm."},
                  {"id": "c-num", "text": "Chiến thắng Bạch Đằng chủ yếu nhờ quân ta đông hơn và vũ khí hiện đại hơn quân Nam Hán."}
                ],
                "reasoningOptions": [
                  {"id": "r-tide", "text": "Nước triều lên che giấu bãi cọc khi nhử địch vào sâu, đến lúc triều rút chảy xiết khiến thuyền lớn của địch mắc cọc và bị tiêu diệt."},
                  {"id": "r-luck", "text": "Quân Nam Hán tự rút lui vì thiếu lương thảo và không quen khí hậu phương Nam."}
                ],
                "evidenceOptions": [
                  {"id": "51000000-0000-4000-8000-000000000101"},
                  {"id": "51000000-0000-4000-8000-000000000102"},
                  {"id": "51000000-0000-4000-8000-000000000103"},
                  {"id": "51000000-0000-4000-8000-000000000104"},
                  {"id": "d7b10000-0000-4000-8000-000000000001"},
                  {"id": "d7b10000-0000-4000-8000-000000000002"}
                ],
                "priorEvidenceSource": "es",
                "acceptedCombos": [
                  {
                    "claimId": "c-tide",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000101",
                      "51000000-0000-4000-8000-000000000102",
                      "51000000-0000-4000-8000-000000000103",
                      "51000000-0000-4000-8000-000000000104"
                    ],
                    "reasoningId": "r-tide"
                  },
                  {
                    "claimId": "c-tide",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000101",
                      "51000000-0000-4000-8000-000000000102"
                    ],
                    "reasoningId": "r-tide"
                  },
                  {
                    "claimId": "c-tide",
                    "evidenceIds": [
                      "d7b10000-0000-4000-8000-000000000001",
                      "d7b10000-0000-4000-8000-000000000002"
                    ],
                    "reasoningId": "r-tide"
                  }
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Kết luận CER hoàn toàn chính xác! Bạn đã kết nối chặt chẽ nhận định, bằng chứng và lập luận lịch sử.",
                "PARTIAL": "Lập luận của bạn đã đúng một phần. Hãy kiểm tra lại sự ăn khớp giữa Nhận định, Bằng chứng và Lý giải.",
                "INCORRECT": "Kết luận chưa chính xác. Hãy dựa vào các bằng chứng về bãi cọc và thủy triều đã kiểm chứng.",
                "EXHAUSTED": "Đã hết lượt thử. Chiến thắng Bạch Đằng năm 938 là đỉnh cao nghệ thuật lợi dụng địa hình và thủy triều để chấm dứt Bắc thuộc."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- 2.2 Lesson 2: Tiếng Trống Mê Linh (Hai Bà Trưng năm 40)
    d_hbt := $draft$ {
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh lịch sử",
          "required": true,
          "nextStageIds": ["discovery"],
          "activities": [
            {
              "id": "read-hbt-context",
              "type": "READ",
              "required": true,
              "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn",
              "config": {
                "text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."
              }
            }
          ]
        },
        {
          "id": "discovery",
          "type": "EVIDENCE",
          "title": "Khám phá 4 Dấu Vết",
          "required": true,
          "requiredEvidenceIds": [
            "51000000-0000-4000-8000-000000000201",
            "51000000-0000-4000-8000-000000000202",
            "51000000-0000-4000-8000-000000000203",
            "51000000-0000-4000-8000-000000000204",
            "20000000-0000-0000-0000-000000000002"
          ],
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "es",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "instruction": "Khám phá và chọn đủ 4 nhóm dấu vết (Hiện vật, Địa hình, Nhân vật, Cổ thư) làm sáng tỏ nguyên nhân và quy mô khởi nghĩa Hai Bà Trưng",
              "config": {
                "graded": true,
                "visibleEvidenceIds": [
                  "51000000-0000-4000-8000-000000000201",
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000203",
                  "51000000-0000-4000-8000-000000000204",
                  "20000000-0000-0000-0000-000000000002"
                ],
                "acceptedEvidenceIds": [
                  "51000000-0000-4000-8000-000000000201",
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000203",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "minRequired": 2,
                "maxAttempts": 3,
                "remedialAttempts": 1
              },
              "feedback": {
                "COMPLETED": "Chính xác! Bạn đã thu thập đủ 4 nhóm dấu vết: Trống đồng Mê Linh, Địa hình Hát Môn – Luy Lâu, Nhân vật Hai Bà Trưng và Cổ thư Lời thề Hát Môn.",
                "PARTIAL": "Bạn mới chọn được một phần. Hãy chọn trọn bộ 4 dấu vết đại diện cho [Hiện vật], [Địa hình], [Nhân vật] và [Cổ thư].",
                "INCORRECT": "Lựa chọn chưa đúng trọng tâm. Hãy kiểm tra lại 4 nhóm dấu vết cốt lõi của cuộc khởi nghĩa.",
                "EXHAUSTED": "Đã hết lượt thử. Hệ thống ghi nhận 4 nhóm dấu vết chuẩn của cuộc khởi nghĩa Hai Bà Trưng."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt giả thuyết",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Dựa vào các dấu vết đã thu thập, hãy đặt giả thuyết về động lực cốt lõi khiến 65 thành trì đồng loạt hưởng ứng Hai Bà Trưng",
              "config": {
                "prompt": "Vì sao tiếng trống Mê Linh của Hai Bà Trưng nhanh chóng quy tụ được sức mạnh của cả 65 thành trì?",
                "priorEvidenceSource": "es",
                "hypotheses": [
                  {
                    "id": "h-restore-independ",
                    "label": "Cuộc khởi nghĩa kết tinh khát vọng rửa quốc thù, khôi phục cơ nghiệp họ Hùng và giải phóng nhân dân khỏi ách bóc lột Đông Hán",
                    "text": "Cuộc khởi nghĩa kết tinh khát vọng rửa quốc thù, khôi phục cơ nghiệp họ Hùng và giải phóng nhân dân khỏi ách bóc lột Đông Hán"
                  },
                  {
                    "id": "h-personal-revenge",
                    "label": "Cuộc khởi nghĩa chỉ thuần túy là hành động trả thù riêng của gia đình Trưng Trắc đối với Thái thú Tô Định",
                    "text": "Cuộc khởi nghĩa chỉ thuần túy là hành động trả thù riêng của gia đình Trưng Trắc đối với Thái thú Tô Định"
                  },
                  {
                    "id": "h-han-title",
                    "label": "Các Lạc tướng nổi dậy nhằm gây sức ép để triều đình Đông Hán ban thêm tước vị và bổng lộc",
                    "text": "Các Lạc tướng nổi dậy nhằm gây sức ép để triều đình Đông Hán ban thêm tước vị và bổng lộc"
                  }
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết để tiến hành bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phản ánh đúng tầm vóc cuộc khởi nghĩa.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Kiểm chứng",
          "required": true,
          "nextStageIds": ["reconstruct"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Đối chiếu giả thuyết đã chọn với Lời thề Hát Môn và quy mô 65 thành trì hưởng ứng",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
                "evidenceSource": "es",
                "expectedHypothesis": "h-restore-independ",
                "visibleSourceIds": [
                  "51000000-0000-4000-8000-000000000201",
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000203",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "requiredEvidenceIds": [
                  "51000000-0000-4000-8000-000000000201",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "SUPPORTED": "Kiểm chứng thành công! Lời thề Hát Môn đặt việc rửa quốc thù và nối nghiệp Hùng Vương lên trên nỗi đau riêng, giải thích vì sao 65 thành đều hưởng ứng.",
                "PARTIAL": "Giả thuyết đúng nhưng bạn cần thu thập đủ bằng chứng Hiện vật và Cổ thư để chứng minh.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — nếu chỉ vì thù riêng thì không thể quy tụ hào kiệt khắp 65 thành trì.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Mục tiêu giành độc lập và nối nghiệp Hùng Vương chính là ngọn cờ quy tụ toàn dân."
              }
            }
          ]
        },
        {
          "id": "reconstruct",
          "type": "RECONSTRUCTION",
          "title": "Dựng lại sự kiện",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "do",
              "type": "DRAG_ORDER",
              "required": true,
              "instruction": "Sắp xếp lại trình tự diễn biến cuộc khởi nghĩa Hai Bà Trưng năm 40",
              "config": {
                "items": [
                  {"id": "s1", "label": "Nhà Đông Hán bóc lột hà khắc, Thái thú Tô Định sát hại Thi Sách"},
                  {"id": "s2", "label": "Hai Bà Trưng lập đàn thề tại cửa sông Hát (Hát Môn), phất cờ khởi nghĩa"},
                  {"id": "s3", "label": "Nghĩa quân làm chủ Mê Linh, tiến đánh Cổ Loa"},
                  {"id": "s4", "label": "Tấn công hạ thành Luy Lâu, Thái thú Tô Định hoảng sợ tháo chạy"},
                  {"id": "s5", "label": "65 thành trì hưởng ứng, Trưng Trắc được suy tôn làm Vua (Trưng Nữ Vương)"}
                ],
                "expectedOrder": ["s1", "s2", "s3", "s4", "s5"],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Chính xác! Bạn đã tái hiện đúng mạch diễn biến hào hùng của cuộc khởi nghĩa Hai Bà Trưng.",
                "PARTIAL": "Một số mốc đã đúng vị trí. Hãy lưu ý trình tự địa lý: Hát Môn → Mê Linh, Cổ Loa → Luy Lâu → Xưng Vương.",
                "INCORRECT": "Trình tự chưa chính xác. Hãy bắt đầu từ nguyên nhân Tô Định sát hại Thi Sách và hội thề Hát Môn.",
                "EXHAUSTED": "Đã hết lượt thử. Trình tự chuẩn: Ách áp bức & sát hại Thi Sách → Hội thề Hát Môn → Chiếm Mê Linh, Cổ Loa → Hạ thành Luy Lâu → Xưng Vương."
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Kết luận CER",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "cer",
              "type": "CER_CHOICE",
              "required": true,
              "instruction": "Hoàn thành kết luận CER về nguyên nhân thắng lợi và ý nghĩa lịch sử của khởi nghĩa Hai Bà Trưng",
              "config": {
                "claims": [
                  {"id": "c-indep", "text": "Khởi nghĩa Hai Bà Trưng là cuộc đấu tranh giải phóng dân tộc rộng lớn nhằm khôi phục quốc thống độc lập."},
                  {"id": "c-revenge", "text": "Khởi nghĩa Hai Bà Trưng chỉ là cuộc xung đột cục bộ nhằm giải quyết ân oán cá nhân tại quận Giao Chỉ."}
                ],
                "reasoningOptions": [
                  {"id": "r-unity", "text": "Lời thề Hát Môn đặt quốc thù và cơ nghiệp họ Hùng lên hàng đầu, nhờ đó quy tụ được hào kiệt 65 thành cùng nổi dậy giành quyền tự chủ."},
                  {"id": "r-luck", "text": "Quân Đông Hán tự rút khỏi Luy Lâu mà không có sự tham gia của nhân dân các quận."}
                ],
                "evidenceOptions": [
                  {"id": "51000000-0000-4000-8000-000000000201"},
                  {"id": "51000000-0000-4000-8000-000000000202"},
                  {"id": "51000000-0000-4000-8000-000000000203"},
                  {"id": "51000000-0000-4000-8000-000000000204"},
                  {"id": "20000000-0000-0000-0000-000000000002"}
                ],
                "priorEvidenceSource": "es",
                "acceptedCombos": [
                  {
                    "claimId": "c-indep",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000201",
                      "51000000-0000-4000-8000-000000000202",
                      "51000000-0000-4000-8000-000000000203",
                      "51000000-0000-4000-8000-000000000204"
                    ],
                    "reasoningId": "r-unity"
                  },
                  {
                    "claimId": "c-indep",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000201",
                      "51000000-0000-4000-8000-000000000204"
                    ],
                    "reasoningId": "r-unity"
                  }
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Hoàn toàn chính xác! Bạn đã lập luận chặt chẽ về tầm vóc giải phóng dân tộc của khởi nghĩa Hai Bà Trưng.",
                "PARTIAL": "Một phần lựa chọn đã đúng. Hãy đối chiếu lại sự thống nhất giữa Nhận định, Bằng chứng và Lập luận.",
                "INCORRECT": "Kết luận chưa phù hợp với bằng chứng lịch sử. Hãy xem lại Lời thề Hát Môn và quy mô 65 thành hưởng ứng.",
                "EXHAUSTED": "Đã hết lượt thử. Khởi nghĩa Hai Bà Trưng mở đầu truyền thống quật cường giành độc lập tự chủ của dân tộc Việt Nam."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- 2.3 Lesson 3: Chiến Tuyến Sông Cầu (Sông Như Nguyệt năm 1077)
    d_nn := $draft$ {
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh chiến dịch",
          "required": true,
          "nextStageIds": ["discovery"],
          "activities": [
            {
              "id": "read-ly-context",
              "type": "READ",
              "required": true,
              "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077",
              "config": {
                "text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."
              }
            }
          ]
        },
        {
          "id": "discovery",
          "type": "EVIDENCE",
          "title": "Khám phá 4 Dấu Vết",
          "required": true,
          "requiredEvidenceIds": [
            "51000000-0000-4000-8000-000000000301",
            "51000000-0000-4000-8000-000000000302",
            "51000000-0000-4000-8000-000000000303",
            "51000000-0000-4000-8000-000000000304",
            "20000000-0000-0000-0000-000000000003"
          ],
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "es",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "instruction": "Khám phá và chọn đủ 4 nhóm dấu vết (Hiện vật, Địa hình, Nhân vật, Cổ thư) làm rõ nghệ thuật quân sự tại sông Như Nguyệt năm 1077",
              "config": {
                "graded": true,
                "visibleEvidenceIds": [
                  "51000000-0000-4000-8000-000000000301",
                  "51000000-0000-4000-8000-000000000302",
                  "51000000-0000-4000-8000-000000000303",
                  "51000000-0000-4000-8000-000000000304",
                  "20000000-0000-0000-0000-000000000003"
                ],
                "acceptedEvidenceIds": [
                  "51000000-0000-4000-8000-000000000301",
                  "51000000-0000-4000-8000-000000000302",
                  "51000000-0000-4000-8000-000000000303",
                  "51000000-0000-4000-8000-000000000304"
                ],
                "minRequired": 2,
                "maxAttempts": 3,
                "remedialAttempts": 1
              },
              "feedback": {
                "COMPLETED": "Chính xác! Bạn đã thu thập đủ 4 nhóm dấu vết: Lũy đất cọc tre, Địa hình sông Như Nguyệt, Thái úy Lý Thường Kiệt và Cổ thư Nam Quốc Sơn Hà.",
                "PARTIAL": "Bạn đã chọn đúng một số dấu vết nhưng cần thu thập đủ cả 4 nhóm [Hiện vật], [Địa hình], [Nhân vật] và [Cổ thư].",
                "INCORRECT": "Lựa chọn chưa chính xác. Hãy rà soát lại 4 nhóm dấu vết cốt lõi của phòng tuyến Như Nguyệt.",
                "EXHAUSTED": "Đã hết lượt thử. Hệ thống ghi nhận trọn bộ 4 nhóm dấu vết lịch sử tại phòng tuyến sông Như Nguyệt."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt giả thuyết",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Từ các dấu vết đã thu thập, hãy chọn giả thuyết giải thích vì sao Lý Thường Kiệt bẻ gãy được 10 vạn đại quân Tống",
              "config": {
                "prompt": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?",
                "priorEvidenceSource": "es",
                "hypotheses": [
                  {
                    "id": "h-defense-psywar",
                    "label": "Chủ động lập phòng tuyến kiên cố tiêu hao sinh lực địch, kết hợp đòn tâm lý chiến Nam Quốc Sơn Hà và phản công đúng thời cơ",
                    "text": "Chủ động lập phòng tuyến kiên cố tiêu hao sinh lực địch, kết hợp đòn tâm lý chiến Nam Quốc Sơn Hà và phản công đúng thời cơ"
                  },
                  {
                    "id": "h-all-out-attack",
                    "label": "Dồn toàn bộ quân chủ lực vượt sông quyết chiến ngay khi đại quân Quách Quỳ vừa kéo tới bờ bắc",
                    "text": "Dồn toàn bộ quân chủ lực vượt sông quyết chiến ngay khi đại quân Quách Quỳ vừa kéo tới bờ bắc"
                  },
                  {
                    "id": "h-retreat-capital",
                    "label": "Bỏ trống vùng sông Cầu, rút toàn quân về thành Thăng Long cố thủ chờ quân Tống tự rút",
                    "text": "Bỏ trống vùng sông Cầu, rút toàn quân về thành Thăng Long cố thủ chờ quân Tống tự rút"
                  }
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết của bạn để chuyển sang bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phù hợp với thực tế chiến trường Như Nguyệt.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Kiểm chứng",
          "required": true,
          "nextStageIds": ["reconstruct"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Đối chiếu giả thuyết đã chọn với hệ thống lũy đất cọc tre và bài thơ thần Nam Quốc Sơn Hà",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
                "evidenceSource": "es",
                "expectedHypothesis": "h-defense-psywar",
                "visibleSourceIds": [
                  "51000000-0000-4000-8000-000000000301",
                  "51000000-0000-4000-8000-000000000302",
                  "51000000-0000-4000-8000-000000000303",
                  "51000000-0000-4000-8000-000000000304"
                ],
                "requiredEvidenceIds": [
                  "51000000-0000-4000-8000-000000000301",
                  "51000000-0000-4000-8000-000000000304"
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "SUPPORTED": "Kiểm chứng thành công! Bằng chứng về phòng tuyến cọc tre và bài thơ thần Nam Quốc Sơn Hà hoàn toàn củng cố giả thuyết của bạn.",
                "PARTIAL": "Giả thuyết đúng hướng nhưng bộ bằng chứng thu thập còn thiếu. Hãy rà soát lại các dấu vết cốt lõi.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — Lý Thường Kiệt đã chặn đứng địch ngay tại bờ nam sông Như Nguyệt.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Nghệ thuật phòng ngự kiên cố kết hợp tâm lý chiến và tập kích bất ngờ là chìa khóa chiến thắng."
              }
            }
          ]
        },
        {
          "id": "reconstruct",
          "type": "RECONSTRUCTION",
          "title": "Dựng lại sự kiện",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "do",
              "type": "DRAG_ORDER",
              "required": true,
              "instruction": "Sắp xếp lại trình tự diễn biến cuộc kháng chiến trên phòng tuyến sông Như Nguyệt năm 1077",
              "config": {
                "items": [
                  {"id": "s1", "label": "Lý Thường Kiệt đắp lũy đất, đóng cọc tre lập phòng tuyến bờ nam sông Như Nguyệt"},
                  {"id": "s2", "label": "Quân Lý đánh bại các đợt vượt sông của Quách Quỳ, làm quân Tống mỏi mệt bế tắc"},
                  {"id": "s3", "label": "Đêm khuya vang lên bài thơ thần Nam Quốc Sơn Hà khích lệ sĩ khí tướng sĩ Đại Việt"},
                  {"id": "s4", "label": "Đại quân Lý vượt sông tập kích bất ngờ vào doanh trại quân Tống"},
                  {"id": "s5", "label": "Quân Tống tổn thất quá nửa, chấp nhận giảng hòa và rút quân về nước"}
                ],
                "expectedOrder": ["s1", "s2", "s3", "s4", "s5"],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Xuất sắc! Bạn đã dựng lại đúng diễn biến chiến dịch phòng ngự — phản công trên sông Như Nguyệt.",
                "PARTIAL": "Một số sự kiện đã đúng vị trí. Hãy chú ý trình tự: Lập phòng tuyến → Chặn địch vượt sông → Thơ thần khích lệ → Tập kích → Giảng hòa.",
                "INCORRECT": "Thứ tự chưa chính xác. Hãy bắt đầu từ bước xây dựng phòng tuyến Như Nguyệt.",
                "EXHAUSTED": "Đã hết lượt thử. Trình tự chuẩn: Lập phòng tuyến → Đánh lui các đợt vượt sông → Đọc thơ thần → Tập kích doanh trại Tống → Giảng hòa rút quân."
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Kết luận CER",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "cer",
              "type": "CER_CHOICE",
              "required": true,
              "instruction": "Hoàn thành kết luận CER về nghệ thuật quân sự và ý nghĩa của chiến thắng Như Nguyệt năm 1077",
              "config": {
                "claims": [
                  {"id": "c-strategy", "text": "Chiến thắng Như Nguyệt là đỉnh cao nghệ thuật kết hợp phòng ngự địa hình kiên cố, chiến tranh tâm lý và phản công đúng thời điểm."},
                  {"id": "c-passive", "text": "Chiến thắng Như Nguyệt chỉ nhờ quân Tống tự rút lui vì đường sá xa xôi chứ không có giao chiến lớn."}
                ],
                "reasoningOptions": [
                  {"id": "r-synergy", "text": "Phòng tuyến lũy đất cọc tre chặn đứng 10 vạn quân Tống, trong khi bài thơ Nam Quốc Sơn Hà khẳng định chủ quyền thiêng liêng và tạo đà cho đòn tập kích quyết định."},
                  {"id": "r-chance", "text": "Quân nhà Lý chỉ cố thủ trong kinh thành Thăng Long mà không cần lập phòng tuyến bên bờ sông."}
                ],
                "evidenceOptions": [
                  {"id": "51000000-0000-4000-8000-000000000301"},
                  {"id": "51000000-0000-4000-8000-000000000302"},
                  {"id": "51000000-0000-4000-8000-000000000303"},
                  {"id": "51000000-0000-4000-8000-000000000304"},
                  {"id": "20000000-0000-0000-0000-000000000003"}
                ],
                "priorEvidenceSource": "es",
                "acceptedCombos": [
                  {
                    "claimId": "c-strategy",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000301",
                      "51000000-0000-4000-8000-000000000302",
                      "51000000-0000-4000-8000-000000000303",
                      "51000000-0000-4000-8000-000000000304"
                    ],
                    "reasoningId": "r-synergy"
                  },
                  {
                    "claimId": "c-strategy",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000301",
                      "51000000-0000-4000-8000-000000000304"
                    ],
                    "reasoningId": "r-synergy"
                  }
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Kết luận CER hoàn toàn chính xác! Bạn đã làm sáng tỏ tài thao lược của Lý Thường Kiệt và giá trị của bài thơ thần Nam Quốc Sơn Hà.",
                "PARTIAL": "Lập luận của bạn đã đúng một phần. Hãy kiểm tra lại sự kết nối giữa Nhận định, Bằng chứng và Lý giải.",
                "INCORRECT": "Kết luận chưa chính xác. Hãy dựa vào các dấu vết về phòng tuyến sông Cầu và bài thơ Nam Quốc Sơn Hà.",
                "EXHAUSTED": "Đã hết lượt thử. Chiến thắng Như Nguyệt năm 1077 đã đập tan mưu đồ xâm lược của nhà Tống và bảo vệ vững chắc nền độc lập Đại Việt."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- 2.4 Lesson 4: Quyết Định Lịch Sử: Chuyển Phương Châm Tại Điện Biên Phủ (1954)
    d_dbp := $draft$ {
      "schemaVersion": 1,
      "stages": [
        {
          "id": "context",
          "type": "CONTEXT",
          "title": "Bối cảnh chiến dịch",
          "required": true,
          "nextStageIds": ["discovery"],
          "activities": [
            {
              "id": "read-dbp-context",
              "type": "READ",
              "required": true,
              "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954",
              "config": {
                "text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."
              }
            }
          ]
        },
        {
          "id": "discovery",
          "type": "EVIDENCE",
          "title": "Khám phá 4 Dấu Vết",
          "required": true,
          "requiredEvidenceIds": [
            "51000000-0000-4000-8000-000000000401",
            "51000000-0000-4000-8000-000000000402",
            "51000000-0000-4000-8000-000000000403",
            "51000000-0000-4000-8000-000000000404",
            "20000000-0000-0000-0000-000000000004"
          ],
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "es",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "instruction": "Khám phá và chọn đủ 4 nhóm dấu vết (Hiện vật, Địa hình, Nhân vật, Cổ thư) lý giải quyết định chuyển phương châm tác chiến tại Điện Biên Phủ",
              "config": {
                "graded": true,
                "visibleEvidenceIds": [
                  "51000000-0000-4000-8000-000000000401",
                  "51000000-0000-4000-8000-000000000402",
                  "51000000-0000-4000-8000-000000000403",
                  "51000000-0000-4000-8000-000000000404",
                  "20000000-0000-0000-0000-000000000004"
                ],
                "acceptedEvidenceIds": [
                  "51000000-0000-4000-8000-000000000401",
                  "51000000-0000-4000-8000-000000000402",
                  "51000000-0000-4000-8000-000000000403",
                  "51000000-0000-4000-8000-000000000404"
                ],
                "minRequired": 2,
                "maxAttempts": 3,
                "remedialAttempts": 1
              },
              "feedback": {
                "COMPLETED": "Chính xác! Bạn đã thu thập trọn bộ 4 nhóm dấu vết: Pháo 105mm & hào vây lấn, Địa hình lòng chảo Mường Thanh, Đại tướng Võ Nguyên Giáp và Nghị quyết ngày 26/1/1954.",
                "PARTIAL": "Bạn đã chọn đúng một số dấu vết nhưng cần thu thập đủ cả 4 nhóm [Hiện vật], [Địa hình], [Nhân vật] và [Cổ thư].",
                "INCORRECT": "Lựa chọn chưa chính xác. Hãy tập trung vào 4 nhóm dấu vết cốt lõi của chiến dịch Điện Biên Phủ.",
                "EXHAUSTED": "Đã hết lượt thử. Hệ thống ghi nhận 4 nhóm dấu vết lịch sử của chiến dịch Điện Biên Phủ."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt giả thuyết",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Dựa trên 4 nhóm dấu vết, hãy đặt giả thuyết về lý do quyết định chuyển sang phương châm 'Đánh chắc, tiến chắc' mang tính sống còn",
              "config": {
                "prompt": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ năm 1954?",
                "priorEvidenceSource": "es",
                "hypotheses": [
                  {
                    "id": "h-steady-siege",
                    "label": "Giúp bộ đội đào hào vây lấn, đặt pháo trong hầm kiên cố trên sườn núi, bóc dỡ từng cứ điểm và triệt tiêu ưu thế pháo binh - không quân Pháp",
                    "text": "Giúp bộ đội đào hào vây lấn, đặt pháo trong hầm kiên cố trên sườn núi, bóc dỡ từng cứ điểm và triệt tiêu ưu thế pháo binh - không quân Pháp"
                  },
                  {
                    "id": "h-wait-allies",
                    "label": "Chỉ nhằm mục đích trì hoãn thời gian chờ lực lượng không quân nước ngoài trực tiếp tham chiến",
                    "text": "Chỉ nhằm mục đích trì hoãn thời gian chờ lực lượng không quân nước ngoài trực tiếp tham chiến"
                  },
                  {
                    "id": "h-withdraw-delta",
                    "label": "Nhằm rút toàn bộ các đại đoàn chủ lực khỏi Tây Bắc để quay về phòng thủ vùng đồng bằng Bắc Bộ",
                    "text": "Nhằm rút toàn bộ các đại đoàn chủ lực khỏi Tây Bắc để quay về phòng thủ vùng đồng bằng Bắc Bộ"
                  }
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết của bạn để chuyển sang bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phản ánh đúng ý đồ chiến lược của Bộ Chỉ huy chiến dịch.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Kiểm chứng",
          "required": true,
          "nextStageIds": ["reconstruct"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Đối chiếu giả thuyết đã chọn với hệ thống chiến hào vây lấn, hầm pháo 105mm và Nghị quyết ngày 26/1/1954",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
                "evidenceSource": "es",
                "expectedHypothesis": "h-steady-siege",
                "visibleSourceIds": [
                  "51000000-0000-4000-8000-000000000401",
                  "51000000-0000-4000-8000-000000000402",
                  "51000000-0000-4000-8000-000000000403",
                  "51000000-0000-4000-8000-000000000404"
                ],
                "requiredEvidenceIds": [
                  "51000000-0000-4000-8000-000000000401",
                  "51000000-0000-4000-8000-000000000404"
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "SUPPORTED": "Kiểm chứng thành công! Hệ thống hầm pháo trên cao và hơn 200km giao thông hào vây lấn hoàn toàn chứng minh tính đúng đắn của phương châm Đánh chắc, tiến chắc.",
                "PARTIAL": "Giả thuyết đúng hướng nhưng bộ bằng chứng thu thập còn thiếu. Hãy rà soát lại các dấu vết cốt lõi.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — quân ta không rút đi mà kiên trì bao vây tiêu diệt toàn bộ tập đoàn cứ điểm.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Phương châm Đánh chắc, tiến chắc đã giúp quân ta bóc dỡ từng cụm cứ điểm và giành toàn thắng."
              }
            }
          ]
        },
        {
          "id": "reconstruct",
          "type": "RECONSTRUCTION",
          "title": "Dựng lại sự kiện",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "do",
              "type": "DRAG_ORDER",
              "required": true,
              "instruction": "Sắp xếp lại trình tự diễn biến chính của chiến dịch Điện Biên Phủ năm 1954",
              "config": {
                "items": [
                  {"id": "s1", "label": "Ngày 26/1/1954: Hoãn giờ nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc, tiến chắc"},
                  {"id": "s2", "label": "Xây dựng hầm pháo kiên cố và đào hàng trăm km giao thông hào bao vây lòng chảo Mường Thanh"},
                  {"id": "s3", "label": "Đợt 1 (13–17/3/1954): Đánh chiếm các cụm cứ điểm Him Lam, Độc Lập, Bản Kéo mở toang cửa ngõ phía Bắc"},
                  {"id": "s4", "label": "Đợt 2 (30/3–26/4/1954): Đánh lấn các cao điểm phía Đông, giằng co quyết liệt tại Đồi A1 và cắt đứt sân bay"},
                  {"id": "s5", "label": "Đợt 3 (1–7/5/1954): Tổng công kích, bắt sống tướng De Castries và toàn bộ Bộ Tham mưu Pháp"}
                ],
                "expectedOrder": ["s1", "s2", "s3", "s4", "s5"],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Xuất sắc! Bạn đã dựng lại chính xác 56 ngày đêm lịch sử của chiến dịch Điện Biên Phủ.",
                "PARTIAL": "Một số giai đoạn đã đúng vị trí. Hãy chú ý trình tự: Chuyển phương châm → Đào hào chuẩn bị → Đợt 1 → Đợt 2 → Đợt 3.",
                "INCORRECT": "Trình tự chưa đúng. Chiến dịch bắt đầu bước ngoặt từ quyết định ngày 26/1/1954 trước khi nổ súng Đợt 1 ngày 13/3/1954.",
                "EXHAUSTED": "Đã hết lượt thử. Trình tự chuẩn: Chuyển phương châm 26/1 → Đào hào & làm hầm pháo → Đợt 1 (Him Lam, Độc Lập) → Đợt 2 (Cao điểm phía Đông, sân bay) → Đợt 3 (Tổng công kích 7/5)."
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Kết luận CER",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "cer",
              "type": "CER_CHOICE",
              "required": true,
              "instruction": "Hoàn thành kết luận CER về ý nghĩa quyết định chuyển phương châm tác chiến tại Điện Biên Phủ",
              "config": {
                "claims": [
                  {"id": "c-steady", "text": "Quyết định chuyển sang 'Đánh chắc, tiến chắc' là nhân tố quyết định trực tiếp đưa chiến dịch Điện Biên Phủ đến toàn thắng."},
                  {"id": "c-quick", "text": "Phương án 'Đánh nhanh, thắng nhanh' ban đầu vẫn có thể dễ dàng tiêu diệt tập đoàn cứ điểm trong một đêm mà không cần đào chiến hào."}
                ],
                "reasoningOptions": [
                  {"id": "r-trench", "text": "Nhờ chuẩn bị hầm pháo trên cao và hệ thống chiến hào vây lấn bóc dỡ từng cứ điểm, quân ta vừa bảo toàn lực lượng vừa làm tê liệt pháo binh và cầu hàng không của Pháp."},
                  {"id": "r-weather", "text": "Quân Pháp tại Điện Biên Phủ tự đầu hàng ngay trong tháng 1/1954 do thời tiết sương mù."}
                ],
                "evidenceOptions": [
                  {"id": "51000000-0000-4000-8000-000000000401"},
                  {"id": "51000000-0000-4000-8000-000000000402"},
                  {"id": "51000000-0000-4000-8000-000000000403"},
                  {"id": "51000000-0000-4000-8000-000000000404"},
                  {"id": "20000000-0000-0000-0000-000000000004"}
                ],
                "priorEvidenceSource": "es",
                "acceptedCombos": [
                  {
                    "claimId": "c-steady",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000401",
                      "51000000-0000-4000-8000-000000000402",
                      "51000000-0000-4000-8000-000000000403",
                      "51000000-0000-4000-8000-000000000404"
                    ],
                    "reasoningId": "r-trench"
                  },
                  {
                    "claimId": "c-steady",
                    "evidenceIds": [
                      "51000000-0000-4000-8000-000000000401",
                      "51000000-0000-4000-8000-000000000404"
                    ],
                    "reasoningId": "r-trench"
                  }
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Kết luận CER hoàn toàn chính xác! Bạn đã phân tích sâu sắc tầm vóc quyết định lịch sử ngày 26/1/1954 tại Điện Biên Phủ.",
                "PARTIAL": "Lập luận của bạn đã đúng một phần. Hãy kiểm tra lại sự ăn khớp giữa Nhận định, Bằng chứng và Lý giải.",
                "INCORRECT": "Kết luận chưa chính xác. Hãy dựa vào các bằng chứng về hệ thống chiến hào vây lấn và Nghị quyết ngày 26/1/1954.",
                "EXHAUSTED": "Đã hết lượt thử. Chiến thắng Điện Biên Phủ ngày 7/5/1954 lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp ký Hiệp định Genève."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- =========================================================================
    -- 3. UPDATE LESSONS DRAFT_JSON & INSERT LESSON_VERSIONS V2
    -- =========================================================================
    UPDATE lessons
    SET draft_json = d_bd,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_bd;

    UPDATE lessons
    SET draft_json = d_hbt,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_hbt;

    UPDATE lessons
    SET draft_json = d_nn,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_nn;

    UPDATE lessons
    SET draft_json = d_dbp,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_dbp;

    INSERT INTO lesson_versions (
        id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by
    ) VALUES
        (ver_bd_v2,  les_bd,  2, 1, d_bd,  now(), sys_user),
        (ver_hbt_v2, les_hbt, 2, 1, d_hbt, now(), sys_user),
        (ver_nn_v2,  les_nn,  2, 1, d_nn,  now(), sys_user),
        (ver_dbp_v2, les_dbp, 2, 1, d_dbp, now(), sys_user)
    ON CONFLICT (id) DO UPDATE SET
        snapshot_json = EXCLUDED.snapshot_json,
        published_at  = now();

    UPDATE lessons
    SET current_version_id = ver_bd_v2,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_bd;

    UPDATE lessons
    SET current_version_id = ver_hbt_v2,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_hbt;

    UPDATE lessons
    SET current_version_id = ver_nn_v2,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_nn;

    UPDATE lessons
    SET current_version_id = ver_dbp_v2,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_dbp;
END $$;

-- =============================================================================
-- 4. EMBED EVIDENCE[] AND ASSETS[] INTO NEW LESSON_VERSIONS SNAPSHOT_JSON (V30 PATTERN)
-- =============================================================================
WITH RECURSIVE
cfg_evidence AS (
  SELECT
    lv.id AS version_id,
    t.ev_id::uuid AS evidence_id
  FROM lesson_versions lv
  CROSS JOIN LATERAL (
    SELECT value #>> '{}' AS ev_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.visibleEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.requiredEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.acceptedEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.visibleSourceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value->>'id'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.evidenceOptions[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].requiredEvidenceIds[*]') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT value #>> '{}'
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].evidenceRefs[*]') AS j(value)
    WHERE lv2.id = lv.id
  ) t
  WHERE lv.id IN (
    '51000000-0000-4000-8000-000000000001'::uuid,
    '51000000-0000-4000-8000-000000000002'::uuid,
    '51000000-0000-4000-8000-000000000003'::uuid,
    '51000000-0000-4000-8000-000000000004'::uuid
  )
    AND t.ev_id IS NOT NULL AND t.ev_id <> ''
),
ev_per_version AS (
  SELECT DISTINCT ON (version_id, evidence_id) version_id, evidence_id
  FROM cfg_evidence
),
evidence_json AS (
  SELECT
    epv.version_id,
    jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'id', e.id::text,
        'title', e.title,
        'evidenceType', e.evidence_type,
        'description', e.description,
        'source', jsonb_strip_nulls(jsonb_build_object(
          'title', e.source_title,
          'author', e.source_author,
          'url', e.source_url,
          'citation', e.source_citation,
          'publishedAt', e.source_published_at::text
        )),
        'reliability', e.reliability,
        'relevance', e.relevance,
        'assetId', e.asset_id::text
      ))
      ORDER BY e.id
    ) AS evidence_arr
  FROM ev_per_version epv
  JOIN evidences e ON e.id = epv.evidence_id
  GROUP BY epv.version_id
),
cfg_asset AS (
  SELECT
    lv.id AS version_id,
    t.a_id::uuid AS asset_id
  FROM lesson_versions lv
  CROSS JOIN LATERAL (
    SELECT e.asset_id::text AS a_id
    FROM evidences e
    WHERE e.id IN (SELECT evidence_id FROM ev_per_version WHERE version_id = lv.id)
      AND e.asset_id IS NOT NULL
    UNION ALL
    SELECT value #>> '{}' AS a_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.imageAssetId') AS j(value)
    WHERE lv2.id = lv.id
    UNION ALL
    SELECT (value->>'id') AS a_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].config.backgroundAssetId') AS j(value)
    WHERE lv2.id = lv.id
  ) t
  WHERE lv.id IN (
    '51000000-0000-4000-8000-000000000001'::uuid,
    '51000000-0000-4000-8000-000000000002'::uuid,
    '51000000-0000-4000-8000-000000000003'::uuid,
    '51000000-0000-4000-8000-000000000004'::uuid
  )
    AND t.a_id IS NOT NULL AND t.a_id <> ''
),
asset_per_version AS (
  SELECT DISTINCT version_id, asset_id FROM cfg_asset
),
assets_json AS (
  SELECT
    apv.version_id,
    jsonb_agg(
      jsonb_strip_nulls(jsonb_build_object(
        'id', a.id::text,
        'storageKey', a.storage_key,
        'mimeType', a.mime_type,
        'sizeBytes', a.size_bytes,
        'originalFilename', a.original_filename,
        'altText', a.alt_text
      ))
      ORDER BY a.id
    ) AS assets_arr
  FROM asset_per_version apv
  JOIN assets a ON a.id = apv.asset_id
  GROUP BY apv.version_id
),
target_versions AS (
  SELECT lv.id AS version_id, lv.lesson_id, lv.snapshot_json, l.title
  FROM lesson_versions lv
  JOIN lessons l ON l.id = lv.lesson_id
  WHERE lv.id IN (
    '51000000-0000-4000-8000-000000000001'::uuid,
    '51000000-0000-4000-8000-000000000002'::uuid,
    '51000000-0000-4000-8000-000000000003'::uuid,
    '51000000-0000-4000-8000-000000000004'::uuid
  )
)
UPDATE lesson_versions lv
SET snapshot_json =
  tv.snapshot_json
  || jsonb_build_object('evidence', COALESCE(ej.evidence_arr, '[]'::jsonb))
  || jsonb_build_object('assets',   COALESCE(aj.assets_arr,   '[]'::jsonb))
FROM target_versions tv
LEFT JOIN evidence_json ej ON ej.version_id = tv.version_id
LEFT JOIN assets_json   aj ON aj.version_id = tv.version_id
WHERE lv.id = tv.version_id;

ALTER TABLE lesson_versions ENABLE TRIGGER trg_lesson_versions_immutable;
