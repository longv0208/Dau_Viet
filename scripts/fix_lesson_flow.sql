
BEGIN;

-- 1. Xóa các attempt cũ liên quan đến 3 bài học này để tránh xung đột trạng thái
DELETE FROM activity_attempts WHERE learner_attempt_id IN (
    SELECT id FROM learner_attempts WHERE lesson_version_id IN (
        '30000000-0000-0000-0000-000000000002'::uuid,
        '30000000-0000-0000-0000-000000000003'::uuid,
        '30000000-0000-0000-0000-000000000004'::uuid
    )
);

DELETE FROM learner_attempts WHERE lesson_version_id IN (
    '30000000-0000-0000-0000-000000000002'::uuid,
    '30000000-0000-0000-0000-000000000003'::uuid,
    '30000000-0000-0000-0000-000000000004'::uuid
);

-- 2. Tạm thời vô hiệu hóa trigger chống sửa lesson_versions
ALTER TABLE lesson_versions DISABLE TRIGGER trg_lesson_versions_immutable;

-- 3. Đổi trạng thái sang DRAFT và ngắt current_version_id
UPDATE lessons SET status = 'DRAFT', current_version_id = NULL WHERE id IN (
    '10000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid
);

-- 4. Xóa lesson_versions cũ
DELETE FROM lesson_versions WHERE id IN (
    '30000000-0000-0000-0000-000000000002'::uuid,
    '30000000-0000-0000-0000-000000000003'::uuid,
    '30000000-0000-0000-0000-000000000004'::uuid
);

-- 5. Cập nhật draft_json cho lessons (dùng dollar quoting $$...$$)
UPDATE lessons SET draft_json = $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-hbt-context", "type": "READ", "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa", "config": {"question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "nextStageIds": [], "activities": [{"id": "read-hbt-conclusion", "type": "READ", "required": true, "instruction": "Đúc kết bài học lịch sử", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb WHERE id = '10000000-0000-0000-0000-000000000002'::uuid;
UPDATE lessons SET draft_json = $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-ly-context", "type": "READ", "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt", "config": {"question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "nextStageIds": [], "activities": [{"id": "read-ly-conclusion", "type": "READ", "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb WHERE id = '10000000-0000-0000-0000-000000000003'::uuid;
UPDATE lessons SET draft_json = $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-dbp-context", "type": "READ", "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến", "config": {"question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "nextStageIds": [], "activities": [{"id": "read-dbp-conclusion", "type": "READ", "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb WHERE id = '10000000-0000-0000-0000-000000000004'::uuid;

-- 6. Tạo mới lesson_versions chuẩn UTF-8 và required: true
INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by)
VALUES
(
    '30000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-hbt-context", "type": "READ", "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\n\nMột xin rửa sạch quốc thù,\nHai xin đem lại nghiệp xưa họ Hùng,\nBa kẻo oan ức lòng chồng,\nBốn xin vẹn vẹn sở công lênh này.\n\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa", "config": {"question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "nextStageIds": [], "activities": [{"id": "read-hbt-conclusion", "type": "READ", "required": true, "instruction": "Đúc kết bài học lịch sử", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
),
(
    '30000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-ly-context", "type": "READ", "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt", "config": {"question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "nextStageIds": [], "activities": [{"id": "read-ly-conclusion", "type": "READ", "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
),
(
    '30000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid,
    1,
    1,
    $${"schemaVersion": 1, "stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "nextStageIds": ["verify"], "activities": [{"id": "read-dbp-context", "type": "READ", "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}}]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "nextStageIds": ["conclusion"], "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến", "config": {"question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "correctOptionIds": ["opt-1"]}}]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "nextStageIds": [], "activities": [{"id": "read-dbp-conclusion", "type": "READ", "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}}]}], "completion": {"requireAllRequiredStages": true}}$$::jsonb,
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
);

-- 7. Bật lại trigger trg_lesson_versions_immutable
ALTER TABLE lesson_versions ENABLE TRIGGER trg_lesson_versions_immutable;

-- 8. Gán lại current_version_id và trạng thái PUBLISHED
UPDATE lessons SET status = 'PUBLISHED', current_version_id = '30000000-0000-0000-0000-000000000002'::uuid WHERE id = '10000000-0000-0000-0000-000000000002'::uuid;
UPDATE lessons SET status = 'PUBLISHED', current_version_id = '30000000-0000-0000-0000-000000000003'::uuid WHERE id = '10000000-0000-0000-0000-000000000003'::uuid;
UPDATE lessons SET status = 'PUBLISHED', current_version_id = '30000000-0000-0000-0000-000000000004'::uuid WHERE id = '10000000-0000-0000-0000-000000000004'::uuid;

COMMIT;
