-- ============================================================================
-- DẤU VIỆT — SCRIPT C: OPTIONAL DEMO CLEANUP (PREVIEW_ONLY mặc định)
-- Issue #54 — dọn dữ liệu demo trùng lặp / nháp thử nghiệm.
--
-- MẶC ĐỊNH: PREVIEW_ONLY (chỉ liệt kê ứng viên, KHÔNG ghi).
-- Để APPLY: chạy với  -v apply_cleanup=1  SAU KHI đã sao lưu DB và xác nhận
-- môi trường demo/dev. APPLY chỉ ARCHIVE — không hard-delete bản ghi có
-- lịch sử học tập. Không bao giờ đụng: users, lesson_versions,
-- learner_attempts, user_*, rewards, dossier unlock, published snapshots.
--
-- Ví dụ: psql -f script_c_cleanup_preview.sql            → preview
--        psql -v apply_cleanup=1 -f script_c_cleanup_preview.sql  → archive
-- ============================================================================
\set ON_ERROR_STOP on

\if :{?apply_cleanup}
  \echo '>>> APPLY MODE — ARCHIVING demo duplicate/draft rows (backup required)'
\else
  \echo '>>> PREVIEW_ONLY — liệt kê ứng viên cleanup, không ghi'
\endif

-- Bốn lesson demo FOUR_STEP canonical — KHÔNG BAO GIỜ là ứng viên cleanup.
CREATE TEMP TABLE _keep_lessons(id uuid);
INSERT INTO _keep_lessons VALUES
 ('64000000-0000-4000-8000-000000000001'),
 ('64000000-0000-4000-8000-000000000002'),
 ('64000000-0000-4000-8000-000000000003'),
 ('d7b20000-0000-4000-8000-000000000001');
-- tiến trình học viên tham chiếu (không có lesson có attempt, không có
-- learning-path node trong path PUBLISHED, không có evidence APPROVED).
-- ---------------------------------------------------------------------------
SELECT 'C1. EVENT cleanup candidates' AS section;
WITH cand AS (
  SELECT e.id, e.slug, e.title, e.status,
         (SELECT count(*) FROM lessons l WHERE l.event_id=e.id) AS lessons,
         (SELECT count(*) FROM evidences ev WHERE ev.event_id=e.id) AS evidences,
         (SELECT count(*) FROM learning_path_event_nodes n
            JOIN learning_path_versions v ON v.id=n.path_version_id
            WHERE n.event_id=e.id AND v.status='PUBLISHED') AS pub_path_nodes,
         (SELECT count(*) FROM lessons l
            JOIN lesson_versions lv ON lv.lesson_id=l.id
            JOIN learner_attempts la ON la.lesson_version_id=lv.id
            WHERE l.event_id=e.id) AS attempts
  FROM historical_events e
  WHERE e.slug NOT IN ('bach-dang-938','khoi-nghia-hai-ba-trung-40',
                       'history-ba-trieu','history-ly-bi')
)
SELECT * FROM cand
WHERE (attempts = 0)
  AND (pub_path_nodes = 0 OR slug LIKE 'demo%' OR slug LIKE '%test%')
ORDER BY slug;

-- ---------------------------------------------------------------------------
-- Ứng viên 2: LESSON draft/test không có attempt, thuộc event demo/test,
-- không được path published tham chiếu.
-- ---------------------------------------------------------------------------
SELECT 'C2. LESSON cleanup candidates (draft/test, no attempts)' AS section;
SELECT l.id, e.slug, l.title, l.status,
       EXISTS(SELECT 1 FROM learner_attempts la
              JOIN lesson_versions lv ON lv.id=la.lesson_version_id
              WHERE lv.lesson_id=l.id) AS has_attempts
FROM lessons l JOIN historical_events e ON e.id=l.event_id
WHERE (l.status='DRAFT' OR e.slug LIKE 'demo%' OR e.slug LIKE '%test%')
  AND l.id NOT IN (SELECT id FROM _keep_lessons)
  AND NOT EXISTS(SELECT 1 FROM learner_attempts la
                 JOIN lesson_versions lv ON lv.id=la.lesson_version_id
                 WHERE lv.lesson_id=l.id)
ORDER BY e.slug, l.created_at;

-- ---------------------------------------------------------------------------
-- Ứng viên 3: EVIDENCE trùng title trong cùng event (giữ 1, archive phần dư).
-- ---------------------------------------------------------------------------
SELECT 'C3. DUPLICATE EVIDENCE per event' AS section;
SELECT event_id, title, count(*) AS dup, string_agg(id::text, ', ') AS ids
FROM evidences GROUP BY event_id, title HAVING count(*)>1;

-- ---------------------------------------------------------------------------
-- Ứng viên 4: ASSET không được tham chiếu (không xoá — chỉ liệt kê RETIRED).
-- ---------------------------------------------------------------------------
SELECT 'C4. UNREFERENCED ASSETS' AS section;
SELECT a.id, a.storage_key, a.state
FROM assets a
WHERE a.state='ACTIVE'
  AND NOT EXISTS(SELECT 1 FROM evidences ev WHERE ev.asset_id=a.id)
  AND NOT EXISTS(SELECT 1 FROM animation_scene_asset_refs r WHERE r.asset_id=a.id)
  AND NOT EXISTS(SELECT 1 FROM historical_dossiers d WHERE d.asset_id=a.id)
ORDER BY a.created_at;

-- ---------------------------------------------------------------------------
-- APPLY (chỉ khi -v apply_cleanup=1): ARCHIVE — không hard-delete.
-- ---------------------------------------------------------------------------
\if :{?apply_cleanup}
BEGIN;

-- Archive events demo/test không có attempt & không trong published path.
UPDATE historical_events e SET status='ARCHIVED', updated_at=now()
WHERE (e.slug LIKE 'demo%' OR e.slug LIKE '%test%')
  AND NOT EXISTS(SELECT 1 FROM lessons l
                 JOIN lesson_versions lv ON lv.lesson_id=l.id
                 JOIN learner_attempts la ON la.lesson_version_id=lv.id
                 WHERE l.event_id=e.id)
  AND NOT EXISTS(SELECT 1 FROM learning_path_event_nodes n
                 JOIN learning_path_versions v ON v.id=n.path_version_id
                 WHERE n.event_id=e.id AND v.status='PUBLISHED');

-- Archive DRAFT/test lessons không có attempt.
UPDATE lessons l SET status='ARCHIVED', updated_at=now()
WHERE (l.status='DRAFT' OR EXISTS(SELECT 1 FROM historical_events e
        WHERE e.id=l.event_id AND (e.slug LIKE 'demo%' OR e.slug LIKE '%test%')))
  AND l.id NOT IN (SELECT id FROM _keep_lessons)
  AND NOT EXISTS(SELECT 1 FROM learner_attempts la
                 JOIN lesson_versions lv ON lv.id=la.lesson_version_id
                 WHERE lv.lesson_id=l.id);

COMMIT;
\echo '>>> APPLY DONE — rows archived (preview query lại để xác nhận)'
\endif

SELECT '=== CLEANUP SCRIPT END ===' AS section;
