-- Seed 3 new historical events and their published lessons + evidences
BEGIN;

-- 1. Insert 3 Historical Events
INSERT INTO historical_events (
    id, slug, title, era, period, start_year, summary, description, location, cover_asset_key, tags, status, created_at, updated_at
) VALUES
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
    'Lòng chảo Mường Thanh, Điện Biên Phủ',
    'events/dien-bien-phu-1954/hero.jpg',
    ARRAY['dien-bien-phu', 'vo-nguyen-giap', 'khang-chien-phap', 'muong-thanh', '1954'],
    'PUBLISHED',
    now(),
    now()
)
ON CONFLICT (slug) DO UPDATE SET
    title = EXCLUDED.title,
    summary = EXCLUDED.summary,
    description = EXCLUDED.description,
    status = EXCLUDED.status;

-- 2. Insert Evidences for the 3 events
INSERT INTO evidences (
    id, event_id, title, evidence_type, description, source_title, source_author, reliability, relevance, status, created_by, created_at, updated_at
) VALUES
(
    '20000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'Đại Việt Sử Ký Toàn Thư ghi chép về Trưng Nữ Vương',
    'HISTORICAL_TEXT',
    'Trưng Trắc, Trưng Nhị là phụ nữ, hô một tiếng mà các quận Giao Chỉ, Cửu Chân, Nhật Nam, Hợp Phố cùng 65 thành ở Lĩnh Ngoại đều hưởng ứng, dựng nước xưng vương dễ như trở bàn tay.',
    'Đại Việt Sử Ký Toàn Thư - Kỷ Trưng Nữ Vương',
    'Ngô Sĩ Liên',
    'HIGH',
    'Sử liệu quan trọng ghi nhận quy mô rộng lớn và sự ủng hộ tuyệt đối của nhân dân với cuộc khởi nghĩa.',
    'APPROVED',
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
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
    'Khuyết danh (tương truyền Lý Thường Kiệt)',
    'HIGH',
    'Tuyên ngôn độc lập đầu tiên, đòn chiến tranh tâm lý xuất sắc bẻ gãy ý chí quân Tống.',
    'APPROVED',
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
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
    'Đại tướng Võ Nguyên Giáp',
    'HIGH',
    'Chứng cứ lịch sử then chốt chứng minh sự thay đổi chiến thuật mang tính quyết định thắng lợi.',
    'APPROVED',
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    now(),
    now()
)
ON CONFLICT (id) DO NOTHING;

