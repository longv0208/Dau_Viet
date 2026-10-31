-- ============================================================================
-- DẤU VIỆT — SCRIPT D: POSTFLIGHT VALIDATION (READ-ONLY)
-- Issue #54 — kiểm tra hậu điều kiện demo 4 sự kiện + FOUR_STEP.
-- Phân biệt rõ DRAFT_READY vs PUBLISHED_READY — không tuyên bố publish khi
-- mới chỉ có draft.
-- Chạy: psql -f script_d_postflight.sql
-- Mỗi check trả PASS/FAIL + chi tiết. Kết luận cuối tổng hợp.
-- ============================================================================
\set ON_ERROR_STOP off
\pset footer off

-- Demo scope: 4 canonical event slugs + 4 demo lesson ids.
CREATE TEMP TABLE _demo_scope(ev_slug text, ev_id uuid, les_id uuid);
INSERT INTO _demo_scope VALUES
 ('khoi-nghia-hai-ba-trung-40', NULL, '64000000-0000-4000-8000-000000000001'),
 ('history-ba-trieu',          NULL, '64000000-0000-4000-8000-000000000002'),
 ('history-ly-bi',             NULL, '64000000-0000-4000-8000-000000000003'),
 ('bach-dang-938',             NULL, 'd7b20000-0000-4000-8000-000000000001');
UPDATE _demo_scope s SET ev_id=e.id FROM historical_events e WHERE e.slug=s.ev_slug;

SELECT '=== D1. 4 canonical events exist & PUBLISHED ===' AS check;
SELECT s.ev_slug, e.id IS NOT NULL AS exists, e.status,
       CASE WHEN e.status='PUBLISHED' THEN 'PASS' ELSE 'FAIL' END AS result
FROM _demo_scope s LEFT JOIN historical_events e ON e.id=s.ev_id
ORDER BY s.ev_slug;

SELECT '=== D2. Each event has ≥1 FOUR_STEP lesson (demo id) ===' AS check;
SELECT s.ev_slug, l.id AS lesson_id, l.status, lt.code,
       CASE WHEN lt.code='FOUR_STEP' THEN 'PASS' ELSE 'FAIL' END AS result
FROM _demo_scope s
LEFT JOIN lessons l ON l.id=s.les_id
LEFT JOIN lesson_templates lt ON lt.id=l.template_id
ORDER BY s.ev_slug;

SELECT '=== D3. 16 evidences (namespace 64000000, 4/event) ===' AS check;
SELECT e.slug, count(*) AS ev_count,
       CASE WHEN count(*)>=4 THEN 'PASS' ELSE 'FAIL' END AS result
FROM evidences ev JOIN historical_events e ON e.id=ev.event_id
WHERE ev.id::text LIKE '64000000%'
GROUP BY e.slug ORDER BY e.slug;

SELECT '=== D4. Draft FOUR_STEP structure (4 stages, 4 clues, order) ===' AS check;
SELECT s.ev_slug,
       (d.draft_json->>'flowModel') AS flow,
       jsonb_array_length(d.draft_json->'stages') AS stage_count,
       (SELECT string_agg(a->>'clueType', ',' ORDER BY a->>'clueType')
        FROM jsonb_array_elements(d.draft_json->'stages'->0->'activities') a) AS clues,
       (SELECT count(*) FROM jsonb_array_elements(d.draft_json->'stages'->1->'activities')) AS hyp_acts,
       (SELECT count(*) FROM jsonb_array_elements(d.draft_json->'stages'->2->'activities')) AS ver_acts,
       (SELECT count(*) FROM jsonb_array_elements(d.draft_json->'stages'->3->'activities')) AS rec_acts,
       CASE
         WHEN d.draft_json->>'flowModel'='FOUR_STEP'
          AND jsonb_array_length(d.draft_json->'stages')=4
          AND (d.draft_json->'stages'->0->>'type')='DISCOVERY'
          AND (d.draft_json->'stages'->1->>'type')='HYPOTHESIS'
          AND (d.draft_json->'stages'->2->>'type')='VERIFICATION'
          AND (d.draft_json->'stages'->3->>'type')='RECONSTRUCTION'
         THEN 'PASS' ELSE 'FAIL' END AS result
FROM _demo_scope s JOIN lessons d ON d.id=s.les_id ORDER BY s.ev_slug;

