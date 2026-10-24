-- Dấu Việt | V16 | Cinematic 2.5D demo scenes — 3 v2 scenes (schemaVersion=2).
-- Extends V15 with camera/tracks/effects/audio/environment — v1 scenes stay
-- PUBLISHED intact (new scene ids; snapshots immutable). Audio cues reference
-- assets[] role AUDIO — seeded empty (no real audio file in repo); admins
-- upload + re-publish via admin UI. Idempotent: ON CONFLICT DO NOTHING.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';
    tpl_river UUID := 'd7a10000-0000-4000-8000-000000000001';
    tpl_map   UUID := 'd7a10000-0000-4000-8000-000000000002';
    sc_bd_cine UUID := 'd7a40000-0000-4000-8000-000000000001';
    sc_hb_cine UUID := 'd7a40000-0000-4000-8000-000000000002';
    sc_lt_cine UUID := 'd7a40000-0000-4000-8000-000000000003';
    v_bd_cine  UUID := 'd7a50000-0000-4000-8000-000000000001';
    v_hb_cine  UUID := 'd7a50000-0000-4000-8000-000000000002';
    v_lt_cine  UUID := 'd7a50000-0000-4000-8000-000000000003';
    m_bd_cine JSONB;
    m_hb_cine JSONB;
    m_lt_cine JSONB;
    s_bd_cine TEXT;
    s_hb_cine TEXT;
    s_lt_cine TEXT;
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System',
            'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    /* Audio fixture — silent WAV (seed-assets/silence.wav, 46B). Row
       chỉ đăng ký asset ACTIVE để manifests[].audio.assetRef resolve
       được; file bytes phải có ở {dauviet.assets.dir}/d7a60000-...-0001.wav
       (dev copy bằng tay từ seed-assets/, hoặc upload lại qua admin UI).
       Thiếu file → controller serve 404 nhưng scene vẫn render (audio
       cue no-op theo contract v2). */
    INSERT INTO assets (id, storage_key, original_filename, mime_type,
                        size_bytes, state, alt_text, created_by)
    VALUES ('d7a60000-0000-4000-8000-000000000001',
            'assets/d7a60000-0000-4000-8000-000000000001.wav',
            'silence.wav', 'audio/wav', 46, 'ACTIVE',
            'Silent ambience fixture for cinematic demo scenes',
            sys_user)
    ON CONFLICT (id) DO NOTHING;

    /* ============ SCENE 1 — Bạch Đằng 938 (RIVER_TIDE v2 cinematic) ============
       Camera zooms vào bãi cọc khi nước rút; track animates decoy boat; mist
       ambient; audio placeholder (empty cues — upload via admin). */
    m_bd_cine := '{
      "schemaVersion": 2,
      "rendererCode": "RIVER_TIDE",
      "rendererVersion": 1,
      "title": "Trận Bạch Đằng năm 938 — Cinematic",
      "learningObjective": "Hiểu mối liên hệ giữa bãi cọc, thủy triều, việc dụ địch và phản công phối hợp — qua lăng kính điện ảnh: camera pan/zoom, object chuyển động, hiệu ứng môi trường.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [
        {"id": "amb-river", "assetId": "d7a60000-0000-4000-8000-000000000001",
         "role": "AUDIO"}
      ],
      "objects": [
        {"id": "boat-decoy", "type": "BOAT",
         "position": {"x": 0.15, "y": 0.45}, "scale": 0.14, "layer": 1,
         "visible": true, "rotation": 0, "opacity": 1}
      ],
      "initialState": {},
      "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"],
      "disclaimer": "Sơ đồ minh họa chiến thuật + cinematic camera — không theo tỉ lệ, không phải phục dựng chính xác trận đánh.",
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
      "environment": {"mist": 0.35, "glow": 0.2},
      "camera": {
        "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0},
        "steps": [
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}},
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}},
          {"target": {"x": 0.55, "y": 0.55, "zoom": 1.2, "focusObjectId": "boat-decoy"}},
          {"target": {"x": 0.52, "y": 0.55, "zoom": 1.6}},
          {"target": {"x": 0.55, "y": 0.5, "zoom": 1.8}},
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}
        ]
      },
      "tracks": [
        {"objectId": "boat-decoy", "property": "position",
         "keyframes": [
           {"tMs": 0, "value": {"x": 0.15, "y": 0.45}, "easing": "linear"},
           {"tMs": 2200, "value": {"x": 0.45, "y": 0.42}, "easing": "linear"},
           {"tMs": 4400, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"},
           {"tMs": 6600, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"}
         ]},
        {"objectId": "boat-decoy", "property": "rotation",
         "keyframes": [
           {"tMs": 0, "value": 0, "easing": "easeInOut"},
           {"tMs": 4400, "value": 0, "easing": "easeInOut"},
           {"tMs": 6600, "value": -25, "easing": "easeInOut"}
         ]}
      ],
      "effects": [
        {"type": "MIST", "params": {"intensity": 0.3}},
        {"type": "WATER_RIPPLE", "stepId": "tide-fall", "durationMs": 2200,
         "params": {"x": 0.55, "y": 0.62, "intensity": 0.7}},
        {"type": "GLOW", "stepId": "counterattack", "durationMs": 2200,
         "params": {"x": 0.55, "y": 0.45, "intensity": 0.5, "objectId": "boat-decoy"}},
        {"type": "FADE_OUT", "stepId": "summary", "durationMs": 800}
      ],
      "audio": [
        {"stepId": "prepare", "assetRef": "amb-river", "cue": "LOOP", "volume": 0.4},
        {"stepId": "tide-fall", "assetRef": "amb-river", "cue": "ENTER", "volume": 0.5},
        {"stepId": "counterattack", "assetRef": "amb-river", "cue": "ENTER", "volume": 0.7},
        {"stepId": "summary", "assetRef": "amb-river", "cue": "EXIT", "fadeMs": 600}
      ],
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
         "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Thuyền dụ địch (track keyframe) trượt về phía bãi.",
         "hint": "Camera theo thuyền dụ vào vùng bãi cọc.",
         "targetState": {"waterLevel": 0.90, "boatProgress": 0.72, "obstructed": false, "decoyProgress": 1}},
        {"id": "tide-fall", "title": "Nước rút", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra — camera zoom vào bãi cọc; gợn nước đánh dấu điểm mấu chốt.",
         "hint": "Camera zoom + ripple overlay đánh dấu bãi cọc lộ.",
         "allowedInteractions": ["WATER_LEVEL_CONTROL"],
         "targetState": {"waterLevel": 0.28, "boatProgress": 0.85, "obstructed": false, "decoyProgress": 1}},
        {"id": "counterattack", "title": "Phản công phối hợp", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Camera zoom sâu hơn; glow quanh thuyền dụ đánh dấu điểm dồn lực phản công.",
         "hint": "Glow + camera zoom tối đa khi phản công.",
         "targetState": {"waterLevel": 0.28, "boatProgress": 0.85, "obstructed": true, "decoyProgress": 1, "counterattackProgress": 1}},
        {"id": "summary", "title": "Tổng kết", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Chiến thắng đến từ chuỗi chủ động: chuẩn bị bãi cọc → tính nhịp thủy triều → dụ địch → khống chế → phản công. Fade out khép lại cảnh điện ảnh.",
         "hint": "Fade out kết thúc cinematic.",
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
        "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông — thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này.",
        "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ?",
        "revealTargetState": {"waterLevel": 0.22, "boatProgress": 0.85, "obstructed": true, "highlightStakes": true}
      }
    }'::jsonb;

    /* ============ SCENE 2 — Hai Bà Trưng 40 (JOURNEY_MAP v2 cinematic) ============
       Camera pan giữa các địa điểm; ROUTE_REVEAL + glow per step. */
    m_hb_cine := '{
      "schemaVersion": 2,
      "rendererCode": "JOURNEY_MAP",
      "rendererVersion": 1,
      "title": "Khởi nghĩa Hai Bà Trưng năm 40 — Cinematic",
      "learningObjective": "Nhận biết các địa điểm then chốt qua camera pan điện ảnh + route reveal — Hát Môn, Mê Linh, Luy Lâu.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [
        {"id": "amb-battle", "assetId": "d7a60000-0000-4000-8000-000000000001",
         "role": "AUDIO"}
      ],
      "objects": [],
      "initialState": {},
      "interactions": ["TAP_TO_EXPLORE", "PREDICTION"],
      "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.",
      "sourceReferences": [
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\" (baotanglichsuquocgia.vn)."}
      ],
      "map": {
        "locations": [
          {"id": "hat-mon", "name": "Hát Môn", "x": 0.30, "y": 0.62,
           "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40.",
           "contextLabel": "Nơi phát khởi"},
          {"id": "me-linh", "name": "Mê Linh", "x": 0.48, "y": 0.42,
           "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng.",
           "contextLabel": "Nơi quy tụ"},
          {"id": "luy-lau", "name": "Luy Lâu", "x": 0.72, "y": 0.34,
           "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ.",
           "contextLabel": "Trung tâm Hán"}
        ],
        "routes": [
          {"id": "gather", "from": "hat-mon", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}],
           "explanation": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh."},
          {"id": "advance", "from": "me-linh", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}],
           "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu."}
        ]
      },
      "camera": {
        "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0},
        "steps": [
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}},
          {"target": {"x": 0.3, "y": 0.62, "zoom": 1.4, "focusLocationId": "hat-mon"}},
          {"target": {"x": 0.48, "y": 0.42, "zoom": 1.4, "focusLocationId": "me-linh"}},
          {"target": {"x": 0.72, "y": 0.34, "zoom": 1.5, "focusLocationId": "luy-lau"}},
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}},
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}
        ]
      },
      "tracks": [],
      "effects": [
        {"type": "FADE_IN", "stepId": "context", "durationMs": 800},
        {"type": "GLOW", "stepId": "outbreak", "durationMs": 2200,
         "params": {"x": 0.30, "y": 0.62, "intensity": 0.6}},
        {"type": "GLOW", "stepId": "advance", "durationMs": 2200,
         "params": {"x": 0.72, "y": 0.34, "intensity": 0.6}},
        {"type": "FADE_OUT", "stepId": "meaning", "durationMs": 1000}
      ],
      "audio": [
        {"stepId": "context", "assetRef": "amb-battle", "cue": "ENTER", "volume": 0.4},
        {"stepId": "outbreak", "assetRef": "amb-battle", "cue": "ENTER", "volume": 0.5},
        {"stepId": "gather", "assetRef": "amb-battle", "cue": "ENTER", "volume": 0.5},
        {"stepId": "advance", "assetRef": "amb-battle", "cue": "ENTER", "volume": 0.6},
        {"stepId": "meaning", "assetRef": "amb-battle", "cue": "EXIT", "fadeMs": 800}
      ],
      "steps": [
        {"id": "context", "title": "Bối cảnh", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Fade in mở màn.",
         "hint": "Fade in đánh dấu mở cảnh.",
         "targetState": {"markerVisibility": {}}},
        {"id": "outbreak", "title": "Khởi nghĩa bùng lên", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Năm 40, cuộc khởi nghĩa bùng lên ở sông Hát / Hát Môn. Camera zoom vào điểm phát khởi với glow đánh dấu.",
         "hint": "Camera pan + zoom vào Hát Môn, glow nhấn điểm phát khởi.",
         "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}},
        {"id": "gather", "title": "Quy tụ lực lượng", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh. Camera tiếp tục pan theo hướng di chuyển.",
         "hint": "Camera pan sang Mê Linh, route reveal trên bản đồ.",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1}, "routeProgress": {"gather": 1}, "focusedLocationId": "me-linh"}},
        {"id": "advance", "title": "Hướng về Luy Lâu", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Cuộc khởi nghĩa hướng tới Luy Lâu — camera zoom sâu nhất khi nhắm trung tâm cai trị Hán.",
         "hint": "Zoom mạnh nhất tại Luy Lâu.",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "focusedLocationId": "luy-lau"}},
        {"id": "explore", "title": "Khám phá bản đồ", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Camera trở về tổng quan — chạm vào từng địa điểm để đọc ý nghĩa lịch sử.",
         "hint": "Camera zoom out, mở khám phá tương tác.",
         "allowedInteractions": ["TAP_TO_EXPLORE"],
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}}},
        {"id": "meaning", "title": "Ý nghĩa", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ. Fade out khép lại hành trình.",
         "hint": "Fade out kết thúc cinematic.",
         "targetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"]}}
      ],
      "prediction": {
        "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?",
        "options": [
          {"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."},
          {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ."}
        ],
        "explainedOptionIndex": 1,
        "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ — cuộc khởi nghĩa hướng về Luy Lâu thách thức trực tiếp bộ máy cai trị.",
        "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị.",
        "revealTargetState": {"markerVisibility": {"hat-mon": 1, "me-linh": 1, "luy-lau": 1}, "routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "focusedLocationId": "luy-lau"}
      }
    }'::jsonb;

    /* ============ SCENE 3 — Lý Thái Tổ 1010 (JOURNEY_MAP v2 cinematic) ============
       Camera zoom-out cho reveal cuối; fade-in title; glow khi chọn Đại La. */
    m_lt_cine := '{
      "schemaVersion": 2,
      "rendererCode": "JOURNEY_MAP",
      "rendererVersion": 1,
      "title": "Lý Thái Tổ dời đô năm 1010 — Cinematic",
      "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới — qua cinematic zoom-out reveal.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [
        {"id": "amb-court", "assetId": "d7a60000-0000-4000-8000-000000000001",
         "role": "AUDIO"}
      ],
      "objects": [],
      "initialState": {},
      "interactions": ["TAP_TO_EXPLORE", "PREDICTION"],
      "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.",
      "sourceReferences": [
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Thăng Long thời nhà Lý (1009–1225)\" và \"Hà Nội — địa linh nhân kiệt\" (baotanglichsuquocgia.vn)."}
      ],
      "map": {
        "locations": [
          {"id": "hoa-lu", "name": "Hoa Lư", "x": 0.28, "y": 0.70,
           "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê.",
           "contextLabel": "Kinh đô cũ"},
          {"id": "dai-la", "name": "Đại La — Thăng Long", "x": 0.62, "y": 0.40,
           "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010.",
           "contextLabel": "Kinh đô mới"}
        ],
        "routes": [
          {"id": "relocation", "from": "hoa-lu", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}],
           "explanation": "Dời kinh đô từ Hoa Lư về Đại La."}
        ]
      },
      "camera": {
        "initial": {"x": 0.28, "y": 0.70, "zoom": 1.3, "focusLocationId": "hoa-lu"},
        "steps": [
          {"target": {"x": 0.28, "y": 0.70, "zoom": 1.5}},
          {"target": {"x": 0.45, "y": 0.55, "zoom": 1.2}},
          {"target": {"x": 0.62, "y": 0.40, "zoom": 1.6, "focusLocationId": "dai-la"}},
          {"target": {"x": 0.45, "y": 0.58, "zoom": 1.0}},
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}
        ]
      },
      "tracks": [],
      "effects": [
        {"type": "FADE_IN", "stepId": "old-capital", "durationMs": 900},
        {"type": "GLOW", "stepId": "chosen", "durationMs": 2200,
         "params": {"x": 0.62, "y": 0.40, "intensity": 0.7}},
        {"type": "FADE_OUT", "stepId": "thang-long", "durationMs": 1200}
      ],
      "audio": [
        {"stepId": "old-capital", "assetRef": "amb-court", "cue": "ENTER", "volume": 0.4},
        {"stepId": "chosen", "assetRef": "amb-court", "cue": "ENTER", "volume": 0.6},
        {"stepId": "thang-long", "assetRef": "amb-court", "cue": "EXIT", "fadeMs": 1000}
      ],
      "steps": [
        {"id": "old-capital", "title": "Hoa Lư — kinh đô cũ", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê. Camera bắt đầu zoom sẵn tại đây + fade in mở màn.",
         "hint": "Camera đã zoom sẵn vào Hoa Lư từ đầu.",
         "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}},
        {"id": "considering", "title": "Cân nhắc dời đô", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Sau khi lên ngôi, Lý Thái Tổ cân nhắc vị trí kinh đô mới — camera kéo ra để bao quát cả hai vùng.",
         "hint": "Camera zoom out — chuẩn bị reveal lựa chọn mới.",
         "targetState": {"markerVisibility": {"hoa-lu": 1}}},
        {"id": "chosen", "title": "Đại La được chọn", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Năm 1010, Lý Thái Tổ chọn Đại La làm kinh đô mới — camera zoom sâu nhất + glow đánh dấu.",
         "hint": "Zoom + glow đánh dấu Đại La được chọn.",
         "targetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "focusedLocationId": "dai-la"}},
        {"id": "relocated", "title": "Dời đô năm 1010", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Quyết định dời đô thực hiện — camera kéo ra để bao trọn tuyến dời đô.",
         "hint": "Camera zoom out để nhìn cả hành trình.",
         "targetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "routeProgress": {"relocation": 1}, "focusedLocationId": "dai-la"}},
        {"id": "thang-long", "title": "Thăng Long", "durationMs": 1100, "easing": "easeInOut",
         "narration": "Kinh đô mới được đặt tên Thăng Long — \"rồng bay lên\". Fade out khép lại hành trình điện ảnh.",
         "hint": "Fade out kết thúc cinematic.",
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
        "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long.",
        "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện?",
        "revealTargetState": {"markerVisibility": {"hoa-lu": 1, "dai-la": 1}, "routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "focusedLocationId": "dai-la"}
      }
    }'::jsonb;

    -- Insert as DRAFT first (same CHECK dance as V15).
    INSERT INTO animation_scenes (id, template_id, event_id, title, draft_json, status, created_by, updated_by)
    VALUES
        (sc_bd_cine, tpl_river, NULL, 'Trận Bạch Đằng năm 938 — Cinematic', m_bd_cine, 'DRAFT', sys_user, sys_user),
        (sc_hb_cine, tpl_map,   NULL, 'Khởi nghĩa Hai Bà Trưng năm 40 — Cinematic', m_hb_cine, 'DRAFT', sys_user, sys_user),
        (sc_lt_cine, tpl_map,   NULL, 'Lý Thái Tổ dời đô năm 1010 — Cinematic', m_lt_cine, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO NOTHING;

    s_bd_cine := m_bd_cine::text;
    s_hb_cine := m_hb_cine::text;
    s_lt_cine := m_lt_cine::text;

    INSERT INTO animation_scene_versions
        (id, scene_id, version_no, schema_version, renderer_code, renderer_version,
         snapshot_json, manifest_checksum, published_by)
    VALUES
        (v_bd_cine, sc_bd_cine, 1, 2, 'RIVER_TIDE', 1, s_bd_cine::jsonb,
         encode(digest(s_bd_cine, 'sha256'), 'hex'), sys_user),
        (v_hb_cine, sc_hb_cine, 1, 2, 'JOURNEY_MAP', 1, s_hb_cine::jsonb,
         encode(digest(s_hb_cine, 'sha256'), 'hex'), sys_user),
        (v_lt_cine, sc_lt_cine, 1, 2, 'JOURNEY_MAP', 1, s_lt_cine::jsonb,
         encode(digest(s_lt_cine, 'sha256'), 'hex'), sys_user)
    ON CONFLICT (id) DO NOTHING;

    UPDATE animation_scenes SET current_version_id = v_bd_cine WHERE id = sc_bd_cine AND current_version_id IS NULL;
    UPDATE animation_scenes SET current_version_id = v_hb_cine WHERE id = sc_hb_cine AND current_version_id IS NULL;
    UPDATE animation_scenes SET current_version_id = v_lt_cine WHERE id = sc_lt_cine AND current_version_id IS NULL;

    UPDATE animation_scenes SET status = 'PUBLISHED'
    WHERE id IN (sc_bd_cine, sc_hb_cine, sc_lt_cine)
      AND status <> 'PUBLISHED';
END $$;
