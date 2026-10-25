-- Dấu Việt | V20 | Seed historical events, lessons, lesson versions, evidences and map locations
-- Bao gồm dữ liệu lịch sử chuẩn hoá:
-- 1. Thời Đại Hùng Vương - Dựng Nước Văn Lang
-- 2. Khởi Nghĩa Hai Bà Trưng (Năm 40)
-- 3. Đại Chiến Bạch Đằng 938
-- 4. Chiến Thắng Như Nguyệt 1077
-- 5. Chiến Dịch Điện Biên Phủ 1954
-- Cùng các bài học đã xuất bản, bằng chứng lịch sử và 11 toạ độ di tích trên bản đồ.

-- ============================================================================
-- 1. HISTORICAL EVENTS
-- ============================================================================
INSERT INTO historical_events (
    id, slug, title, era, period, start_year, summary, description, location, cover_asset_key, tags, status, created_at, updated_at
) VALUES
(
    '00000000-0000-0000-0000-000000000005'::uuid,
    'hung-vuong-van-lang',
    'Thời Đại Hùng Vương - Dựng Nước Văn Lang',
    'Thời Hùng Vương - Văn Lang (~2879 - 258 TCN)',
    'Khoảng thế kỷ VII TCN',
    -700,
    'Thời kỳ dựng nước đầu tiên của dân tộc Việt Nam với 18 đời vua Hùng, đặt nền móng cho nền văn minh sông Hồng.',
    'Mười tám đời vua Hùng nối tiếp nhau trị vì non sông, khai hoang lập ấp, định đô tại Phong Châu (Phú Thọ ngày nay), sáng tạo nền văn hóa Đông Sơn rực rỡ với trống đồng thiêng liêng.',
    'Khu di tích lịch sử Đền Hùng, Nghĩa Lĩnh, Phong Châu, Phú Thọ',
    'events/hung-vuong/hero.jpg',
    ARRAY['hung-vuong', 'van-lang', 'phong-chau', 'trong-dong', 'den-hung'],
    'PUBLISHED',
    now(),
    now()
),
(
    '00000000-0000-0000-0000-000000000002'::uuid,
    'khoi-nghia-hai-ba-trung-40',
    'Khởi Nghĩa Hai Bà Trưng (Năm 40)',
    'Thời kỳ Bắc thuộc lần 1',
    'Mùa Xuân năm 40 SCN',
    40,
    'Cuộc khởi nghĩa vũ trang đầu tiên của người Việt chống ách đô hộ của nhà Đông Hán, do Trưng Trắc và Trưng Nhị lãnh đạo, giải phóng Mê Linh và 65 thành trì.',
    'Bất bình trước chính sách đồng hóa tàn bạo và sưu thuế hà khắc của viên Thái thú Tô Định, cùng thù riêng khi Thi Sách bị sát hại, Trưng Trắc cùng em gái là Trưng Nhị dựng cờ khởi nghĩa tại cửa sông Hát. Khởi nghĩa được nhân dân khắp nơi hưởng ứng nhiệt liệt, nhanh chóng quét sạch chính quyền đô hộ, lập nên nền độc lập tự chủ kéo dài gần 3 năm.',
    'Hát Môn (Phúc Thọ, Hà Nội) & Mê Linh',
    'events/hai-ba-trung-40/hero.jpg',
    ARRAY['hai-ba-trung', 'khoi-nghia', 'me-linh', 'bac-thuoc'],
    'PUBLISHED',
    now(),
    now()
),
(
    '00000000-0000-0000-0000-000000000001'::uuid,
    'bach-dang-938',
    'Đại Chiến Bạch Đằng 938',
    'Thời Ngô - Đinh - Tiền Lê (938 - 1009)',
    'Mùa Đông 938 SCN',
    938,
    'Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt lợi dụng con nước triều, tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, chính thức chấm dứt hơn 1.000 năm Bắc thuộc.',
    'Năm 938, Ngô Quyền lợi dụng địa thế cửa sông Bạch Đằng và quy luật thủy triều để bố trí trận địa cọc ngầm bịt sắt, nhử hạm đội Nam Hán vào trận địa rồi tiêu diệt khi nước rút. Chiến thắng mở ra kỷ nguyên độc lập lâu dài cho Việt Nam.',
    'Cửa sông Bạch Đằng, Quảng Ninh - Hải Phòng',
    'events/bach-dang-938/hero.jpg',
    ARRAY['ngo-quyen', 'thuy-chien', 'bac-thuoc', 'bach-dang'],
    'PUBLISHED',
    now(),
    now()
),
(
    '00000000-0000-0000-0000-000000000003'::uuid,
    'chien-thang-nhu-nguyet-1077',
    'Chiến Thắng Như Nguyệt 1077',
    'Thời nhà Lý (1009 - 1225)',
    'Mùa Xuân năm 1077',
    1077,
    'Trận quyết chiến chiến lược trên sông Như Nguyệt do Thái úy Lý Thường Kiệt chỉ huy, chặn đứng hoàn toàn 10 vạn đại quân xâm lược Tống và bảo vệ vững chắc Thăng Long.',
    'Năm 1077, quân Tống do Quách Quỳ chỉ huy tràn vào Đại Việt. Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu), dùng cọc tre, lũy đất tạo thế phòng ngự vững chắc. Kết hợp chiến tranh tâm lý với bài thơ thần Nam quốc sơn hà vang dội trong đêm, quân ta mở đòn phản công chớp nhoáng khiến địch tan rã, buộc phải chấp nhận giảng hòa rút quân.',
    'Phòng tuyến sông Như Nguyệt (sông Cầu, Bắc Ninh)',
    'events/nhu-nguyet-1077/hero.jpg',
    ARRAY['ly-thuong-kiet', 'nhu-nguyet', 'nha-ly', 'nam-quoc-son-ha'],
    'PUBLISHED',
    now(),
    now()
),
(
    '00000000-0000-0000-0000-000000000004'::uuid,
    'chien-dich-dien-bien-phu-1954',
    'Chiến Dịch Điện Biên Phủ 1954',
    'Thời kỳ Kháng chiến chống Pháp (1945 - 1954)',
    '13/03/1954 - 07/05/1954',
    1954,
    'Chiến thắng lừng lẫy năm châu, chấn động địa cầu, đập tan tập đoàn cứ điểm quân sự mạnh nhất Đông Dương của Pháp, quyết định thắng lợi trên bàn đàm phán Hiệp định Genève.',
    'Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm được quân Pháp coi là pháo đài bất khả xâm phạm. Dưới sự chỉ huy sáng suốt của Đại tướng Võ Nguyên Giáp, quân và dân ta đã thay đổi phương châm từ đánh nhanh thắng nhanh sang đánh chắc tiến chắc, đào hàng trăm km chiến hào siết chặt vòng vây, tiêu diệt hoàn toàn quân viễn chinh Pháp sau 56 ngày đêm chiến đấu kiên cường.',
    'Thung lũng Điện Biên Phủ, tỉnh Lai Châu (nay thuộc Điện Biên)',
    'events/dien-bien-phu-1954/hero.jpg',
    ARRAY['dien-bien-phu', 'vo-nguyen-giap', 'khang-chien-phap', 'muong-thanh', '1954'],
    'PUBLISHED',
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    era = EXCLUDED.era,
    period = EXCLUDED.period,
    start_year = EXCLUDED.start_year,
    summary = EXCLUDED.summary,
    description = EXCLUDED.description,
    location = EXCLUDED.location,
    cover_asset_key = EXCLUDED.cover_asset_key,
    tags = EXCLUDED.tags,
    status = EXCLUDED.status,
    updated_at = now();

-- ============================================================================
-- 2. HISTORICAL EVIDENCES
-- ============================================================================
INSERT INTO evidences (
    id, event_id, title, evidence_type, description, source_title, source_citation, status, created_at, updated_at
) VALUES
(
    '20000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Đại Việt Sử Ký Toàn Thư ghi chép về Trưng Nữ Vương',
    'HISTORICAL_TEXT',
    'Trưng Trắc, Trưng Nhị là phụ nữ, hô một tiếng mà các quận Giao Chỉ, Cửu Chân, Nhật Nam, Hợp Phố cùng 65 thành ở Lĩnh Ngoại đều hưởng ứng, dựng nước xưng vương dễ như trở bàn tay.',
    'Đại Việt Sử Ký Toàn Thư - Kỷ Trưng Nữ Vương',
    'Ngô Sĩ Liên, Đại Việt Sử Ký Toàn Thư, Bản kỷ Quyển III',
    'APPROVED',
    now(),
    now()
),
(
    '20000000-0000-0000-0000-000000000003'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid,
    'Bài thơ thần Nam Quốc Sơn Hà vang trên sông Như Nguyệt',
    'HISTORICAL_TEXT',
    'Nam quốc sơn hà Nam đế cư / Tiệt nhiên định phận tại thiên thư / Như hà nghịch lỗ lai xâm phạm / Nhữ đẳng hành khan thủ bại hư.',
    'Việt Điện U Linh Tập & Đại Việt Sử Ký Toàn Thư',
    'Lý Tế Xuyên, Việt Điện U Linh Tập & Khâm định Việt sử Thông giám Cương mục',
    'APPROVED',
    now(),
    now()
),
(
    '20000000-0000-0000-0000-000000000004'::uuid,
    '00000000-0000-0000-0000-000000000004'::uuid,
    'Mệnh lệnh chuyển phương châm tác chiến chiến dịch Điện Biên Phủ',
    'MILITARY_DOCUMENT',
    'Quyết định hoãn giờ nổ súng ngày 26/01/1954, lệnh kéo pháo ra để chuẩn bị thế trận theo phương châm Đánh chắc, tiến chắc.',
    'Hồi ký Điểm hẹn lịch sử',
    'Đại tướng Võ Nguyên Giáp, Điểm hẹn lịch sử, NXB Quân đội Nhân dân',
    'APPROVED',
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    source_title = EXCLUDED.source_title,
    source_citation = EXCLUDED.source_citation,
    status = EXCLUDED.status,
    updated_at = now();

-- ============================================================================
-- 3. LESSONS (INSERT AS DRAFT FIRST)
-- ============================================================================
INSERT INTO lessons (
    id, event_id, template_id, title, central_question, objectives_json, draft_json, status, current_version_id, created_at, updated_at, created_by, updated_by
) VALUES
(
    '10000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
    'Vì sao cuộc khởi nghĩa của Hai Bà Trưng được đông đảo nhân dân và các Lạc tướng khắp 65 thành trì hưởng ứng?',
    '["Hiểu rõ nguyên nhân sâu xa và trực tiếp của khởi nghĩa Mê Linh", "Phân tích lời thề Hát Môn và tinh thần bất khuất của phụ nữ Việt Nam", "Ý nghĩa lịch sử mở đầu trang sử đấu tranh chống Bắc thuộc"]'::jsonb,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-hbt-context", "type": "READ", "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa", "config": {"question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "nextStageIds": [], "activities": [{"id": "read-hbt-conclusion", "type": "READ", "required": true, "instruction": "Đúc kết bài học lịch sử", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    'DRAFT',
    NULL,
    now(),
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000001'::uuid
),
(
    '10000000-0000-0000-0000-000000000003'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Chiến Tuyến Sông Cầu: Bẻ Gãy Mưu Đồ Xâm Lược Nhà Tống',
    'Nghệ thuật quân sự độc đáo nào đã giúp quân dân nhà Lý đánh bại 10 vạn quân Tống xâm lược?',
    '["Nắm vững bối cảnh chiến trường phòng tuyến sông Như Nguyệt năm 1077", "Phân tích tác dụng của bài thơ thần Nam Quốc Sơn Hà trong chiến tranh tâm lý", "Đánh giá tài thao lược chủ động tấn công để phòng vệ của Thái úy Lý Thường Kiệt"]'::jsonb,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-ly-context", "type": "READ", "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt", "config": {"question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "nextStageIds": [], "activities": [{"id": "read-ly-conclusion", "type": "READ", "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    'DRAFT',
    NULL,
    now(),
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000001'::uuid
),
(
    '10000000-0000-0000-0000-000000000004'::uuid,
    '00000000-0000-0000-0000-000000000004'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Quyết Định Lịch Sử: Chuyển Phương Châm Tại Điện Biên Phủ',
    'Vì sao Đại tướng Võ Nguyên Giáp quyết định thay đổi phương châm từ Đánh nhanh thắng nhanh sang Đánh chắc tiến chắc?',
    '["Hiểu rõ cấu trúc tập đoàn cứ điểm Điện Biên Phủ của Pháp", "Phân tích nguyên nhân và tầm quan trọng của quyết định chuyển phương châm tác chiến ngày 26/1/1954", "Ý nghĩa chiến thắng Điện Biên Phủ đối với nền độc lập dân tộc"]'::jsonb,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-dbp-context", "type": "READ", "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến", "config": {"question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "nextStageIds": [], "activities": [{"id": "read-dbp-conclusion", "type": "READ", "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    'DRAFT',
    NULL,
    now(),
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000001'::uuid
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    central_question = EXCLUDED.central_question,
    objectives_json = EXCLUDED.objectives_json,
    draft_json = EXCLUDED.draft_json,
    updated_at = now();

-- ============================================================================
-- 4. LESSON VERSIONS
-- ============================================================================
INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by)
VALUES
(
    '30000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-hbt-context", "type": "READ", "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa", "config": {"question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "nextStageIds": [], "activities": [{"id": "read-hbt-conclusion", "type": "READ", "required": true, "instruction": "Đúc kết bài học lịch sử", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid
),
(
    '30000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-ly-context", "type": "READ", "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt", "config": {"question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "nextStageIds": [], "activities": [{"id": "read-ly-conclusion", "type": "READ", "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid
),
(
    '30000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-dbp-context", "type": "READ", "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến", "config": {"question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "nextStageIds": [], "activities": [{"id": "read-dbp-conclusion", "type": "READ", "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '00000000-0000-4000-8000-000000000001'::uuid
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 5. PUBLISH LESSONS
-- ============================================================================
UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000002'::uuid,
    updated_at = now()
WHERE id = '10000000-0000-0000-0000-000000000002'::uuid;

UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000003'::uuid,
    updated_at = now()
WHERE id = '10000000-0000-0000-0000-000000000003'::uuid;

UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000004'::uuid,
    updated_at = now()
WHERE id = '10000000-0000-0000-0000-000000000004'::uuid;

-- ============================================================================
-- 6. MAP LOCATIONS
-- ============================================================================
INSERT INTO map_locations (
    id, event_id, title, description, latitude, longitude, unlock_lesson_id, display_order, status, published_at
) VALUES
    ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'Khu di tích Đền Hùng', 'Núi Nghĩa Lĩnh, Phong Châu — nơi hội tụ linh khí non sông, nơi phụng thờ 18 đời Hùng Vương mở cõi dựng nước.', 21.3653, 105.3262, NULL, 1, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 'Làng Cổ Văn Lang & Ngã Ba Hạc', 'Nơi hợp lưu của ba con sông lớn sông Hồng, sông Lô và sông Đà — cái nôi của nền văn minh lúa nước và văn hóa Đông Sơn.', 21.3121, 105.4215, NULL, 2, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'Bến Bạch Đằng - Trận Địa Cọc', 'Cửa sông Bạch Đằng lịch sử — nơi Ngô Quyền cắm cọc vạt nhọn bọc sắt tiêu diệt hạm đội thuyền giặc Nam Hán năm 938.', 20.8492, 106.6891, NULL, 1, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'Bãi Cọc Yên Giang (Quảng Yên)', 'Chứng tích những thân gỗ lim cắm sâu lòng sông ngầm, biểu tượng mưu trí và sức mạnh quật cường của quân dân Việt.', 20.9324, 106.8123, NULL, 2, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 'Cửa Sông Nam Triệu', 'Cửa ngõ huyết mạch dẫn từ biển vào Bạch Đằng giang, nơi giặc lọt vào thế trận mai phục khi thủy triều rút kiệt.', 20.7801, 106.7902, NULL, 3, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002', 'Cửa Sông Hát (Hát Môn)', 'Nơi Hai Bà Trưng tế cờ khởi nghĩa mùa xuân năm 40, truyền vang lời thề cứu nước cứu dân đuổi quân đô hộ Đông Hán.', 21.1452, 105.5801, '10000000-0000-0000-0000-000000000002', 1, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000002', 'Thành Cổ Mê Linh', 'Trung tâm chỉ huy nghĩa quân và kinh đô sau khi Trưng Nữ Vương xưng vương, giành lại 65 thành trì Lĩnh Ngoại.', 21.1804, 105.7103, NULL, 2, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000003', 'Phòng Tuyến Sông Cầu', 'Phòng tuyến hiểm trở dài hàng trăm dặm do Lý Thường Kiệt đắp luỹ cắm chông chặn đứng 30 vạn quân Tống xâm lược.', 21.2175, 106.0024, '10000000-0000-0000-0000-000000000003', 1, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000003', 'Đền Xà - Bài Thơ Thần', 'Bản tuyên ngôn độc lập đầu tiên Nam Quốc Sơn Hà ngân vang giữa đêm trăng làm rung chuyển ý chí quân xâm lược.', 21.2051, 106.0182, NULL, 2, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000004', 'Cứ Điểm Đồi A1 (Eliane 2)', 'Trận địa đẫm máu then chốt bảo vệ trung tâm Mường Thanh, ngọn đồi quyết định cục diện chiến trường Điện Biên Phủ.', 21.3854, 103.0185, '10000000-0000-0000-0000-000000000004', 1, 'PUBLISHED', now()),
    ('a0000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000004', 'Hầm Tướng De Castries', 'Nơi cờ quyết chiến quyết thắng tung bay vào chiều ngày 7/5/1954, kết thúc 56 ngày đêm chấn động địa cầu.', 21.3882, 103.0151, NULL, 2, 'PUBLISHED', now())
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    unlock_lesson_id = EXCLUDED.unlock_lesson_id,
    display_order = EXCLUDED.display_order,
    status = EXCLUDED.status,
    published_at = EXCLUDED.published_at;
