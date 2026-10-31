-- ============================================================================
-- DẤU VIỆT — SCRIPT A: DATABASE PREFLIGHT (READ-ONLY)
-- Issue #54 — Database cleanup & 4 demo lessons audit.
-- Chạy: psql -f script_a_preflight.sql   (read-only, không ghi dữ liệu)
-- ============================================================================
\set ON_ERROR_STOP on
\timing off

SELECT '=== A0. FLYWAY HISTORY (latest 15) ===' AS section;
SELECT version, description, success, installed_on
FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 15;

SELECT '=== A1. EVENT COUNT BY STATUS ===' AS section;
SELECT status, count(*) FROM historical_events GROUP BY status ORDER BY status;

SELECT '=== A2. DUPLICATE SLUG / TITLE / START_YEAR ===' AS section;
SELECT slug, count(*) AS dup_slug FROM historical_events GROUP BY slug HAVING count(*)>1;
SELECT title, count(*) AS dup_title FROM historical_events GROUP BY title HAVING count(*)>1;
SELECT start_year, count(*) AS same_year FROM historical_events
  GROUP BY start_year HAVING count(*)>1 ORDER BY start_year;

SELECT '=== A3. ALL EVENTS (canonical + demo candidates) ===' AS section;
SELECT id, slug, title, era, start_year, status FROM historical_events
ORDER BY start_year NULLS LAST, slug;

SELECT '=== A4. 4 DEMO EVENTS — canonical check ===' AS section;
SELECT id, slug, title, status FROM historical_events
WHERE slug IN ('bach-dang-938','khoi-nghia-hai-ba-trung-40','hai-ba-trung-40',
               'history-ba-trieu','history-ly-bi','ba-trieu','ly-bi',
               'khoi-nghia-ba-trieu','van-xuan','ly-bi-van-xuan')
ORDER BY slug;

SELECT '=== A5. LESSONS PER EVENT ===' AS section;
SELECT e.slug, l.id AS lesson_id, l.title, l.status AS lesson_status,
       lt.code AS template, l.current_version_id,
       EXISTS(SELECT 1 FROM learner_attempts la
              JOIN lesson_versions lv ON lv.id=la.lesson_version_id
              WHERE lv.lesson_id=l.id) AS has_attempts
FROM lessons l JOIN historical_events e ON e.id=l.event_id
LEFT JOIN lesson_templates lt ON lt.id=l.template_id
ORDER BY e.slug, l.created_at;

SELECT '=== A6. LESSONS WITH NO VALID EVENT ===' AS section;
SELECT l.id, l.title, l.status FROM lessons l
WHERE l.event_id IS NULL
   OR NOT EXISTS(SELECT 1 FROM historical_events e WHERE e.id=l.event_id);

SELECT '=== A7. DRAFT DEMO LESSONS NOT REFERENCED (cleanup candidates) ===' AS section;
SELECT l.id, e.slug, l.title, l.status,
       EXISTS(SELECT 1 FROM learner_attempts la
              JOIN lesson_versions lv ON lv.id=la.lesson_version_id
              WHERE lv.lesson_id=l.id) AS has_attempts
FROM lessons l JOIN historical_events e ON e.id=l.event_id
WHERE l.status='DRAFT' ORDER BY l.created_at;

SELECT '=== A8. EVIDENCES — count + type per event ===' AS section;
SELECT e.slug, count(*) AS ev_count,
       count(*) FILTER (WHERE ev.status='APPROVED') AS approved,
       string_agg(DISTINCT ev.evidence_type, ', ') AS types
FROM evidences ev JOIN historical_events e ON e.id=ev.event_id
GROUP BY e.slug ORDER BY ev_count DESC;

SELECT '=== A9. DUPLICATE EVIDENCE (same event+title) ===' AS section;
SELECT event_id, title, count(*) AS dup
FROM evidences GROUP BY event_id, title HAVING count(*)>1;

