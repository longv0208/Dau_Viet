-- Dấu Việt | V23 | GAME-04 FIX 1 — audit policy v1 (V22 đã áp dụng).
--
-- V22 seed chọn required lesson bằng `ORDER BY created_at LIMIT 1` — tùy
-- theo thứ tự tạo, không phải required set đã biên soạn. Rủi ro khi event
-- có nhiều lesson: chỉ 1 bài được yêu cầu, các bài quan trọng khác bị bỏ sót.
--
-- Audit chiến lược (idempotent, an toàn tái chạy):
--   1. Archive mọi policy v1 PUBLISHED có required_lesson_ids không cover
--      đủ toàn bộ lesson PUBLISHED của event (số phần tử < tổng PUBLISHED).
--   2. Publish policy v2 = required ALL lesson PUBLISHED của event, sorted
--      theo lesson_id (không phụ thuộc created_at, deterministic).
--      Mastery threshold giữ 70 như policy v1 mặc định.
--   3. Policy v1 còn đúng (n event có đúng n lesson PUBLISHED) → giữ nguyên,
--      không bump version (tránh noise + giữ provenance cũ).
--   4. Event không có lesson PUBLISHED nào → KHÔNG seed policy (service trả
--      NOT_CONFIGURED — không cấp milestone sai).
--   5. ON CONFLICT (event_id, policy_version) DO NOTHING để tái chạy an toàn.
--
-- Không xóa milestone/unlock đã cấp — entitlement luôn giữ (EVT-05).

DO $$
DECLARE
    evt RECORD;
    required_json JSONB;
    current_policy_count INT;
    published_lesson_count INT;
BEGIN
    FOR evt IN
        SELECT e.id AS event_id,
               COALESCE(
                   (SELECT jsonb_agg(l.id ORDER BY l.id)
                      FROM lessons l
                     WHERE l.event_id = e.id AND l.status = 'PUBLISHED'),
                   '[]'::jsonb
               ) AS required_ids
        FROM historical_events e
        WHERE e.status = 'PUBLISHED'
    LOOP
        required_json := evt.required_ids;
        published_lesson_count := jsonb_array_length(required_json);

        -- Không lesson PUBLISHED → bỏ qua (NOT_CONFIGURED).
        IF published_lesson_count = 0 THEN
            CONTINUE;
        END IF;

        -- Đếm policy PUBLISHED hiện tại của event.
        SELECT count(*) INTO current_policy_count
          FROM event_completion_policies
         WHERE event_id = evt.event_id AND status = 'PUBLISHED';

        IF current_policy_count > 0 THEN
            -- Có policy v1: archive nếu required set ít hơn tổng lesson
            -- PUBLISHED (tức là chọn tùy ý theo created_at).
            UPDATE event_completion_policies p
               SET status = 'ARCHIVED'
             WHERE p.event_id = evt.event_id
               AND p.status = 'PUBLISHED'
               AND jsonb_array_length(p.required_lesson_ids)
                   < published_lesson_count;

            -- Nếu đã archive (current_policy_count thay đổi), publish v2.
            IF FOUND THEN
                INSERT INTO event_completion_policies
                    (id, event_id, policy_version, status,
                     required_lesson_ids, optional_lesson_ids,
                     mastery_threshold, published_at)
                VALUES (gen_random_uuid(), evt.event_id, 2, 'PUBLISHED',
                        required_json, '[]'::jsonb, 70, now())
                ON CONFLICT (event_id, policy_version) DO NOTHING;
            END IF;
        ELSE
            -- Chưa có policy nào: publish v1 đúng required set.
            INSERT INTO event_completion_policies
                (id, event_id, policy_version, status,
                 required_lesson_ids, optional_lesson_ids,
                 mastery_threshold, published_at)
            VALUES (gen_random_uuid(), evt.event_id, 1, 'PUBLISHED',
                    required_json, '[]'::jsonb, 70, now())
            ON CONFLICT (event_id, policy_version) DO NOTHING;
        END IF;
    END LOOP;
END $$;
