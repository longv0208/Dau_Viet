-- Dấu Việt | V15 | Animation Engine seed — 2 templates + 3 published scenes.
-- Idempotent: every INSERT is ON CONFLICT DO NOTHING. event_id stays NULL:
-- seed scenes are template-bound, not event-bound, and historical_events
-- rows are environment data, not migration-owned.
-- checksum = SHA-256 of the stored snapshot_json text (UTF-8), same recipe
-- as AnimationScenePublishService.sha256(write(snapshot)) — the canonical
-- text of what is persisted/learner-facing, not the bare draft manifest.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';
    tpl_river UUID := 'd7a10000-0000-4000-8000-000000000001';
    tpl_map   UUID := 'd7a10000-0000-4000-8000-000000000002';
    sc_bach_dang UUID := 'd7a20000-0000-4000-8000-000000000001';
    sc_hai_ba   UUID := 'd7a20000-0000-4000-8000-000000000002';
    sc_ly_thai  UUID := 'd7a20000-0000-4000-8000-000000000003';
    v_bach_dang UUID := 'd7a30000-0000-4000-8000-000000000001';
    v_hai_ba    UUID := 'd7a30000-0000-4000-8000-000000000002';
    v_ly_thai   UUID := 'd7a30000-0000-4000-8000-000000000003';
    m_bach_dang JSONB;
    m_hai_ba JSONB;
    m_ly_thai JSONB;
    s_bach_dang TEXT;
    s_hai_ba TEXT;
    s_ly_thai TEXT;