SELECT '=== D5. VERIFICATION refs resolve to real evidences of same event ===' AS check;
SELECT s.ev_slug,
       v.act->'config'->>'expectedHypothesis' AS expected_hyp,
       (SELECT count(*) FROM jsonb_array_elements_text(v.act->'config'->'visibleSourceIds') x
        JOIN evidences ev ON ev.id=x.value::uuid AND ev.event_id=s.ev_id) AS visible_ok,
       (SELECT count(*) FROM jsonb_array_elements_text(v.act->'config'->'requiredEvidenceIds') x
        JOIN evidences ev ON ev.id=x.value::uuid AND ev.event_id=s.ev_id) AS required_ok,
       CASE WHEN (SELECT count(*) FROM jsonb_array_elements_text(v.act->'config'->'requiredEvidenceIds') x
                  JOIN evidences ev ON ev.id=x.value::uuid AND ev.event_id=s.ev_id)
                 = jsonb_array_length(v.act->'config'->'requiredEvidenceIds')
            THEN 'PASS' ELSE 'FAIL' END AS result
FROM _demo_scope s
JOIN lessons l ON l.id=s.les_id,
LATERAL (SELECT (jsonb_array_elements(l.draft_json->'stages'->2->'activities')) AS act) v
ORDER BY s.ev_slug;

SELECT '=== D6. Learning path DEMO_BAC_THUOC — 4 ordered event nodes ===' AS check;
SELECT v.path_code, v.status,
       (SELECT count(*) FROM learning_path_event_nodes n WHERE n.path_version_id=v.id) AS event_nodes,
       (SELECT string_agg(e.slug, ' → ' ORDER BY n.sort_order)
        FROM learning_path_event_nodes n JOIN historical_events e ON e.id=n.event_id
        WHERE n.path_version_id=v.id) AS event_order,
       CASE WHEN v.status IN ('DRAFT','PUBLISHED')
             AND (SELECT count(*) FROM learning_path_event_nodes n WHERE n.path_version_id=v.id)=4
            THEN 'PASS' ELSE 'FAIL' END AS result
FROM learning_path_versions v WHERE v.path_code='DEMO_BAC_THUOC'
ORDER BY v.version_no DESC LIMIT 1;

SELECT '=== D7. Path lesson nodes → lesson per event ===' AS check;
SELECT e.slug, ln.lesson_id,
       CASE WHEN ln.lesson_id=s.les_id THEN 'PASS' ELSE 'FAIL' END AS result
FROM learning_path_lesson_nodes ln
JOIN learning_path_event_nodes en ON en.id=ln.event_node_id
JOIN learning_path_versions v ON v.id=en.path_version_id
JOIN historical_events e ON e.id=ln.event_id
JOIN _demo_scope s ON s.ev_id=e.id
WHERE v.path_code='DEMO_BAC_THUOC' ORDER BY e.slug;

SELECT '=== D8. Completion policy → 1 required lesson = demo lesson ===' AS check;
SELECT e.slug, p.policy_version, p.status, p.required_lesson_ids,
       CASE WHEN p.status='PUBLISHED'
             AND jsonb_array_length(p.required_lesson_ids)=1
             AND p.required_lesson_ids->>0 = s.les_id::text
            THEN 'PASS' ELSE 'FAIL' END AS result
FROM event_completion_policies p
JOIN historical_events e ON e.id=p.event_id
JOIN _demo_scope s ON s.ev_id=e.id
WHERE p.status='PUBLISHED' ORDER BY e.slug;

SELECT '=== D9. No duplicate lesson per event among demo lessons ===' AS check;
SELECT e.slug, count(*) AS demo_lessons,
       CASE WHEN count(*)>=1 THEN 'PASS' ELSE 'FAIL' END AS result
FROM lessons l JOIN historical_events e ON e.id=l.event_id
JOIN _demo_scope s ON s.les_id=l.id
GROUP BY e.slug;

SELECT '=== D10. User progress NOT touched (baseline sanity) ===' AS check;
SELECT 'learner_attempts' AS tbl, count(*) FROM learner_attempts
UNION ALL SELECT 'user_event_progress', count(*) FROM user_event_progress
UNION ALL SELECT 'user_dossier_unlocks', count(*) FROM user_dossier_unlocks;

SELECT '=== D11. PUBLISH STATE — DRAFT_READY vs PUBLISHED_READY ===' AS check;
SELECT s.ev_slug, l.status AS lesson_status, l.current_version_id,
       CASE
         WHEN l.status='PUBLISHED' AND l.current_version_id IS NOT NULL
           THEN 'PUBLISHED_READY'
         WHEN l.status='DRAFT' THEN 'DRAFT_READY (chưa publish)'
         ELSE 'NEEDS_ATTENTION' END AS readiness
FROM _demo_scope s JOIN lessons l ON l.id=s.les_id ORDER BY s.ev_slug;

SELECT '=== POSTFLIGHT DONE ===' AS section;