-- 3. Insert Lessons (initially as DRAFT without current_version_id to satisfy FK)
INSERT INTO lessons (
    id, event_id, template_id, title, central_question, objectives_json, draft_json, status, current_version_id, created_by, updated_by, created_at, updated_at
) VALUES
(
    '10000000-0000-0000-0000-000000000002'::uuid,
    '00000000-0000-0000-0000-000000000002'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa',
    'Vì sao cuộc khởi nghĩa của Hai Bà Trưng bùng nổ mạnh mẽ và thu phục 65 thành trì trên khắp Giao Chỉ?',
    '["Hiểu rõ nguyên nhân sâu xa và trực tiếp của cuộc khởi nghĩa Hai Bà Trưng", "Phân tích sức mạnh liên kết các bộ tộc và vai trò quật khởi của phụ nữ Lạc Việt"]'::jsonb,
    '{
      "schemaVersion": 1,
      "stages": [
        {
          "id": "ctx",
          "type": "CONTEXT",
          "title": "Bối cảnh lịch sử",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "read-hbt-context",
              "type": "READ",
              "required": false,
              "instruction": "Đọc tư liệu về sự cai trị hà khắc của Thái thú Tô Định và lời thề Hát Môn",
              "config": {
                "text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc người Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, bạo ngược. Khi Thi Sách (chồng Trưng Trắc) bị giết hại, Trưng Trắc cùng Trưng Nhị đã dựng cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ: Một xin rửa sạch quốc thù, Hai xin đem lại nghiệp xưa họ Hùng..."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Điều tra chứng cứ & Đánh giá",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "mc-hbt-cause",
              "type": "MULTIPLE_CHOICE",
              "required": true,
              "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa",
              "config": {
                "question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?",
                "options": [
                  {"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"},
                  {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"},
                  {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}
                ],
                "correctOptionIds": ["opt-1"]
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Ý nghĩa lịch sử",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "read-hbt-conclusion",
              "type": "READ",
              "required": false,
              "instruction": "Đúc kết bài học lịch sử",
              "config": {
                "text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống anh hùng của phụ nữ Việt Nam."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }'::jsonb,
    'DRAFT',
    NULL,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    now(),
    now()
),
(
    '10000000-0000-0000-0000-000000000003'::uuid,
    '00000000-0000-0000-0000-000000000003'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Chiến Tuyến Sông Cầu: Bẻ Gãy Mưu Đồ Xâm Lược Nhà Tống',
    'Lý Thường Kiệt đã kết hợp thế trận phòng ngự chủ động và đòn tâm lý Nam quốc sơn hà như thế nào để đánh bại quân Tống?',
    '["Nắm vững nghệ thuật chọn địa thế chiến lược tại sông Như Nguyệt", "Phân tích tác động tinh thần to lớn của bài thơ thần đối với sĩ khí hai bên"]'::jsonb,
    '{
      "schemaVersion": 1,
      "stages": [
        {
          "id": "ctx",
          "type": "CONTEXT",
          "title": "Bối cảnh chiến dịch",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "read-ly-context",
              "type": "READ",
              "required": false,
              "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt",
              "config": {
                "text": "Năm 1077, 10 vạn quân Tống do Quách Quỳ tiến sát bờ bắc sông Như Nguyệt. Thái úy Lý Thường Kiệt đã xây dựng phòng tuyến dài hơn 30km men bờ nam với lũy tre dày đặc và thuyền chiến cơ động, chặn đứng bước tiến của quân xâm lược trước cửa ngõ Thăng Long."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Nghệ thuật quân sự",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "mc-ly-tactic",
              "type": "MULTIPLE_CHOICE",
              "required": true,
              "instruction": "Chọn nhận định chính xác về chiến thuật",
              "config": {
                "question": "Điểm độc đáo nhất trong chiến thuật kháng chiến của Lý Thường Kiệt tại phòng tuyến Như Nguyệt là gì?",
                "options": [
                  {"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp tâm lý chiến"},
                  {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"},
                  {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}
                ],
                "correctOptionIds": ["opt-1"]
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Đúc kết bài học",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "read-ly-conclusion",
              "type": "READ",
              "required": false,
              "instruction": "Ý nghĩa lịch sử",
              "config": {
                "text": "Chiến thắng Như Nguyệt thể hiện đỉnh cao nghệ thuật quân sự Đại Việt: biết mình biết ta, đánh bại ý chí xâm lăng của kẻ thù mạnh hơn nhiều lần, bảo toàn trọn vẹn chủ quyền dân tộc."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }'::jsonb,
    'DRAFT',
    NULL,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    now(),
    now()
),
(
    '10000000-0000-0000-0000-000000000004'::uuid,
    '00000000-0000-0000-0000-000000000004'::uuid,
    'd7a00000-0000-4000-8000-000000000001'::uuid,
    'Quyết Định Lịch Sử: Chuyển Phương Châm Tại Điện Biên Phủ',
    'Vì sao quyết định chuyển từ Đánh nhanh thắng nhanh sang Đánh chắc tiến chắc là bước ngoặt quyết định của chiến dịch?',
    '["Hiểu rõ đặc điểm của tập đoàn cứ điểm Mường Thanh", "Thấy được bản lĩnh và tư duy quân sự sắc sảo của Đại tướng Võ Nguyên Giáp"]'::jsonb,
    '{
      "schemaVersion": 1,
      "stages": [
        {
          "id": "ctx",
          "type": "CONTEXT",
          "title": "Bối cảnh chiến dịch",
          "required": true,
          "nextStageIds": ["verify"],
          "activities": [
            {
              "id": "read-dbp-context",
              "type": "READ",
              "required": false,
              "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954",
              "config": {
                "text": "Ban đầu, kế hoạch dự kiến nổ súng đánh nhanh giải quyết trong vài ngày đêm. Nhưng khi trực tiếp thị sát trận địa, Đại tướng Võ Nguyên Giáp nhận thấy địch đã tăng cường công sự kiên cố, pháo binh và máy bay vượt trội. Đêm 25, rạng sáng 26/1/1954, một quyết định khó khăn nhất trong cuộc đời cầm quân đã được đưa ra: Hoãn nổ súng, kéo pháo ra, chuyển sang Đánh chắc tiến chắc."
              }
            }
          ]
        },
        {
          "id": "verify",
          "type": "VERIFICATION",
          "title": "Phân tích chiến lược",
          "required": true,
          "nextStageIds": ["conclusion"],
          "activities": [
            {
              "id": "mc-dbp-decision",
              "type": "MULTIPLE_CHOICE",
              "required": true,
              "instruction": "Đánh giá về quyết định chuyển phương châm",
              "config": {
                "question": "Vì sao phương châm Đánh chắc, tiến chắc là chìa khóa mở ra chiến thắng Điện Biên Phủ?",
                "options": [
                  {"id": "opt-1", "label": "Giúp bộ đội xây dựng mạng lưới chiến hào siết chặt, bóc dỡ từng cứ điểm và triệt tiêu ưu thế pháo binh, không quân địch"},
                  {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"},
                  {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về giữ đồng bằng Bắc Bộ"}
                ],
                "correctOptionIds": ["opt-1"]
              }
            }
          ]
        },
        {
          "id": "conclusion",
          "type": "CONCLUSION",
          "title": "Tổng kết chiến thắng",
          "required": true,
          "nextStageIds": [],
          "activities": [
            {
              "id": "read-dbp-conclusion",
              "type": "READ",
              "required": false,
              "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ",
              "config": {
                "text": "Chiến thắng Điện Biên Phủ ngày 7/5/1954 đã đập tan tập đoàn cứ điểm kiên cố nhất của thực dân Pháp, ghi vào lịch sử dân tộc như một Bạch Đằng, Chi Lăng của thế kỷ 20."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }'::jsonb,
    'DRAFT',
    NULL,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    now(),
    now()
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    central_question = EXCLUDED.central_question,
    objectives_json = EXCLUDED.objectives_json,
    draft_json = EXCLUDED.draft_json;

-- 4. Insert Lesson Versions (Published Snapshot)
INSERT INTO lesson_versions (
    id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by
) VALUES
(
    '30000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    1,
    1,
    (SELECT draft_json FROM lessons WHERE id = '10000000-0000-0000-0000-000000000002'::uuid),
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
),
(
    '30000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    1,
    1,
    (SELECT draft_json FROM lessons WHERE id = '10000000-0000-0000-0000-000000000003'::uuid),
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
),
(
    '30000000-0000-0000-0000-000000000004'::uuid,
    '10000000-0000-0000-0000-000000000004'::uuid,
    1,
    1,
    (SELECT draft_json FROM lessons WHERE id = '10000000-0000-0000-0000-000000000004'::uuid),
    now(),
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid
)
ON CONFLICT (id) DO NOTHING;

-- 5. Update Lessons to PUBLISHED with current_version_id
UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000002'::uuid
WHERE id = '10000000-0000-0000-0000-000000000002'::uuid;

UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000003'::uuid
WHERE id = '10000000-0000-0000-0000-000000000003'::uuid;

UPDATE lessons SET
    status = 'PUBLISHED',
    current_version_id = '30000000-0000-0000-0000-000000000004'::uuid
WHERE id = '10000000-0000-0000-0000-000000000004'::uuid;

COMMIT;
