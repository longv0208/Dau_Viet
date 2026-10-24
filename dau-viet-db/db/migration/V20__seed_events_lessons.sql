-- Dấu Việt | V20 | Seed sample events + lessons so a fresh DB is browsable.
-- Idempotent: every INSERT ON CONFLICT DO NOTHING. Lessons go in as DRAFT
-- first (chk_lesson_published_version), publish v1, then flip PUBLISHED —
-- same dance as V15/V16/V17.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    tpl_hist UUID := 'd7a00000-0000-4000-8000-000000000001';  -- HISTORY_INVESTIGATION (V7)

    evt_bd UUID := 'd7b00000-0000-4000-8000-000000000001';   -- Bạch Đằng 938
    evt_hb UUID := 'd7b00000-0000-4000-8000-000000000002';   -- Hai Bà Trưng 40
    evt_lt UUID := 'd7b00000-0000-4000-8000-000000000003';   -- Lý Thái Tổ 1010

    ev_bd_1 UUID := 'd7b10000-0000-4000-8000-000000000001';
    ev_bd_2 UUID := 'd7b10000-0000-4000-8000-000000000002';
    ev_bd_3 UUID := 'd7b10000-0000-4000-8000-000000000003';
    ev_hb_1 UUID := 'd7b11000-0000-4000-8000-000000000001';
    ev_hb_2 UUID := 'd7b11000-0000-4000-8000-000000000002';
    ev_hb_3 UUID := 'd7b11000-0000-4000-8000-000000000003';
    ev_lt_1 UUID := 'd7b12000-0000-4000-8000-000000000001';
    ev_lt_2 UUID := 'd7b12000-0000-4000-8000-000000000002';
    ev_lt_3 UUID := 'd7b12000-0000-4000-8000-000000000003';

    les_bd UUID := 'd7b20000-0000-4000-8000-000000000001';
    les_hb UUID := 'd7b20000-0000-4000-8000-000000000002';
    les_lt UUID := 'd7b20000-0000-4000-8000-000000000003';
    ver_bd UUID := 'd7b30000-0000-4000-8000-000000000001';
    ver_hb UUID := 'd7b30000-0000-4000-8000-000000000002';
    ver_lt UUID := 'd7b30000-0000-4000-8000-000000000003';

    d_bd JSONB;
    d_hb JSONB;
    d_lt JSONB;
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System',
            'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    /* ================= EVENTS ================= */
    INSERT INTO historical_events
        (id, slug, title, era, period, start_year, summary, description,
         location, tags, status)
    VALUES
        (evt_bd, 'bach-dang-938', 'Trận Bạch Đằng năm 938',
         'Thời kỳ độc lập', 'Ngô Quyền', 938,
         'Chiến thắng của Ngô Quyền trên sông Bạch Đằng chấm dứt một nghìn năm Bắc thuộc.',
         'Quân Nam Hán kéo thủy quân vào sông Bạch Đằng. Ngô Quyền cho đóng bãi cọc ngầm, lợi dụng thủy triều dụ địch vào trận địa rồi phục kích khi triều rút.',
         'Sông Bạch Đằng, Quảng Ninh', ARRAY['thuy-chien','ngo-quyen','doc-lap'], 'PUBLISHED'),
        (evt_hb, 'hai-ba-trung-40', 'Khởi nghĩa Hai Bà Trưng năm 40',
         'Bắc thuộc lần I', 'Hai Bà Trưng', 40,
         'Cuộc khởi nghĩa do Hai Bà Trưng khởi xướng, thiết lập chính quyền tự chủ ngắn ngủi.',
         'Năm 40, Hai Bà Trưng phất cờ khởi nghĩa tại Mê Linh, nhanh chóng lan rộng và chiếm Luy Lâu — trung tâm cai trị của nhà Hán.',
         'Mê Linh, Luy Lâu', ARRAY['khoi-nghia','hai-ba-trung'], 'PUBLISHED'),
        (evt_lt, 'ly-thai-to-1010', 'Lý Thái Tổ dời đô năm 1010',
         'Nhà Lý', 'Lý Thái Tổ', 1010,
         'Quyết định dời kinh đô từ Hoa Lư về Đại La — đặt nền móng cho Thăng Long.',
         'Năm 1010, Lý Thái Tổ ban Chiếu dời đô, chọn vùng Đại La làm kinh đô mới và đổi tên thành Thăng Long.',
         'Hoa Lư → Đại La (Thăng Long)', ARRAY['kinh-do','nha-ly','thang-long'], 'PUBLISHED')
    ON CONFLICT (slug) DO NOTHING;

    /* Events may already exist via EventSeedRunner or prior seed. Resolve
       the real row ids — do NOT rely on the generated UUIDs above. */
    SELECT id INTO evt_bd FROM historical_events WHERE slug = 'bach-dang-938';
    SELECT id INTO evt_hb FROM historical_events WHERE slug = 'hai-ba-trung-40';
    SELECT id INTO evt_lt FROM historical_events WHERE slug = 'ly-thai-to-1010';

    /* ================= EVIDENCES ================= */
    INSERT INTO evidences
        (id, event_id, title, evidence_type, description,
         source_title, source_author, source_url, source_citation,
         reliability, relevance, status, created_by)
    VALUES
        (ev_bd_1, evt_bd, 'Đại Việt sử ký toàn thư — trận Bạch Đằng',
         'TEXT', 'Đoạn ghi chép Ngô Quyền đóng cọc ngầm và lợi dụng thủy triều.',
         'Đại Việt sử ký toàn thư', 'Ngô Sĩ Liên', NULL,
         'Ngoại kỷ, quyển 5, kỷ Ngô Quyền', 'HIGH',
         'Tư liệu chính về trận đánh', 'APPROVED', sys_user),
        (ev_bd_2, evt_bd, 'Bảo tàng LSQG — bãi cọc Bạch Đằng',
         'TEXT', 'Hiện vật cọc gỗ khai quật tại khu vực Bạch Đằng.',
         'Bảo tàng Lịch sử Quốc gia', NULL, 'https://baotanglichsuquocgia.vn',
         'Mục "Ngô Quyền và chiến thắng Bạch Đằng năm 938"', 'HIGH',
         'Bằng chứng vật lý về trận địa cọc', 'APPROVED', sys_user),
        (ev_bd_3, evt_bd, 'Tư liệu địa hình cửa sông Bạch Đằng',
         'TEXT', 'Mô tả địa hình lòng sông và chế độ thủy triều vùng cửa Bạch Đằng.',
         'Viện Hàn lâm KHXH&NV', NULL, NULL, NULL, 'MEDIUM',
         'Bối cảnh địa tự nhiên của trận đánh', 'APPROVED', sys_user),

        (ev_hb_1, evt_hb, 'Đại Việt sử ký toàn thư — khởi nghĩa Hai Bà Trưng',
         'TEXT', 'Đoạn ghi chép 65 thành trì theo về khởi nghĩa.',
         'Đại Việt sử ký toàn thư', 'Ngô Sĩ Liên', NULL,
         'Ngoại kỷ, quyển 3, kỷ Trưng Nữ Vương', 'HIGH',
         'Bằng chứng quy mô của khởi nghĩa', 'APPROVED', sys_user),
        (ev_hb_2, evt_hb, 'Đền Hai Bà Trưng — Mê Linh',
         'TEXT', 'Đền thờ tại quê hương Hai Bà Trưng.',
         'Ban quản lý di tích Mê Linh', NULL, NULL, NULL, 'MEDIUM',
         'Bối cảnh văn hóa của cuộc khởi nghĩa', 'APPROVED', sys_user),
        (ev_hb_3, evt_hb, 'Tư liệu về Luy Lâu thời Đông Hán',
         'TEXT', 'Mô tả vai trò Luy Lâu như trung tâm cai trị.',
         'Viện Hàn lâm KHXH&NV', NULL, NULL, NULL, 'MEDIUM',
         'Bối cảnh chính trị của cuộc khởi nghĩa', 'APPROVED', sys_user),

        (ev_lt_1, evt_lt, 'Chiếu dời đô — Lý Thái Tổ',
         'TEXT', 'Văn bản chiếu thiên đô năm 1010.',
         'Đại Việt sử ký toàn thư', NULL, NULL,
         'Bản kỷ, quyển 2, kỷ Lý Thái Tổ', 'HIGH',
         'Văn bản gốc của quyết định', 'APPROVED', sys_user),
        (ev_lt_2, evt_lt, 'Đại Việt sử ký toàn thư — dời đô về Thăng Long',
         'TEXT', 'Đoạn ghi chép quá trình chọn địa điểm mới.',
         'Đại Việt sử ký toàn thư', 'Ngô Sĩ Liên', NULL, NULL, 'HIGH',
         'Bằng chứng về quyết định dời đô', 'APPROVED', sys_user),
        (ev_lt_3, evt_lt, 'Tư liệu về thành Đại La',
         'TEXT', 'Mô tả vị trí và vai trò thành Đại La.',
         'Viện Hàn lâm KHXH&NV', NULL, NULL, NULL, 'MEDIUM',
         'Bối cảnh địa lý của kinh đô mới', 'APPROVED', sys_user)
    ON CONFLICT (id) DO NOTHING;

    /* ================= LESSON: Bạch Đằng 938 ================= */
    d_bd := '{
      "schemaVersion": 1,
      "stages": [
        {"id":"ctx","type":"CONTEXT","required":true,
         "activities":[{"id":"intro","type":"READ","required":true,
           "instruction":"Đọc bối cảnh trận Bạch Đằng năm 938",
           "config":{"text":"Năm 938, quân Nam Hán kéo thủy quân vào sông Bạch Đằng. Ngô Quyền chuẩn bị trận đánh dựa trên địa hình cửa sông và quy luật thủy triều."}}],
         "nextStageIds":["ev"]},
        {"id":"ev","type":"EVIDENCE","required":true,
         "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
           "instruction":"Chọn những tư liệu chứng minh Ngô Quyền lợi dụng thủy triều",
           "config":{"graded":true,
             "visibleEvidenceIds":["d7b10000-0000-4000-8000-000000000001","d7b10000-0000-4000-8000-000000000002","d7b10000-0000-4000-8000-000000000003"],
             "acceptedEvidenceIds":["d7b10000-0000-4000-8000-000000000001","d7b10000-0000-4000-8000-000000000002"],
             "minRequired":1,"maxAttempts":2,"remedialAttempts":1},
           "feedback":{"COMPLETED":"Đúng — hai tư liệu cốt lõi về bãi cọc và thủy triều.",
             "PARTIAL":"Chưa đủ — một trong hai bằng chứng chính còn thiếu.",
             "INCORRECT":"Chưa đúng — rà soát lại tư liệu.",
             "EXHAUSTED":"Hết lượt thử."}}],
         "requiredEvidenceIds":["d7b10000-0000-4000-8000-000000000001","d7b10000-0000-4000-8000-000000000002","d7b10000-0000-4000-8000-000000000003"],
         "nextStageIds":["re"]},
        {"id":"re","type":"RECONSTRUCTION","required":true,
         "activities":[{"id":"do","type":"DRAG_ORDER","required":true,
           "instruction":"Sắp xếp lại trình tự diễn biến trận đánh",
           "config":{"items":[
             {"id":"s1","label":"Đóng cọc ở cửa sông"},
             {"id":"s2","label":"Dụ địch vào bãi"},
             {"id":"s3","label":"Thủy triều lên che cọc"},
             {"id":"s4","label":"Phục kích chặn đánh"},
             {"id":"s5","label":"Thủy triều rút, thuyền mắc cọc"},
             {"id":"s6","label":"Quân Nam Hán tan vỡ"}],
             "expectedOrder":["s1","s2","s3","s4","s5","s6"]},
           "feedback":{"COMPLETED":"Đúng trình tự.","INCORRECT":"Sai thứ tự."}}],
         "nextStageIds":["cc"]},
        {"id":"cc","type":"CONCLUSION","required":true,
         "activities":[{"id":"cer","type":"CER_CHOICE","required":true,
           "instruction":"Kết luận về nguyên nhân chiến thắng",
           "config":{"claims":[
             {"id":"c-tide","text":"Chiến thắng là kết quả lợi dụng thủy triều và địa hình."},
             {"id":"c-num","text":"Chiến thắng là kết quả áp đảo quân số."}],
             "reasoningOptions":[
               {"id":"r-tide","text":"Triều che giấu bãi cọc, triều rút khiến thuyền địch mắc kẹt."},
               {"id":"r-luck","text":"Quân địch tự rút vì thiếu lương."}],
             "evidenceOptions":[
               {"id":"d7b10000-0000-4000-8000-000000000001"},
               {"id":"d7b10000-0000-4000-8000-000000000002"}],
             "priorEvidenceSource":"es",
             "acceptedCombos":[{"claimId":"c-tide",
               "evidenceIds":["d7b10000-0000-4000-8000-000000000001","d7b10000-0000-4000-8000-000000000002"],
               "reasoningId":"r-tide"}],
             "maxAttempts":3},
           "feedback":{"COMPLETED":"Kết luận đúng.","PARTIAL":"Một phần đúng.",
             "INCORRECT":"Chưa đúng.","EXHAUSTED":"Hết lượt."}}],
         "nextStageIds":[]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }'::jsonb;

    /* ================= LESSON: Hai Bà Trưng ================= */
    d_hb := '{
      "schemaVersion": 1,
      "stages": [
        {"id":"ev","type":"EVIDENCE","required":true,
         "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
           "instruction":"Chọn tư liệu chứng minh quy mô khởi nghĩa",
           "config":{"graded":true,
             "visibleEvidenceIds":["d7b11000-0000-4000-8000-000000000001","d7b11000-0000-4000-8000-000000000002","d7b11000-0000-4000-8000-000000000003"],
             "acceptedEvidenceIds":["d7b11000-0000-4000-8000-000000000001"],
             "maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng.","INCORRECT":"Chưa đúng.","EXHAUSTED":"Hết lượt."}}],
         "requiredEvidenceIds":["d7b11000-0000-4000-8000-000000000001","d7b11000-0000-4000-8000-000000000002","d7b11000-0000-4000-8000-000000000003"],
         "nextStageIds":["cc"]},
        {"id":"cc","type":"CONCLUSION","required":true,
         "activities":[{"id":"cer","type":"CER_CHOICE","required":true,
           "instruction":"Kết luận về ý nghĩa khởi nghĩa",
           "config":{"claims":[
             {"id":"c-indep","text":"Khởi nghĩa khôi phục chính quyền tự chủ."},
             {"id":"c-sym","text":"Khởi nghĩa chỉ có ý nghĩa biểu tượng."}],
             "reasoningOptions":[
               {"id":"r-castle","text":"65 thành trì theo về cho thấy quyền lực được khôi phục."},
               {"id":"r-short","text":"Khởi nghĩa chỉ kéo dài ba năm."}],
             "evidenceOptions":[
               {"id":"d7b11000-0000-4000-8000-000000000001"},
               {"id":"d7b11000-0000-4000-8000-000000000002"}],
             "priorEvidenceSource":"es",
             "acceptedCombos":[{"claimId":"c-indep",
               "evidenceIds":["d7b11000-0000-4000-8000-000000000001"],
               "reasoningId":"r-castle"}],
             "maxAttempts":3},
           "feedback":{"COMPLETED":"Kết luận đúng.","PARTIAL":"Một phần.",
             "INCORRECT":"Chưa đúng.","EXHAUSTED":"Hết lượt."}}],
         "nextStageIds":[]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }'::jsonb;

    /* ================= LESSON: Lý Thái Tổ ================= */
    d_lt := '{
      "schemaVersion": 1,
      "stages": [
        {"id":"ctx","type":"CONTEXT","required":true,
         "activities":[{"id":"intro","type":"READ","required":true,
           "instruction":"Đọc bối cảnh dời đô năm 1010",
           "config":{"text":"Năm 1010, Lý Thái Tổ quyết định dời kinh đô từ Hoa Lư về Đại La và đổi tên thành Thăng Long — quyết định định hình trung tâm chính trị lâu dài."}}],
         "nextStageIds":["ev"]},
        {"id":"ev","type":"EVIDENCE","required":true,
         "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
           "instruction":"Chọn tư liệu chứng minh quyết định dời đô",
           "config":{"graded":true,
             "visibleEvidenceIds":["d7b12000-0000-4000-8000-000000000001","d7b12000-0000-4000-8000-000000000002","d7b12000-0000-4000-8000-000000000003"],
             "acceptedEvidenceIds":["d7b12000-0000-4000-8000-000000000001","d7b12000-0000-4000-8000-000000000002"],
             "minRequired":1,"maxAttempts":2},
           "feedback":{"COMPLETED":"Đúng.","PARTIAL":"Chưa đủ.",
             "INCORRECT":"Chưa đúng.","EXHAUSTED":"Hết lượt."}}],
         "requiredEvidenceIds":["d7b12000-0000-4000-8000-000000000001","d7b12000-0000-4000-8000-000000000002","d7b12000-0000-4000-8000-000000000003"],
         "nextStageIds":["cc"]},
        {"id":"cc","type":"CONCLUSION","required":true,
         "activities":[{"id":"cer","type":"CER_CHOICE","required":true,
           "instruction":"Kết luận về ý nghĩa quyết định dời đô",
           "config":{"claims":[
             {"id":"c-vision","text":"Dời đô là quyết định chiến lược lâu dài."},
             {"id":"c-temp","text":"Dời đô chỉ là quyết định nhất thời."}],
             "reasoningOptions":[
               {"id":"r-center","text":"Đại La là trung tâm đồng bằng, thuận lợi phát triển."},
               {"id":"r-castle","text":"Hoa Lư hiểm trở, phù hợp phòng thủ hơn."}],
             "evidenceOptions":[
               {"id":"d7b12000-0000-4000-8000-000000000001"},
               {"id":"d7b12000-0000-4000-8000-000000000002"}],
             "priorEvidenceSource":"es",
             "acceptedCombos":[{"claimId":"c-vision",
               "evidenceIds":["d7b12000-0000-4000-8000-000000000001","d7b12000-0000-4000-8000-000000000002"],
               "reasoningId":"r-center"}],
             "maxAttempts":3},
           "feedback":{"COMPLETED":"Kết luận đúng.","PARTIAL":"Một phần.",
             "INCORRECT":"Chưa đúng.","EXHAUSTED":"Hết lượt."}}],
         "nextStageIds":[]}
      ],
      "completion":{"requireAllRequiredStages":true}
    }'::jsonb;

    /* ============ Insert DRAFT → publish v1 → flip PUBLISHED ============ */
    INSERT INTO lessons
        (id, event_id, template_id, title, central_question,
         objectives_json, draft_json, status, created_by, updated_by)
    VALUES
        (les_bd, evt_bd, tpl_hist, 'Trận Bạch Đằng năm 938',
         'Vì sao Ngô Quyền chọn sông Bạch Đằng làm trận địa quyết định?',
         '["Hiểu cơ chế lợi dụng thủy triều và bãi cọc","Phân tích trình tự diễn biến","Kết luận bằng bằng chứng"]'::jsonb,
         d_bd, 'DRAFT', sys_user, sys_user),
        (les_hb, evt_hb, tpl_hist, 'Khởi nghĩa Hai Bà Trưng năm 40',
         'Điều gì cho thấy quy mô và ý nghĩa của khởi nghĩa Hai Bà Trưng?',
         '["Đánh giá bằng chứng về quy mô","Kết luận về ý nghĩa lịch sử"]'::jsonb,
         d_hb, 'DRAFT', sys_user, sys_user),
        (les_lt, evt_lt, tpl_hist, 'Lý Thái Tổ dời đô năm 1010',
         'Vì sao Lý Thái Tổ chọn Đại La thay vì giữ Hoa Lư?',
         '["Hiểu bối cảnh quyết định dời đô","Đánh giá vai trò địa thế"]'::jsonb,
         d_lt, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO NOTHING;

    -- snapshot = draft (same shape; DraftValidator enforces structure)
    INSERT INTO lesson_versions
        (id, lesson_id, version_no, schema_version, snapshot_json, published_by)
    VALUES
        (ver_bd, les_bd, 1, 1, d_bd, sys_user),
        (ver_hb, les_hb, 1, 1, d_hb, sys_user),
        (ver_lt, les_lt, 1, 1, d_lt, sys_user)
    ON CONFLICT (id) DO NOTHING;

    UPDATE lessons SET current_version_id = ver_bd WHERE id = les_bd AND current_version_id IS NULL;
    UPDATE lessons SET current_version_id = ver_hb WHERE id = les_hb AND current_version_id IS NULL;
    UPDATE lessons SET current_version_id = ver_lt WHERE id = les_lt AND current_version_id IS NULL;

    UPDATE lessons SET status = 'PUBLISHED'
    WHERE id IN (les_bd, les_hb, les_lt) AND status <> 'PUBLISHED';
END $$;