SELECT '=== A10. EVIDENCES NOT REFERENCED BY ANY SNAPSHOT ===' AS section;
SELECT ev.id, e.slug, ev.title, ev.status
FROM evidences ev JOIN historical_events e ON e.id=ev.event_id
WHERE NOT EXISTS (
  SELECT 1 FROM lesson_versions lv
  WHERE lv.snapshot_json::text LIKE '%'||ev.id::text||'%'
)
ORDER BY e.slug, ev.created_at;

SELECT '=== A11. ASSETS — usage + unreferenced ===' AS section;
SELECT a.id, a.storage_key, a.state,
       (SELECT count(*) FROM evidences ev WHERE ev.asset_id=a.id) AS evidence_refs,
       EXISTS(SELECT 1 FROM animation_scene_asset_refs r WHERE r.asset_id=a.id) AS anim_ref
FROM assets a ORDER BY a.created_at;

SELECT '=== A12. ANIMATION SCENES ===' AS section;
SELECT s.id, s.title, s.status, s.current_version_id,
       e.slug AS event_slug,
       v.renderer_code
FROM animation_scenes s
LEFT JOIN historical_events e ON e.id=s.event_id
LEFT JOIN animation_scene_versions v ON v.id=s.current_version_id
ORDER BY s.created_at;

SELECT '=== A13. PUBLISHED LEARNING PATH ===' AS section;
SELECT v.path_code, v.version_no, v.title, v.status, v.published_at
FROM learning_path_versions v ORDER BY path_code, version_no;

SELECT '=== A14. PUBLISHED PATH — chapters & event nodes ===' AS section;
SELECT c.code AS chapter, c.sort_order AS c_sort,
       n.sort_order AS n_sort, e.slug, e.title
FROM learning_path_event_nodes n
JOIN learning_path_chapters c ON c.id=n.chapter_id
JOIN learning_path_versions v ON v.id=n.path_version_id
JOIN historical_events e ON e.id=n.event_id
WHERE v.status='PUBLISHED'
ORDER BY c.sort_order, n.sort_order;

SELECT '=== A15. PATH LESSON NODES (published path) ===' AS section;
SELECT e.slug, l.id AS lesson_id, l.title, l.status
FROM learning_path_lesson_nodes ln
JOIN learning_path_event_nodes en ON en.id=ln.event_node_id
JOIN learning_path_versions v ON v.id=en.path_version_id
JOIN lessons l ON l.id=ln.lesson_id
JOIN historical_events e ON e.id=ln.event_id
WHERE v.status='PUBLISHED' ORDER BY e.slug, ln.sort_order;

SELECT '=== A16. EVENT COMPLETION POLICIES ===' AS section;
SELECT e.slug, p.id, p.policy_version, p.status, p.required_lesson_ids, p.optional_lesson_ids
FROM event_completion_policies p JOIN historical_events e ON e.id=p.event_id
ORDER BY e.slug, p.policy_version;

SELECT '=== A17. LESSON VERSIONS REFERENCED BY ATTEMPTS ===' AS section;
SELECT lv.id, l.title, lv.version_no, count(la.*) AS attempts
FROM learner_attempts la
JOIN lesson_versions lv ON lv.id=la.lesson_version_id
JOIN lessons l ON l.id=lv.lesson_id
GROUP BY lv.id, l.title, lv.version_no ORDER BY attempts DESC;

SELECT '=== A18. USER-PROGRESS TABLES (row counts — must NOT be touched) ===' AS section;
SELECT 'learner_attempts' AS tbl, count(*) FROM learner_attempts
UNION ALL SELECT 'user_event_progress', count(*) FROM user_event_progress
UNION ALL SELECT 'user_dossier_unlocks', count(*) FROM user_dossier_unlocks
UNION ALL SELECT 'lesson_versions', count(*) FROM lesson_versions;

SELECT '=== PREFLIGHT DONE ===' AS section;