BEGIN
    -- Bootstrap system user — owns seeded publish rows. password_hash is a
    -- non-BCrypt sentinel so no credential can ever authenticate as it.
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System',
            'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO animation_templates (id, code, name, description, renderer_code, renderer_version, schema_version, capabilities_json, default_config_json)
    VALUES
        (tpl_river, 'RIVER_TIDE', 'Sông & thủy triều',
         'Cảnh sông với mực nước lên xuống, chướng ngại ngầm và thuyền di chuyển.',
         'RIVER_TIDE', 1, 1,
         '{"interactions":["WATER_LEVEL_CONTROL","PREDICTION"],"stateKeys":["waterLevel","boatProgress","decoyProgress","counterattackProgress","obstructed","highlightStakes","showSequenceSummary"]}'::jsonb,
         '{}'::jsonb),
        (tpl_map, 'JOURNEY_MAP', 'Hành trình bản đồ',
         'Bản đồ schematic với địa điểm, tuyến di chuyển và marker tương tác.',
         'JOURNEY_MAP', 1, 1,
         '{"interactions":["TAP_TO_EXPLORE","PREDICTION"],"stateKeys":["markerVisibility","routeProgress","markerHighlight","focusedLocationId"]}'::jsonb,
         '{}'::jsonb)
    ON CONFLICT (code) DO NOTHING;

    /* ============ SCENE 1 — Trận Bạch Đằng năm 938 (RIVER_TIDE) ============ */
    m_bach_dang := '{
      "schemaVersion": 1,
      "rendererCode": "RIVER_TIDE",
      "rendererVersion": 1,
      "title": "Trận Bạch Đằng năm 938",
      "learningObjective": "Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều, việc dụ thuyền địch và thời điểm phản công phối hợp trong chiến thắng Bạch Đằng.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [],
      "objects": [],
      "initialState": {},
      "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"],
      "disclaimer": "Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng chính xác trận đánh.",
      "sourceReferences": [
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Ngô Quyền và chiến thắng Bạch Đằng năm 938\" (baotanglichsuquocgia.vn)."}
      ],
      "river": {"stakes": [
        {"id": "stake-1", "x": 0.42, "length": 0.20},
        {"id": "stake-2", "x": 0.47, "length": 0.22},
        {"id": "stake-3", "x": 0.52, "length": 0.17},
        {"id": "stake-4", "x": 0.57, "length": 0.24},
        {"id": "stake-5", "x": 0.62, "length": 0.19},
        {"id": "stake-6", "x": 0.45, "length": 0.16},
        {"id": "stake-7", "x": 0.55, "length": 0.21},
        {"id": "stake-8", "x": 0.65, "length": 0.23},
        {"id": "stake-9", "x": 0.60, "length": 0.18}
      ]},
      "steps": [
        {"id": "prepare", "title": "Chuẩn bị", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — sử liệu không ghi bố trí chính xác từng cọc.",
         "hint": "Quan sát vị trí các cọc nhô lên từ đáy sông.",
         "targetState": {"waterLevel": 0.30, "boatProgress": 0.0, "obstructed": false}},
        {"id": "tide-rise", "title": "Nước dâng", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại vật đang ẩn phía dưới.",
         "hint": "Kéo thanh mực nước để tự thấy cọc bị che đi.",
         "allowedInteractions": ["WATER_LEVEL_CONTROL"],
         "targetState": {"waterLevel": 0.90, "boatProgress": 0.0, "obstructed": false}},
        {"id": "decoy", "title": "Dụ địch vào bãi", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Trên sơ đồ, thuyền xanh lục (phòng thủ) đi trước dẫn hướng đoàn địch tiến vào — đây là chỉ báo sơ đồ chiến thuật, không phải lộ trình cụ thể được ghi lại.",
         "hint": "Thuyền dụ địch (buồm xanh lục) và vệt đường dẫn nét đứt đi trước đoàn địch về phía bãi cọc.",
         "targetState": {"waterLevel": 0.90, "boatProgress": 0.72, "obstructed": false, "decoyProgress": 1}},
        {"id": "tide-fall", "title": "Nước rút", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra. Đường đi của thuyền bỗng trở nên nguy hiểm.",
         "hint": "Thử kéo mực nước xuống thấp để thấy cọc lộ rõ.",
         "allowedInteractions": ["WATER_LEVEL_CONTROL"],
         "targetState": {"waterLevel": 0.28, "boatProgress": 0.85, "obstructed": false, "decoyProgress": 1}},
        {"id": "counterattack", "title": "Phản công phối hợp", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Sử liệu ghi nhận quân ta đã đánh úp, phối hợp phản công đúng lúc triều hạ. Trên sơ đồ, thuyền phòng thủ (buồm xanh lục) tiến vào từ phía sau cùng mũi tên phối hợp hướng về bãi — minh họa hướng tác chiến, không phải đội hình hay vị trí thật.",
         "hint": "Thuyền địch mắc cọc + thuyền xanh lục tiến vào từ mép trái + mũi tên phối hợp cùng hướng.",
         "targetState": {"waterLevel": 0.28, "boatProgress": 0.85, "obstructed": true, "decoyProgress": 1, "counterattackProgress": 1}},
        {"id": "summary", "title": "Tổng kết", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Chiến thắng đến từ một chuỗi chủ động: chuẩn bị bãi cọc → tính toán nhịp thủy triều → dụ thuyền địch vào đúng lúc nước lớn → vật cản khống chế → phản công phối hợp khi triều rút. Cơ chế vật lý chỉ là một phần của mưu lược — sơ đồ bên trên tóm tắt lại trình tự đó.",
         "hint": "Sơ đồ chuỗi 5 giai đoạn: đây là kết luận, không phải một cảnh hành động mới.",
         "effects": ["SHOW_SEQUENCE_SUMMARY"],
         "targetState": {"waterLevel": 0.28, "boatProgress": 0.85, "obstructed": true, "decoyProgress": 1, "counterattackProgress": 1, "showSequenceSummary": true}}
      ],
      "prediction": {
        "question": "Khi nước triều rút xuống, điều gì thay đổi đối với thuyền tiến vào khu vực bãi cọc?",
        "options": [
          {"text": "Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi."},
          {"text": "Các cọc dần lộ ra, khiến thuyền khó di chuyển."}
        ],
        "explainedOptionIndex": 1,
        "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông. Thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này — chính là cơ chế khiến đội hình địch bị khống chế để phản công.",
        "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ? Thuyền nổi trên mặt nước sẽ chạm vào đâu?",
        "revealTargetState": {"waterLevel": 0.22, "boatProgress": 0.85, "obstructed": true, "highlightStakes": true}
      }
    }'::jsonb;

    /* ============ SCENE 2 — Khởi nghĩa Hai Bà Trưng năm 40 (JOURNEY_MAP) ============ */
    m_hai_ba := '{
      "schemaVersion": 1,
      "rendererCode": "JOURNEY_MAP",
      "rendererVersion": 1,
      "title": "Khởi nghĩa Hai Bà Trưng năm 40",
      "learningObjective": "Nhận biết các địa điểm then chốt của cuộc khởi nghĩa năm 40 và hiểu vai trò của Luy Lâu như trung tâm cai trị của nhà Hán.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [],
      "objects": [],
      "initialState": {},
      "interactions": ["TAP_TO_EXPLORE", "PREDICTION"],
      "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay phục dựng chính xác đường đi.",
      "sourceReferences": [
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\" (baotanglichsuquocgia.vn)."}
      ],
      "map": {
        "locations": [
          {"id": "hat-mon", "name": "Hát Môn", "x": 0.30, "y": 0.62,
           "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40 theo truyền thống lịch sử được ghi nhận rộng rãi.",
           "contextLabel": "Nơi phát khởi"},
          {"id": "me-linh", "name": "Mê Linh", "x": 0.48, "y": 0.42,
           "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng, người dân các vùng lân cận hưởng ứng cuộc khởi nghĩa.",
           "contextLabel": "Nơi quy tụ"},
          {"id": "luy-lau", "name": "Luy Lâu", "x": 0.72, "y": 0.34,
           "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới.",
           "contextLabel": "Trung tâm Hán"}
        ],
        "routes": [
          {"id": "gather", "from": "hat-mon", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}],
           "explanation": "Từ điểm phát khởi, lực lượng và người dân quy tụ về Mê Linh — sơ đồ minh họa, không phải đường đi cụ thể."},
          {"id": "advance", "from": "me-linh", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}],
           "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu, trung tâm cai trị của nhà Hán — tuyến chỉ mang tính minh họa hướng phát triển."}
        ]
      },
      "steps": [
        {"id": "context", "title": "Bối cảnh", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Sơ đồ chỉ gợi ý một số địa điểm tiêu biểu — không phải bản đồ hành chính của thời kỳ đó.",
         "hint": "Quan sát sơ đồ khu vực rồi tiếp tục.",
         "targetState": {"markerVisibility": {}}},
        {"id": "outbreak", "title": "Khởi nghĩa bùng lên", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Năm 40, cuộc khởi nghĩa do Hai Bà Trưng khởi xướng bắt đầu ở khu vực sông Hát / Hát Môn. Sử liệu không ghi lại vị trí chính xác từng điểm — đây chỉ là minh họa vùng.",
         "hint": "Địa điểm sáng lên là nơi khởi nghĩa bắt đầu.",
         "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}},
        {"id": "gather", "title": "Quy tụ lực lượng", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Từ điểm phát khởi, lực lượng và người dân các nơi quy tụ về Mê Linh — quê hương của Hai Bà Trưng. Tuyến nối trên sơ đồ là minh họa sự lan rộng, không khẳng định đường đi thật.",
         "hint": "Tuyến nét đứt chỉ mang tính sơ đồ hóa quan hệ giữa hai vùng.",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1}, "routeProgress": {"gather": 1}, "focusedLocationId": "me-linh"}},
        {"id": "advance", "title": "Hướng về Luy Lâu", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Cuộc khởi nghĩa lan rộng và hướng tới Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, nơi đặt bộ máy cai trị của Tô Định.",
         "hint": "Vì sao Luy Lâu lại là điểm quan trọng?",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "focusedLocationId": "luy-lau"}},
        {"id": "explore", "title": "Khám phá bản đồ", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Chạm vào từng địa điểm để đọc ý nghĩa lịch sử của nó. Mỗi địa điểm là một mảnh của bức tranh khởi nghĩa: nơi phát khởi, nơi quy tụ và mục tiêu chính trị.",
         "hint": "Thử chạm vào Hát Môn, Mê Linh và Luy Lâu.",
         "allowedInteractions": ["TAP_TO_EXPLORE"],
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}}},
        {"id": "meaning", "title": "Ý nghĩa", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ và trực tiếp thách thức bộ máy cai trị của nhà Hán tại Luy Lâu. Tuy nhiên, đây mới là giai đoạn đầu — cuộc đấu tranh còn kéo dài và chưa mang lại độc lập lâu dài ngay lúc đó.",
         "hint": "Có thể tua lại các bước hoặc chạm địa điểm để xem lại.",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"]}}
      ],
      "prediction": {
        "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?",
        "options": [
          {"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."},
          {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới."}
        ],
        "explainedOptionIndex": 1,
        "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ. Việc cuộc khởi nghĩa hướng về Luy Lâu cho thấy sức lan tỏa của phong trào và thách thức trực tiếp đến bộ máy cai trị — chứ không chỉ là một cuộc nổi dậy cục bộ.",
        "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị — thử suy nghĩ về vai trò đó.",
        "revealTargetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "focusedLocationId": "luy-lau"}
      }
    }'::jsonb;

    /* ============ SCENE 3 — Lý Thái Tổ dời đô năm 1010 (JOURNEY_MAP) ============ */
    m_ly_thai := '{
      "schemaVersion": 1,
      "rendererCode": "JOURNEY_MAP",
      "rendererVersion": 1,
      "title": "Lý Thái Tổ dời đô năm 1010",
      "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới và ý nghĩa lâu dài của quyết định dời đô năm 1010.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [],
      "objects": [],
      "initialState": {},
      "interactions": ["TAP_TO_EXPLORE", "PREDICTION"],
      "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay đường đi thực tế của triều đình.",
      "sourceReferences": [
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Thăng Long thời nhà Lý (1009–1225)\" và \"Hà Nội — địa linh nhân kiệt\" (baotanglichsuquocgia.vn)."}
      ],
      "map": {
        "locations": [
          {"id": "hoa-lu", "name": "Hoa Lư", "x": 0.28, "y": 0.70,
           "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê, kinh đô cũ trước khi triều Lý quyết định dời đô năm 1010.",
           "contextLabel": "Kinh đô cũ"},
          {"id": "dai-la", "name": "Đại La — Thăng Long", "x": 0.62, "y": 0.40,
           "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010, sau đổi tên thành Thăng Long. Đại La và Thăng Long là CÙNG một địa điểm, không phải hai thành khác nhau.",
           "contextLabel": "Kinh đô mới"}
        ],
        "routes": [
          {"id": "relocation", "from": "hoa-lu", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}],
           "explanation": "Dời kinh đô từ Hoa Lư về Đại La — tuyến minh họa khái niệm, không phải đường đi hay đường thủy thật."}
        ]
      },
      "steps": [
        {"id": "old-capital", "title": "Hoa Lư — kinh đô cũ", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê — trung tâm chính trị trước khi nhà Lý lên ngôi. Địa thế núi non hiểm trở phù hợp phòng thủ nhưng hạn chế cho phát triển lâu dài.",
         "hint": "Địa điểm sáng lên là kinh đô cũ.",
         "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}},
        {"id": "considering", "title": "Cân nhắc dời đô", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Sau khi lên ngôi, Lý Thái Tổ và triều thần cân nhắc vị trí kinh đô. Theo tư liệu truyền thống, việc chọn địa điểm mới gắn với cân nhắc về địa thế và hướng phát triển lâu dài của đất nước — sử liệu không ghi đầy đủ mọi lý do cụ thể.",
         "hint": "Vì sao một kinh đô mới lại được cân nhắc?",
         "targetState": {"markerVisibility": {"hoa-lu": 1}}},
        {"id": "chosen", "title": "Đại La được chọn", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Năm 1010, Lý Thái Tổ chọn vùng thành Đại La làm kinh đô mới. Vị trí trung tâm vùng đồng bằng, thuận lợi giao thông và phát triển — theo cách hiểu được ghi nhận trong tư liệu.",
         "hint": "Địa điểm mới xuất hiện là kinh đô được chọn.",
         "targetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "focusedLocationId": "dai-la"}},
        {"id": "relocated", "title": "Dời đô năm 1010", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Quyết định dời đô từ Hoa Lư về Đại La được thực hiện năm 1010. Tuyến nối trên sơ đồ chỉ minh họa quan hệ giữa hai địa điểm — không phải đường đi hay hành trình cụ thể của triều đình.",
         "hint": "Tuyến đứt nét là sơ đồ khái niệm, không phải đường thật.",
         "targetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "routeProgress": {"relocation": 1}, "focusedLocationId": "dai-la"}},
        {"id": "thang-long", "title": "Thăng Long", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Kinh đô mới ở Đại La được đặt tên Thăng Long — \"rồng bay lên\". Quyết định năm 1010 đặt nền móng cho một trung tâm chính trị lâu dài, gắn với Hà Nội ngày nay.",
         "hint": "Chạm vào từng địa điểm để đọc vai trò của nó.",
         "allowedInteractions": ["TAP_TO_EXPLORE"],
         "targetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"]}}
      ],
      "prediction": {
        "question": "Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?",
        "options": [
          {"text": "Hoa Lư — kinh đô cũ được giữ nguyên."},
          {"text": "Đại La — sau này mang tên Thăng Long."}
        ],
        "explainedOptionIndex": 1,
        "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long. Đại La và Thăng Long là cùng một địa điểm — quyết định này gắn với cân nhắc địa thế trung tâm và tầm phát triển lâu dài.",
        "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện ở bước \"Đại La được chọn\"?",
        "revealTargetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "focusedLocationId": "dai-la"}
      }
    }'::jsonb;

    -- Insert as DRAFT first: chk_animation_scene_published_version requires
    -- current_version_id to be set BEFORE status can become PUBLISHED, and
    -- CHECK constraints are evaluated per-row at statement time (not deferrable).
    INSERT INTO animation_scenes (id, template_id, event_id, title, draft_json, status, created_by, updated_by)
    VALUES
        (sc_bach_dang, tpl_river, NULL, 'Trận Bạch Đằng năm 938', m_bach_dang, 'DRAFT', sys_user, sys_user),
        (sc_hai_ba,    tpl_map,   NULL, 'Khởi nghĩa Hai Bà Trưng năm 40', m_hai_ba, 'DRAFT', sys_user, sys_user),
        (sc_ly_thai,   tpl_map,   NULL, 'Lý Thái Tổ dời đô năm 1010', m_ly_thai, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO NOTHING;

    -- Published snapshots — checksum over the snapshot text as stored.
    s_bach_dang := m_bach_dang::text;
    s_hai_ba := m_hai_ba::text;
    s_ly_thai := m_ly_thai::text;

    INSERT INTO animation_scene_versions
        (id, scene_id, version_no, schema_version, renderer_code, renderer_version,
         snapshot_json, manifest_checksum, published_by)
    VALUES
        (v_bach_dang, sc_bach_dang, 1, 1, 'RIVER_TIDE', 1, s_bach_dang::jsonb,
         encode(digest(s_bach_dang, 'sha256'), 'hex'), sys_user),
        (v_hai_ba, sc_hai_ba, 1, 1, 'JOURNEY_MAP', 1, s_hai_ba::jsonb,
         encode(digest(s_hai_ba, 'sha256'), 'hex'), sys_user),
        (v_ly_thai, sc_ly_thai, 1, 1, 'JOURNEY_MAP', 1, s_ly_thai::jsonb,
         encode(digest(s_ly_thai, 'sha256'), 'hex'), sys_user)
    ON CONFLICT (id) DO NOTHING;

    UPDATE animation_scenes SET current_version_id = v_bach_dang WHERE id = sc_bach_dang AND current_version_id IS NULL;
    UPDATE animation_scenes SET current_version_id = v_hai_ba   WHERE id = sc_hai_ba   AND current_version_id IS NULL;
    UPDATE animation_scenes SET current_version_id = v_ly_thai  WHERE id = sc_ly_thai  AND current_version_id IS NULL;

    -- Pointer in place, now safe to mark PUBLISHED (CHECK satisfied per-row).
    UPDATE animation_scenes SET status = 'PUBLISHED'
    WHERE id IN (sc_bach_dang, sc_hai_ba, sc_ly_thai)
      AND status <> 'PUBLISHED';
END $$;
