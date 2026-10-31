-- Dấu Việt | V63 | 4-Step Learning Flow: FOUR_STEP template + Bạch Đằng v3 snapshot + 1 non-animation lesson
-- Issue #52: unified 4-step flow:
--   Step 1 TRUY TÌM DẤU VẾT  (DISCOVERY, 4 clues CONTEXT/CHARACTERS/DEVELOPMENT/SIGNIFICANCE, any order)
--   Step 2 ĐẶT GIẢ THUYẾT   (HYPOTHESIS, exactly 1 activity)
--   Step 3 KIỂM CHỨNG        (VERIFICATION, interactive — selectedEvidenceIds, linked to chosen hypothesis)
--   Step 4 TÁI HIỆN SỰ KIỆN  (RECONSTRUCTION, any activity type; animation optional)
--
-- Idempotent: ON CONFLICT guards on lesson_templates, lesson_versions;
-- trg_lesson_versions_immutable disabled during migration and re-enabled at the end.

ALTER TABLE lesson_versions DISABLE TRIGGER trg_lesson_versions_immutable;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';

    -- Canonical lesson / version IDs
    les_bd       UUID := 'd7b20000-0000-4000-8000-000000000001';   -- Bạch Đằng 938 (existing)
    les_hbt      UUID := '10000000-0000-0000-0000-000000000002';   -- Hai Bà Trưng năm 40 (existing)
    ver_bd_v3    UUID := '63000000-0000-4000-8000-000000000001';
    ver_hbt_v3   UUID := '63000000-0000-4000-8000-000000000002';
    tpl_fourstep UUID := '63000000-0000-4000-8000-000000000010';

    -- Event IDs (resolved from lessons at runtime)
    evt_bd  UUID;
    evt_hbt UUID;

    -- Thematic asset IDs (resolved at runtime; may be NULL)
    asset_bach_dang_coc UUID;
    asset_ngoquyen_hero UUID;
    asset_tran_dia_coc  UUID;
    asset_thu_phong     UUID;
    asset_me_linh       UUID;
    asset_doanh_trai    UUID;

    d_bd4  JSONB;
    d_hbt4 JSONB;
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System', 'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    -- Resolve owning event_id from existing lessons (with slug fallback)
    SELECT event_id INTO evt_bd FROM lessons WHERE id = les_bd;
    IF evt_bd IS NULL THEN
        SELECT id INTO evt_bd FROM historical_events WHERE slug = 'bach-dang-938' LIMIT 1;
    END IF;

    SELECT event_id INTO evt_hbt FROM lessons WHERE id = les_hbt;
    IF evt_hbt IS NULL THEN
        SELECT id INTO evt_hbt FROM historical_events WHERE id = '00000000-0000-0000-0000-000000000002'::uuid;
    END IF;

    -- Resolve thematic assets seeded in earlier migrations (nullable — coverAssetId is optional)
    SELECT id INTO asset_bach_dang_coc FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000003'::uuid;
    SELECT id INTO asset_tran_dia_coc  FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000008'::uuid;
    SELECT id INTO asset_thu_phong     FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000010'::uuid;
    SELECT id INTO asset_ngoquyen_hero FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000011'::uuid;
    SELECT id INTO asset_me_linh       FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000002'::uuid;
    SELECT id INTO asset_doanh_trai    FROM assets WHERE id = 'd7a70000-0000-4000-8000-000000000009'::uuid;

    -- =========================================================================
    -- 1. FOUR_STEP LESSON TEMPLATE (alongside HISTORY_INVESTIGATION)
    -- =========================================================================
    INSERT INTO lesson_templates (
        id, code, name, description, schema_version, preset_json, enabled
    ) VALUES (
        tpl_fourstep,
        'FOUR_STEP',
        'Điều tra 4 bước — Truy tìm dấu vết',
        'Luồng học tập 4 bước (Issue #52): Truy tìm 4 dấu vết → Đặt giả thuyết → Kiểm chứng → Tái hiện sự kiện.',
        1,
        '{
          "schemaVersion": 1,
          "flowModel": "FOUR_STEP",
          "keyTakeaways": [],
          "stages": [
            {
              "id": "discovery",
              "type": "DISCOVERY",
              "title": "Truy tìm Dấu vết",
              "required": true,
              "allowFreeOrder": true,
              "description": "Tìm hiểu bốn dấu vết cốt lõi về sự kiện lịch sử theo bất kỳ thứ tự nào.",
              "activities": [],
              "nextStageIds": ["hypothesis"]
            },
            {
              "id": "hypothesis",
              "type": "HYPOTHESIS",
              "title": "Đặt Giả thuyết",
              "required": true,
              "activities": [],
              "nextStageIds": ["verification"]
            },
            {
              "id": "verification",
              "type": "VERIFICATION",
              "title": "Kiểm chứng Giả thuyết",
              "required": true,
              "activities": [],
              "nextStageIds": ["reconstruction"]
            },
            {
              "id": "reconstruction",
              "type": "RECONSTRUCTION",
              "title": "Tái hiện Sự kiện",
              "required": true,
              "activities": [],
              "nextStageIds": []
            }
          ],
          "completion": {"requireAllRequiredStages": true}
        }'::jsonb,
        true
    )
    ON CONFLICT (code) DO UPDATE SET
        preset_json = EXCLUDED.preset_json,
        description = EXCLUDED.description;

    -- =========================================================================
    -- 2. BẠCH ĐẰNG 938 — V3 SNAPSHOT (4-step flow)
    -- =========================================================================
    d_bd4 := $draft$ {
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Ngô Quyền lợi dụng địa hình cửa sông và quy luật thủy triều để đánh bại quân Nam Hán năm 938",
        "Trận Bạch Đằng kết thúc ách Bắc thuộc, mở ra thời kỳ độc lập lâu dài của dân tộc",
        "Nghệ thuật quân sự sáng tạo: biến địa hình tự nhiên thành vũ khí chiến lược"
      ],
      "stages": [
        {
          "id": "discovery",
          "type": "DISCOVERY",
          "title": "Truy tìm Dấu vết",
          "required": true,
          "allowFreeOrder": true,
          "description": "Tìm hiểu bốn dấu vết cốt lõi về chiến thắng Bạch Đằng năm 938 — bạn có thể khám phá theo bất kỳ thứ tự nào.",
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "clue-context",
              "type": "READ",
              "required": true,
              "clueType": "CONTEXT",
              "title": "Bối cảnh Bắc thuộc và ý chí độc lập",
              "description": "Ngô Quyền lãnh đạo phong trào giải phóng khỏi ách Nam Hán sau hơn 1000 năm Bắc thuộc",
              "coverAssetId": null,
              "instruction": "Đọc bối cảnh trận Bạch Đằng năm 938",
              "config": {
                "text": "Năm 938, quân Nam Hán sai tướng Lưu Hoằng Tháo đem thủy quân vượt biển sang đánh nước ta. Ngô Quyền lãnh đạo nghĩa quân chuẩn bị trận đánh lớn tại cửa sông Bạch Đằng — nơi địa hình cửa sông và quy luật thủy triều trở thành vũ khí chiến lược."
              }
            },
            {
              "id": "clue-characters",
              "type": "READ",
              "required": true,
              "clueType": "CHARACTERS",
              "title": "Ngô Quyền và Lưu Hoằng Tháo",
              "description": "Đối đầu hai tướng: Ngô Quyền hiểu địa hình — Lưu Hoằng Tháo kiêu ngạo quân viễn chinh",
              "coverAssetId": null,
              "instruction": "Tìm hiểu hai nhân vật chính trong trận Bạch Đằng năm 938",
              "config": {
                "text": "Ngô Quyền (897–944) là người Ái Châu, am hiểu sông nước Bạch Đằng và quy luật thủy triều. Ông chọn trận địa cọc ngầm làm điểm quyết chiến. Lưu Hoằng Tháo là tướng trẻ Nam Hán, quân viễn chinh mỏi mệt, thiếu hiểu biết về địa hình cửa sông."
              }
            },
            {
              "id": "clue-development",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "clueType": "DEVELOPMENT",
              "title": "Diễn biến trận đánh — thủy triều và bãi cọc",
              "description": "Khám phá chiến thuật kết hợp cọc ngầm và thủy triều của Ngô Quyền",
              "coverAssetId": null,
              "instruction": "Chọn các dấu vết lịch sử mô tả diễn biến trận Bạch Đằng năm 938",
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
                  "51000000-0000-4000-8000-000000000102"
                ],
                "minRequired": 2,
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Đúng! Cọc gỗ lim và thủy triều chính là hai yếu tố quyết định diễn biến trận Bạch Đằng.",
                "PARTIAL": "Bạn đã chọn một phần đúng. Hãy ưu tiên bằng chứng về bãi cọc ngầm và chế độ thủy triều.",
                "INCORRECT": "Chưa đúng — diễn biến trận Bạch Đằng xoay quanh việc thủy triều dâng/rút và bãi cọc ngầm.",
                "EXHAUSTED": "Đã hết lượt. Dấu vết cốt lõi: cọc gỗ lim bịt sắt đóng ngầm dưới nước, thủy triều lên che cọc rồi rút làm thuyền mắc cọc."
              }
            },
            {
              "id": "clue-significance",
              "type": "MULTIPLE_CHOICE",
              "required": true,
              "clueType": "SIGNIFICANCE",
              "title": "Ý nghĩa lịch sử của chiến thắng",
              "description": "Hiểu giá trị của trận Bạch Đằng trong lịch sử dân tộc",
              "coverAssetId": null,
              "instruction": "Chọn phát biểu mô tả đúng ý nghĩa lịch sử của chiến thắng Bạch Đằng năm 938",
              "config": {
                "graded": true,
                "question": "Phát biểu nào mô tả đúng ý nghĩa lịch sử của chiến thắng Bạch Đằng năm 938?",
                "options": [
                  {"id": "sig-a", "label": "Chấm dứt hoàn toàn ách đô hộ của phương Bắc, mở ra thời kỳ độc lập lâu dài của dân tộc"},
                  {"id": "sig-b", "label": "Là trận chiến duy nhất Ngô Quyền từng thắng trong sự nghiệp"},
                  {"id": "sig-c", "label": "Đánh dấu lần đầu tiên Việt Nam đánh bại một đế quốc phương Bắc"},
                  {"id": "sig-d", "label": "Chỉ có ý nghĩa tượng trưng, không thay đổi tình hình chính trị"}
                ],
                "correctOptionIds": ["sig-a"],
                "maxAttempts": 2
              },
              "feedback": {
                "COMPLETED": "Chính xác! Trận Bạch Đằng chấm dứt ách Bắc thuộc và mở ra thời kỳ độc lập lâu dài.",
                "PARTIAL": "Gần đúng — hãy nghĩ về hệ quả chính trị lớn nhất của trận thắng này.",
                "INCORRECT": "Chưa đúng. Ý nghĩa lịch sử lớn nhất là chấm dứt hoàn toàn ách đô hộ phương Bắc.",
                "EXHAUSTED": "Đã hết lượt. Chiến thắng Bạch Đằng năm 938 chấm dứt ách Bắc thuộc, mở ra thời kỳ độc lập lâu dài."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt Giả thuyết",
          "required": true,
          "description": "Từ bốn dấu vết đã thu thập, hãy chọn giả thuyết hợp lý nhất giải thích chiến thắng của Ngô Quyền.",
          "nextStageIds": ["verification"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Từ các dấu vết đã khám phá, hãy chọn giả thuyết giải thích đúng nhất thắng lợi của Ngô Quyền năm 938",
              "config": {
                "prompt": "Giả thuyết nào phản ánh đúng bản chất nghệ thuật quân sự của Ngô Quyền tại sông Bạch Đằng năm 938?",
                "hypotheses": [
                  {"id": "h-tide",   "label": "Ngô Quyền thắng nhờ kết hợp trận địa cọc ngầm, quy luật nhật triều và mưu nhử địch đúng thời điểm"},
                  {"id": "h-number", "label": "Ngô Quyền thắng vì sở hữu hạm đội chiến thuyền lớn hơn và quân số áp đảo quân Nam Hán"},
                  {"id": "h-storm",  "label": "Thủy quân Nam Hán tự tan vỡ do gặp bão lớn ngoài cửa biển trước khi vào sông Bạch Đằng"}
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phù hợp với dữ kiện lịch sử.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verification",
          "type": "VERIFICATION",
          "title": "Kiểm chứng Giả thuyết",
          "required": true,
          "description": "Đối chiếu giả thuyết đã chọn với các dấu vết lịch sử — chọn bằng chứng hỗ trợ giả thuyết của bạn.",
          "nextStageIds": ["reconstruction"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Chọn các dấu vết chứng minh giả thuyết bạn vừa đặt",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
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
                "SUPPORTED": "Kiểm chứng thành công! Giả thuyết về thế trận cọc ngầm và thủy triều hoàn toàn khớp với bằng chứng.",
                "PARTIAL": "Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy rà soát lại các dấu vết cốt lõi.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh bởi bằng chứng.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Thủy triều dâng che cọc và rút nhanh làm thuyền Nam Hán mắc cọc chính là mấu chốt chiến thắng."
              }
            }
          ]
        },
        {
          "id": "reconstruction",
          "type": "RECONSTRUCTION",
          "title": "Tái hiện Sự kiện",
          "required": true,
          "description": "Sắp xếp lại trình tự diễn biến trận Bạch Đằng năm 938 theo đúng diễn tiến thời gian.",
          "nextStageIds": [],
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
                "COMPLETED": "Xuất sắc! Bạn đã tái hiện chính xác toàn bộ diễn biến trận thủy chiến Bạch Đằng năm 938.",
                "PARTIAL": "Một số bước đã đúng vị trí — chú ý trình tự: đóng cọc → nhử địch khi triều lên → phản công khi triều rút.",
                "INCORRECT": "Thứ tự diễn biến chưa đúng. Hãy bắt đầu từ khâu chuẩn bị bãi cọc trước khi quân Nam Hán tiến vào.",
                "EXHAUSTED": "Đã hết lượt sắp xếp. Trình tự chuẩn: Đóng cọc → Nhử địch → Triều lên che cọc → Phản công → Triều rút thuyền mắc cọc → Địch tan vỡ."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- Fill nullable coverAssetIds after resolving assets
    IF asset_tran_dia_coc IS NOT NULL THEN
        d_bd4 := jsonb_set(d_bd4,
            '{stages,0,activities,0,coverAssetId}', to_jsonb(asset_tran_dia_coc::text), true);
    END IF;
    IF asset_ngoquyen_hero IS NOT NULL THEN
        d_bd4 := jsonb_set(d_bd4,
            '{stages,0,activities,1,coverAssetId}', to_jsonb(asset_ngoquyen_hero::text), true);
    END IF;
    IF asset_bach_dang_coc IS NOT NULL THEN
        d_bd4 := jsonb_set(d_bd4,
            '{stages,0,activities,2,coverAssetId}', to_jsonb(asset_bach_dang_coc::text), true);
    END IF;
    IF asset_thu_phong IS NOT NULL THEN
        d_bd4 := jsonb_set(d_bd4,
            '{stages,0,activities,3,coverAssetId}', to_jsonb(asset_thu_phong::text), true);
    END IF;

    UPDATE lessons
    SET draft_json = d_bd4,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_bd;

    INSERT INTO lesson_versions (
        id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by
    ) VALUES
        (ver_bd_v3, les_bd, 3, 1, d_bd4, now(), sys_user)
    ON CONFLICT (id) DO UPDATE SET
        snapshot_json = EXCLUDED.snapshot_json,
        published_at  = now();

    UPDATE lessons
    SET current_version_id = ver_bd_v3,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_bd;

    -- =========================================================================
    -- 3. HAI BÀ TRƯNG 40 — V3 SNAPSHOT (4-step flow, no animation)
    -- =========================================================================
    d_hbt4 := $draft$ {
      "schemaVersion": 1,
      "flowModel": "FOUR_STEP",
      "keyTakeaways": [
        "Hai Bà Trưng lãnh đạo cuộc khởi nghĩa hạ gục chính quyền đô hộ Đông Hán năm 40",
        "Khởi nghĩa Hai Bà Trưng là biểu tượng của ý chí độc lập và vai trò phụ nữ Việt Nam",
        "65 thành trì hưởng ứng cho thấy sự đồng thuận rộng rãi của nhân dân Lạc Việt"
      ],
      "stages": [
        {
          "id": "discovery",
          "type": "DISCOVERY",
          "title": "Truy tìm Dấu vết",
          "required": true,
          "allowFreeOrder": true,
          "description": "Tìm hiểu bốn dấu vết về cuộc khởi nghĩa Hai Bà Trưng năm 40 — bạn có thể khám phá theo bất kỳ thứ tự nào.",
          "nextStageIds": ["hypothesis"],
          "activities": [
            {
              "id": "clue-context",
              "type": "READ",
              "required": true,
              "clueType": "CONTEXT",
              "title": "Bối cảnh chính quyền Đông Hán đô hộ",
              "description": "Đất nước chịu ách cai trị của nhà Hán và khởi nguồn tinh thần kháng chiến",
              "coverAssetId": null,
              "instruction": "Đọc bối cảnh khởi nghĩa Hai Bà Trưng năm 40",
              "config": {
                "text": "Đầu thế kỷ I, đất nước nằm dưới ách đô hộ của nhà Hán. Tô Định — viên Thái thú Giao Chỉ — tăng thuế má, thống trị hà khắc. Trong bối cảnh đó, Trưng Trắc và Trưng Nhị, hai chị em con rể Lạc tướng Mê Linh, đứng lên kêu gọi quần chúng phất cờ khởi nghĩa."
              }
            },
            {
              "id": "clue-characters",
              "type": "READ",
              "required": true,
              "clueType": "CHARACTERS",
              "title": "Trưng Trắc, Trưng Nhị và các nữ tướng",
              "description": "Những người phụ nữ Lạc Việt lãnh đạo cuộc khởi nghĩa",
              "coverAssetId": null,
              "instruction": "Tìm hiểu các nhân vật chính trong khởi nghĩa Hai Bà Trưng",
              "config": {
                "text": "Trưng Trắc và Trưng Nhị là hai chị em con rể của Lạc tướng Mê Linh — tầng lớp lãnh đạo bản địa Lạc Việt. Hai bà cùng các nữ tướng Lê Chân, Thánh Thiên, Phùng Thị Chính huy động hào kiệt và nhân dân bốn quận đồng loạt nổi dậy chống chính quyền đô hộ Đông Hán."
              }
            },
            {
              "id": "clue-development",
              "type": "EVIDENCE_SELECT",
              "required": true,
              "clueType": "DEVELOPMENT",
              "title": "Diễn biến khởi nghĩa năm 40",
              "description": "Khám phá cách cuộc khởi nghĩa lan rộng và giành thắng lợi",
              "coverAssetId": null,
              "instruction": "Chọn các dấu vết lịch sử mô tả diễn biến khởi nghĩa Hai Bà Trưng năm 40",
              "config": {
                "graded": true,
                "visibleEvidenceIds": [
                  "51000000-0000-4000-8000-000000000201",
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000203",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "acceptedEvidenceIds": [
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "minRequired": 2,
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Đúng! Lời thề Hát Môn và 65 thành trì hưởng ứng là hai dấu vết quan trọng nhất.",
                "PARTIAL": "Bạn đã chọn một phần đúng. Hãy tìm bằng chứng về quy mô và tinh thần của cuộc khởi nghĩa.",
                "INCORRECT": "Chưa đúng — diễn biến khởi nghĩa xoay quanh lời thề Hát Môn và sự hưởng ứng của 65 thành trì.",
                "EXHAUSTED": "Đã hết lượt. Dấu vết cốt lõi: Lời thề Hát Môn bốn câu và sự kiện 65 thành Lĩnh Ngoại đồng loạt quy phục."
              }
            },
            {
              "id": "clue-significance",
              "type": "MULTIPLE_CHOICE",
              "required": true,
              "clueType": "SIGNIFICANCE",
              "title": "Ý nghĩa lịch sử của khởi nghĩa",
              "description": "Hiểu giá trị của khởi nghĩa Hai Bà Trưng trong lịch sử dân tộc",
              "coverAssetId": null,
              "instruction": "Chọn phát biểu mô tả đúng ý nghĩa lịch sử của khởi nghĩa Hai Bà Trưng năm 40",
              "config": {
                "graded": true,
                "question": "Phát biểu nào mô tả đúng ý nghĩa lịch sử của khởi nghĩa Hai Bà Trưng năm 40?",
                "options": [
                  {"id": "sig-a", "label": "Lập lại chủ quyền dân tộc sau 200 năm Bắc thuộc, khẳng định vai trò phụ nữ trong lịch sử Việt Nam"},
                  {"id": "sig-b", "label": "Chỉ là cuộc nổi dậy nhỏ không ảnh hưởng đến chính trị đương thời"},
                  {"id": "sig-c", "label": "Cuộc khởi nghĩa cuối cùng của người Việt trước khi hoàn toàn bị đô hộ"},
                  {"id": "sig-d", "label": "Đánh dấu sự kết thúc của triều đại nhà Hán trên bản đồ thế giới"}
                ],
                "correctOptionIds": ["sig-a"],
                "maxAttempts": 2
              },
              "feedback": {
                "COMPLETED": "Chính xác! Khởi nghĩa Hai Bà Trưng lập lại chủ quyền dân tộc và khẳng định vai trò phụ nữ Việt.",
                "PARTIAL": "Gần đúng — hãy nghĩ về hệ quả chính trị và biểu tượng văn hóa của cuộc khởi nghĩa.",
                "INCORRECT": "Chưa đúng. Ý nghĩa lịch sử là lập lại chủ quyền dân tộc sau hơn 200 năm Bắc thuộc.",
                "EXHAUSTED": "Đã hết lượt. Khởi nghĩa Hai Bà Trưng năm 40 lập lại chủ quyền dân tộc, biểu tượng vai trò phụ nữ Việt Nam."
              }
            }
          ]
        },
        {
          "id": "hypothesis",
          "type": "HYPOTHESIS",
          "title": "Đặt Giả thuyết",
          "required": true,
          "description": "Từ bốn dấu vết đã thu thập, hãy chọn giả thuyết giải thích thắng lợi của khởi nghĩa Hai Bà Trưng.",
          "nextStageIds": ["verification"],
          "activities": [
            {
              "id": "hc",
              "type": "HYPOTHESIS_CHOICE",
              "required": true,
              "instruction": "Từ các dấu vết đã khám phá, hãy chọn giả thuyết giải thích đúng nhất sức mạnh của khởi nghĩa Hai Bà Trưng năm 40",
              "config": {
                "prompt": "Giả thuyết nào giải thích đúng nhất nguyên nhân thành công của khởi nghĩa Hai Bà Trưng năm 40?",
                "hypotheses": [
                  {"id": "h-unity",   "label": "Khởi nghĩa thắng nhờ sự đồng thuận rộng rãi của nhân dân và uy tín của các Lạc tướng lãnh đạo"},
                  {"id": "h-army",    "label": "Khởi nghĩa thắng vì quân Hai Bà Trưng có vũ khí hiện đại vượt trội quân Đông Hán"},
                  {"id": "h-collapse","label": "Chính quyền Đông Hán tự rút lui do nội bộ triều đình suy yếu, không liên quan đến khởi nghĩa"}
                ]
              },
              "feedback": {
                "COMPLETED": "Đã ghi nhận giả thuyết của bạn — chuyển sang bước Kiểm chứng.",
                "PARTIAL": "Đã ghi nhận một phần giả thuyết.",
                "INCORRECT": "Giả thuyết chưa phù hợp với dữ kiện lịch sử.",
                "EXHAUSTED": "Đã hết lượt chọn giả thuyết."
              }
            }
          ]
        },
        {
          "id": "verification",
          "type": "VERIFICATION",
          "title": "Kiểm chứng Giả thuyết",
          "required": true,
          "description": "Đối chiếu giả thuyết đã chọn với các dấu vết lịch sử — chọn bằng chứng hỗ trợ giả thuyết của bạn.",
          "nextStageIds": ["reconstruction"],
          "activities": [
            {
              "id": "vf",
              "type": "VERIFICATION",
              "required": true,
              "instruction": "Chọn các dấu vết chứng minh giả thuyết bạn vừa đặt",
              "onPartial": "discovery",
              "onContradicted": "hypothesis",
              "config": {
                "expectedHypothesis": "h-unity",
                "visibleSourceIds": [
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "requiredEvidenceIds": [
                  "51000000-0000-4000-8000-000000000202",
                  "51000000-0000-4000-8000-000000000204"
                ],
                "maxAttempts": 3
              },
              "feedback": {
                "SUPPORTED": "Kiểm chứng thành công! Giả thuyết về sức mạnh đồng thuận nhân dân hoàn toàn khớp với bằng chứng.",
                "PARTIAL": "Giả thuyết đúng hướng nhưng bộ bằng chứng còn thiếu. Hãy rà soát lại các dấu vết cốt lõi.",
                "CONTRADICTED": "Bằng chứng lịch sử bác bỏ giả thuyết này — hãy quay lại chọn giả thuyết phù hợp hơn.",
                "COMPLETED": "Kiểm chứng hoàn tất — giả thuyết được chứng minh.",
                "INCORRECT": "Giả thuyết chưa được chứng minh bởi bằng chứng.",
                "EXHAUSTED": "Đã hết lượt kiểm chứng. Lời thề Hát Môn và 65 thành hưởng ứng là bằng chứng rõ nhất về sự đồng thuận nhân dân."
              }
            }
          ]
        },
        {
          "id": "reconstruction",
          "type": "RECONSTRUCTION",
          "title": "Tái hiện Sự kiện",
          "required": true,
          "description": "Sắp xếp lại trình tự diễn biến khởi nghĩa Hai Bà Trưng năm 40 theo đúng diễn tiến thời gian.",
          "nextStageIds": [],
          "activities": [
            {
              "id": "do",
              "type": "DRAG_ORDER",
              "required": true,
              "instruction": "Sắp xếp lại trình tự diễn biến khởi nghĩa Hai Bà Trưng năm 40 theo đúng diễn tiến thời gian",
              "config": {
                "items": [
                  {"id": "s1", "label": "Chính quyền Tô Định đô hộ hà khắc, thuế nặng bất công"},
                  {"id": "s2", "label": "Trưng Trắc phất cờ khởi nghĩa tại Mê Linh, Trưng Nhị hưởng ứng"},
                  {"id": "s3", "label": "Lời thề Hát Môn bốn câu được vạc rộng, hào kiệt các nơi hưởng ứng"},
                  {"id": "s4", "label": "Nghĩa quân đánh chiếm Cổ Loa, bao vây trị sở Luy Lâu"},
                  {"id": "s5", "label": "Tô Định trốn về nước, chính quyền đô hộ Đông Hán sụp đổ"},
                  {"id": "s6", "label": "65 thành trì đồng loạt quy phục, hai bà lên ngôi Trưng Vương"}
                ],
                "expectedOrder": ["s1", "s2", "s3", "s4", "s5", "s6"],
                "maxAttempts": 3
              },
              "feedback": {
                "COMPLETED": "Xuất sắc! Bạn đã tái hiện chính xác diễn biến khởi nghĩa Hai Bà Trưng năm 40.",
                "PARTIAL": "Một số bước đã đúng vị trí — chú ý trình tự: Tô Định đô hộ → Trưng Trắc phất cờ → Lời thề Hát Môn.",
                "INCORRECT": "Thứ tự diễn biến chưa đúng. Hãy bắt đầu từ bối cảnh chính quyền Tô Định đô hộ.",
                "EXHAUSTED": "Đã hết lượt sắp xếp. Trình tự chuẩn: Tô Định đô hộ → Phất cờ khởi nghĩa → Lời thề Hát Môn → Đánh Cổ Loa → Tô Định trốn → 65 thành quy phục."
              }
            }
          ]
        }
      ],
      "completion": {"requireAllRequiredStages": true}
    }$draft$::jsonb;

    -- Fill nullable coverAssetIds for Hai Bà Trưng
    IF asset_me_linh IS NOT NULL THEN
        d_hbt4 := jsonb_set(d_hbt4,
            '{stages,0,activities,0,coverAssetId}', to_jsonb(asset_me_linh::text), true);
        d_hbt4 := jsonb_set(d_hbt4,
            '{stages,0,activities,1,coverAssetId}', to_jsonb(asset_me_linh::text), true);
    END IF;
    IF asset_doanh_trai IS NOT NULL THEN
        d_hbt4 := jsonb_set(d_hbt4,
            '{stages,0,activities,3,coverAssetId}', to_jsonb(asset_doanh_trai::text), true);
    END IF;

    UPDATE lessons
    SET draft_json = d_hbt4,
        updated_by = sys_user,
        updated_at = now()
    WHERE id = les_hbt;

    INSERT INTO lesson_versions (
        id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by
    ) VALUES
        (ver_hbt_v3, les_hbt, 3, 1, d_hbt4, now(), sys_user)
    ON CONFLICT (id) DO UPDATE SET
        snapshot_json = EXCLUDED.snapshot_json,
        published_at  = now();

    UPDATE lessons
    SET current_version_id = ver_hbt_v3,
        status = 'PUBLISHED',
        updated_at = now()
    WHERE id = les_hbt;

END $$;

-- =============================================================================
-- 4. EMBED EVIDENCE[] AND ASSETS[] INTO NEW LESSON_VERSIONS SNAPSHOT_JSON
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
    '63000000-0000-4000-8000-000000000001'::uuid,
    '63000000-0000-4000-8000-000000000002'::uuid
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
    UNION ALL
    SELECT value #>> '{}' AS a_id
    FROM lesson_versions lv2,
      jsonb_path_query(lv2.snapshot_json, '$.stages[*].activities[*].coverAssetId') AS j(value)
    WHERE lv2.id = lv.id
  ) t
  WHERE lv.id IN (
    '63000000-0000-4000-8000-000000000001'::uuid,
    '63000000-0000-4000-8000-000000000002'::uuid
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
    '63000000-0000-4000-8000-000000000001'::uuid,
    '63000000-0000-4000-8000-000000000002'::uuid
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
