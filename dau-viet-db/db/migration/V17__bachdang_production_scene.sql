-- Dấu Việt | V17 | Bạch Đằng 938 — production cinematic scene.
-- Real assets (hero JPG, map-base JPG, narration WAV) + a PUBLISHED
-- RIVER_TIDE v2 scene. The event FK is resolved by slug at runtime —
-- event rows are environment data (EventSeedRunner is a dev-only
-- ApplicationRunner that runs AFTER Flyway, and prod events are created
-- via admin APIs with their own UUIDs), so a migration must never
-- hard-code an event UUID. When no `bach-dang-938` row exists yet the
-- scene inserts with event_id NULL (schema allows, same as V15/V16) —
-- the admin scene editor links it to the event later via
-- SceneUpdateRequest.eventId (validated against historical_events).
-- Idempotent: every INSERT is ON CONFLICT DO NOTHING; scene row inserted
-- DRAFT then flipped to PUBLISHED only when still DRAFT (V15/V16 dance —
-- chk_animation_scene_published_version requires a version first).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    sys_user UUID := '00000000-0000-4000-8000-000000000001';
    tpl_river UUID := 'd7a10000-0000-4000-8000-000000000001';
    evt_bachdang UUID;

    ast_hero  UUID := 'd7a70000-0000-4000-8000-000000000001';
    ast_map   UUID := 'd7a70000-0000-4000-8000-000000000002';
    ast_voice UUID := 'd7a70000-0000-4000-8000-000000000003';

    sc_bd_prod UUID := 'd7a80000-0000-4000-8000-000000000001';
    v_bd_prod  UUID := 'd7a90000-0000-4000-8000-000000000001';

    m_bd_prod JSONB;
    s_bd_prod TEXT;
BEGIN
    INSERT INTO users (id, email, password_hash, display_name, role, status)
    VALUES (sys_user, 'system@dauviet.local', '!locked!', 'Dấu Việt System',
            'CONTENT_ADMIN', 'DISABLED')
    ON CONFLICT (id) DO NOTHING;

    /* ---- Assets — production artwork/audio (TASK-0019 brief). ----
       Bytes live at {dauviet.assets.dir}/<uuid>.<ext>; rows register the
       contract metadata (mime/size/alt_text/checksum is advisory — the
       service re-checksums on real uploads, seeds record what we ship). */
    INSERT INTO assets (id, storage_key, original_filename, mime_type,
                        size_bytes, state, alt_text, created_by)
    VALUES
        (ast_hero, 'assets/d7a70000-0000-4000-8000-000000000001.jpg',
         'dv_EVT_ngoquyen_bachdang_hero_v01.jpg', 'image/jpeg', 1164505,
         'ACTIVE',
         'Ngô Quyền chỉ huy thủy quân trên sông Bạch Đằng, bãi cọc nhô phía trước',
         sys_user),
        (ast_map, 'assets/d7a70000-0000-4000-8000-000000000002.jpg',
         'dv_MAP_ngoquyen_bachdang-base_v01.jpg', 'image/jpeg', 1079580,
         'ACTIVE',
         'Cửa sông Bạch Đằng minh họa: sông uốn qua đồng bằng, núi đá vôi, làng chài ven bờ',
         sys_user),
        (ast_voice, 'assets/d7a70000-0000-4000-8000-000000000003.wav',
         'narration_bach_dang.wav', 'audio/wav', 749744,
         'ACTIVE',
         'Thuyết minh 8.5 giây tóm tắt trận Bạch Đằng 938',
         sys_user)
    ON CONFLICT (id) DO NOTHING;

    -- Resolve the event FK by slug at runtime — never a hard-coded UUID.
    -- NULL when the event row does not exist in this environment yet.
    SELECT id INTO evt_bachdang FROM historical_events WHERE slug = 'bach-dang-938';

    /* ============ Bạch Đằng 938 — PRODUCTION (RIVER_TIDE v2) ============
       8 beats: estuary → stake-prep → tide-rise → decoy → prediction →
       tide-fall → counterattack → evidence. Hero JPG is the painted
       background (asset ref + camera zoom on the stakes zone); the map
       artwork rides as a fade-in OBJECT plate on the first beat so the
       estuary beat shows terrain before the tactical overlay. Narration:
       one 8.5s overview clip plays once on the opening beat — repeating
       it as ENTER on every beat made each step restart the shared
       player and loop the intro (P1 audio storyboard fix). Per-beat VO
       needs separate licensed clips; text narration carries the beats
       until they exist. */
    m_bd_prod := '{
      "schemaVersion": 2,
      "rendererCode": "RIVER_TIDE",
      "rendererVersion": 1,
      "title": "Trận Bạch Đằng năm 938 — Trải nghiệm điện ảnh",
      "learningObjective": "Diễn giải chuỗi quyết định — chuẩn bị bãi cọc, bám nhịp triều, dụ địch, khống chế, phản công — qua cảnh điện ảnh 2.5D có chứng cứ.",
      "canvas": {"aspectRatio": 1.6},
      "assets": [
        {"id": "bg-hero",  "assetId": "d7a70000-0000-4000-8000-000000000001", "role": "BACKGROUND"},
        {"id": "map-base", "assetId": "d7a70000-0000-4000-8000-000000000002", "role": "OBJECT"},
        {"id": "voice",    "assetId": "d7a70000-0000-4000-8000-000000000003", "role": "AUDIO"}
      ],
      "objects": [
        {"id": "map-plate", "type": "LOCATION",
         "position": {"x": 0.5, "y": 0.5}, "scale": 1.0, "layer": -1,
         "visible": true, "rotation": 0, "opacity": 0.85,
         "assetRef": "map-base", "shape": "rect"},
        {"id": "boat-decoy", "type": "BOAT",
         "position": {"x": 0.14, "y": 0.46}, "scale": 0.13, "layer": 2,
         "visible": true, "rotation": 0, "opacity": 1},
        {"id": "boat-fleet", "type": "BOAT",
         "position": {"x": 0.88, "y": 0.30}, "scale": 0.11, "layer": 2,
         "visible": true, "rotation": 0, "opacity": 1}
      ],
      "initialState": {},
      "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"],
      "disclaimer": "Cảnh minh họa 2.5D dựa trên tư liệu — không theo tỉ lệ, không phải phục dựng chính xác. Một số chi tiết trang phục/thuyền là suy luận minh họa.",
      "sourceReferences": [
        {"title": "Đại Việt Sử Ký Toàn Thư — Tiền Ngô Vương Kỷ."},
        {"title": "Việt Sử Tiêu Án — ghi chép chiến thắng Bạch Đằng 938."},
        {"title": "Bảo tàng Lịch sử Quốc gia — \"Ngô Quyền và chiến thắng Bạch Đằng năm 938\"."}
      ],
      "river": {"stakes": [
        {"id": "stake-1", "x": 0.40, "length": 0.22},
        {"id": "stake-2", "x": 0.45, "length": 0.19},
        {"id": "stake-3", "x": 0.50, "length": 0.24},
        {"id": "stake-4", "x": 0.55, "length": 0.17},
        {"id": "stake-5", "x": 0.60, "length": 0.21},
        {"id": "stake-6", "x": 0.43, "length": 0.16},
        {"id": "stake-7", "x": 0.57, "length": 0.23},
        {"id": "stake-8", "x": 0.52, "length": 0.18}
      ]},
      "environment": {"mist": 0.3, "glow": 0.15},
      "camera": {
        "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0},
        "steps": [
          {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}},
          {"target": {"x": 0.52, "y": 0.62, "zoom": 1.35}},
          {"target": {"x": 0.5,  "y": 0.55, "zoom": 1.1}},
          {"target": {"x": 0.45, "y": 0.42, "zoom": 1.25, "focusObjectId": "boat-decoy"}},
          {"target": {"x": 0.5,  "y": 0.5,  "zoom": 1.0}},
          {"target": {"x": 0.52, "y": 0.6,  "zoom": 1.55}},
          {"target": {"x": 0.5,  "y": 0.5,  "zoom": 1.8}},
          {"target": {"x": 0.5,  "y": 0.5,  "zoom": 1.0}}
        ]
      },
      "tracks": [
        {"objectId": "map-plate", "property": "opacity",
         "keyframes": [
           {"tMs": 0,    "value": 0.85, "easing": "linear"},
           {"tMs": 2200, "value": 0.0,  "easing": "linear"},
           {"tMs": 8800, "value": 0.0,  "easing": "linear"}
         ]},
        {"objectId": "boat-decoy", "property": "position",
         "keyframes": [
           {"tMs": 0,    "value": {"x": 0.14, "y": 0.46}, "easing": "linear"},
           {"tMs": 3300, "value": {"x": 0.30, "y": 0.42}, "easing": "linear"},
           {"tMs": 4400, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"},
           {"tMs": 6600, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"}
         ]},
        {"objectId": "boat-decoy", "property": "rotation",
         "keyframes": [
           {"tMs": 0,    "value": 0,   "easing": "easeInOut"},
           {"tMs": 4400, "value": 0,   "easing": "easeInOut"},
           {"tMs": 6600, "value": -22, "easing": "easeInOut"}
         ]},
        {"objectId": "boat-fleet", "property": "position",
         "keyframes": [
           {"tMs": 0,    "value": {"x": 0.88, "y": 0.30}, "easing": "linear"},
           {"tMs": 3300, "value": {"x": 0.72, "y": 0.34}, "easing": "linear"},
           {"tMs": 4400, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"},
           {"tMs": 6600, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"}
         ]}
      ],
      "effects": [
        {"type": "MIST", "params": {"intensity": 0.3}},
        {"type": "FADE_IN", "stepId": "estuary", "durationMs": 900},
        {"type": "WATER_RIPPLE", "stepId": "tide-fall", "durationMs": 2000,
         "params": {"x": 0.52, "y": 0.60, "intensity": 0.75}},
        {"type": "GLOW", "stepId": "counterattack", "durationMs": 2000,
         "params": {"x": 0.52, "y": 0.42, "intensity": 0.55, "objectId": "boat-decoy"}},
        {"type": "FADE_OUT", "stepId": "evidence", "durationMs": 900}
      ],
      "audio": [
        {"stepId": "estuary", "assetRef": "voice", "cue": "ENTER", "volume": 0.9}
      ],
      "steps": [
        {"id": "estuary", "title": "Cửa sông Bạch Đằng", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Cửa sông Bạch Đằng nối ra biển Đông — địa thế triều mạnh, luồng nông, nhiều bãi bồi. Đây là nơi Ngô Quyền chọn làm trận địa đón quân Nam Hán.",
         "hint": "Bản đồ minh họa vùng cửa sông hiện ra rồi mờ dần — camera giữ góc nhìn tổng quan.",
         "targetState": {"waterLevel": 0.55, "boatProgress": 0.0, "obstructed": false}},
        {"id": "stake-prep", "title": "Đóng cọc ngầm", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Trước trận, quân ta đóng sẵn bãi cọc gỗ lim bịt sắt dưới lòng sông. Sử liệu không ghi bố trí chính xác — sơ đồ chỉ minh họa ý tưởng trận địa.",
         "hint": "Camera hạ xuống mặt nước, các cọc lần lượt lộ ở vùng bãi.",
         "targetState": {"waterLevel": 0.30, "boatProgress": 0.0, "obstructed": false, "highlightStakes": true}},
        {"id": "tide-rise", "title": "Triều lên", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Nước triều dâng cao, che khuất đỉnh cọc. Từ trên thuyền nhìn xuống khó nhận ra chướng ngại vật ẩn phía dưới.",
         "hint": "Kéo mực nước lên để tự thấy cọc chìm hẳn.",
         "allowedInteractions": ["WATER_LEVEL_CONTROL"],
         "targetState": {"waterLevel": 0.90, "boatProgress": 0.0, "obstructed": false}},
        {"id": "decoy", "title": "Dụ địch vào bãi", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Lúc nước lớn, thuyền dụ dẫn hạm đội Nam Hán tiến vào vùng bãi cọc. Đoàn địch theo sau, không biết đáy sông đã bố trận.",
         "hint": "Camera bám theo thuyền dụ — thuyền địch tiến từ mép phải vào trung tâm bãi.",
         "targetState": {"waterLevel": 0.90, "boatProgress": 0.72, "obstructed": false, "decoyProgress": 1}},
        {"id": "prediction", "title": "Điểm quyết định", "durationMs": 1400, "easing": "easeInOut",
         "narration": "Triều sắp rút. Nếu thuyền địch đã vào sâu bãi cọc, điều gì sẽ xảy ra khi mực nước hạ? Đây là lúc cả trận địa chuyển pha.",
         "hint": "Dừng lại và dự đoán trước khi xem nước rút.",
         "allowedInteractions": ["PREDICTION"],
         "targetState": {"waterLevel": 0.85, "boatProgress": 0.72, "obstructed": false, "decoyProgress": 1}},
        {"id": "tide-fall", "title": "Triều rút — cọc lộ", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Triều rút nhanh, đỉnh cọc nhô lên khỏi mặt sông. Thuyền địch mắc vào bãi, không thể quay đầu hay tiếp tục tiến.",
         "hint": "Camera zoom vào bãi + gợn nước đánh dấu điểm mấu chốt.",
         "allowedInteractions": ["WATER_LEVEL_CONTROL"],
         "targetState": {"waterLevel": 0.26, "boatProgress": 0.85, "obstructed": false, "decoyProgress": 1, "highlightStakes": true}},
        {"id": "counterattack", "title": "Phản công phối hợp", "durationMs": 1200, "easing": "easeInOut",
         "narration": "Khi thuyền địch vướng cọc, quân ta phản công đồng loạt từ nhiều hướng. Thời điểm triều hạ chính là thời điểm quyết định trận đánh.",
         "hint": "Glow quanh thuyền dụ đánh dấu điểm dồn lực — thuyền địch mắc kẹt.",
         "targetState": {"waterLevel": 0.26, "boatProgress": 0.85, "obstructed": true, "decoyProgress": 1, "counterattackProgress": 1}},
        {"id": "evidence", "title": "Kết luận có chứng cứ", "durationMs": 1400, "easing": "easeInOut",
         "narration": "Chiến thắng Bạch Đằng là kết quả của chuỗi chủ động: chọn địa thế triều → chuẩn bị trận địa → dụ địch đúng lúc nước lớn → phản công đúng lúc nước rút. Đây là kết luận dựa trên bối cảnh, không phải chi tiết từng cọc hay từng thuyền được ghi lại.",
         "hint": "Fade out — chuỗi quyết định khép lại bằng chứng cứ.",
         "targetState": {"waterLevel": 0.26, "boatProgress": 0.85, "obstructed": true, "decoyProgress": 1, "counterattackProgress": 1, "showSequenceSummary": true}}
      ],
      "prediction": {
        "question": "Khi triều rút sau khi thuyền địch đã vào bãi cọc, kết quả nào hợp lý nhất?",
        "options": [
          {"text": "Cọc vẫn chìm sâu, thuyền địch rút lui an toàn."},
          {"text": "Cọc lộ ra, thuyền địch mắc kẹt và bị phản công."}
        ],
        "explainedOptionIndex": 1,
        "explanation": "Mực nước hạ làm đỉnh cọc nhô lên — thuyền đã tiến vào lúc nước lớn sẽ vướng phải chướng ngại vật và mất khả năng cơ động.",
        "retryHint": "Kéo mực nước xuống thấp ở bước trước và quan sát phần cọc lộ ra.",
        "revealTargetState": {"waterLevel": 0.22, "boatProgress": 0.85, "obstructed": true, "highlightStakes": true}
      }
    }'::jsonb;

    INSERT INTO animation_scenes (id, template_id, event_id, title, draft_json, status, created_by, updated_by)
    VALUES
        (sc_bd_prod, tpl_river, evt_bachdang,
         'Trận Bạch Đằng năm 938 — Production', m_bd_prod, 'DRAFT', sys_user, sys_user)
    ON CONFLICT (id) DO NOTHING;

    s_bd_prod := m_bd_prod::text;

    INSERT INTO animation_scene_versions
        (id, scene_id, version_no, schema_version, renderer_code, renderer_version,
         snapshot_json, manifest_checksum, published_by)
    VALUES
        (v_bd_prod, sc_bd_prod, 1, 2, 'RIVER_TIDE', 1, s_bd_prod::jsonb,
         encode(digest(s_bd_prod, 'sha256'), 'hex'), sys_user)
    ON CONFLICT (id) DO NOTHING;

    -- Record which assets this published version references (V14 contract).
    INSERT INTO animation_scene_asset_refs (scene_version_id, asset_id, role)
    VALUES
        (v_bd_prod, ast_hero,  'BACKGROUND'),
        (v_bd_prod, ast_map,   'OBJECT'),
        (v_bd_prod, ast_voice, 'AUDIO')
    ON CONFLICT DO NOTHING;

    UPDATE animation_scenes SET current_version_id = v_bd_prod
    WHERE id = sc_bd_prod AND current_version_id IS NULL;

    UPDATE animation_scenes SET status = 'PUBLISHED'
    WHERE id = sc_bd_prod AND status <> 'PUBLISHED';

    -- Late link guard: links NOW if the event row already existed at
    -- migrate-time (prod DB seeded via admin API before deploy). This
    -- UPDATE runs exactly once with this migration — it does NOT re-run
    -- when the event arrives later. Local/dev: EventSeedRunner post-links
    -- via AnimationSceneEventLinker after upserting the event (real id,
    -- untouched-seed guard below — same condition). Prod: admin links via
    -- the scene editor (SceneUpdateRequest.eventId). Only fills NULL on
    -- the untouched seed row (updated_by = sys_user): an admin-cleared or
    -- admin-linked row is never rebound.
    UPDATE animation_scenes s
    SET event_id = e.id,
        updated_by = sys_user
    FROM historical_events e
    WHERE s.id = sc_bd_prod
      AND s.event_id IS NULL
      AND s.updated_by = sys_user
      AND e.slug = 'bach-dang-938';
END $$;
