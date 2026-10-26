-- DB cleanup 2026-10-26 — remove test/demo + archived duplicate events.
-- Run inside ONE transaction; FK order: attempts-graph → versions → locations →
-- lessons → evidences → event-scope → events → users.
-- Backup before: backups/dauviet_before_clean_261026.dump

BEGIN;

-- Bypass trg_lesson_versions_immutable (blocks DELETE on lesson_versions).
SET LOCAL session_replication_role = 'replica';

-- ============ TARGET SETS ============
-- Events to delete: test/demo + ARCHIVED duplicates.
CREATE TEMP TABLE del_events(id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO del_events VALUES
  ('f614d71e-37d7-4ce4-9cb3-ee1f993d7d25'), -- test        (ARCHIVED)
  ('a7fbe644-3f66-48e5-9c68-8ab1f68041c8'), -- test123123  (PUBLISHED)
  ('b6ab2096-c2e2-44c1-ace8-1069b4ab84f9'), -- demo        (DRAFT)
  ('7613064b-513a-4bda-b447-4497c4498fef'), -- demo1       (PUBLISHED)
  ('7769cf5e-37b9-488b-b76e-b891cb5964d1'), -- demo2       (PUBLISHED)
  ('d7b00000-0000-4000-8000-000000000002'), -- hai-ba-trung-40        (ARCHIVED dup)
  ('29780b5e-13cd-45ef-8f10-21328cfd65d9'), -- history-hai-ba-trung   (ARCHIVED dup)
  ('e350ab90-0d83-47d1-972c-8d14e37dc80d'), -- khoi-nghia-hai-ba-trung(ARCHIVED dup)
  ('635d6143-ffe1-4770-91e4-a4e4194fb1b7'), -- history-bach-dang-938  (ARCHIVED dup)
  ('d7b00000-0000-4000-8000-000000000003'), -- ly-thai-to-1010        (ARCHIVED dup)
  ('cd1b6dab-777a-40d4-833d-8e580df3949e'); -- history-dien-bien-phu-1954 (ARCHIVED dup)

-- Lessons to delete: every lesson of del_events + junk inside real event 0001.
CREATE TEMP TABLE del_lessons(id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO del_lessons
  SELECT id FROM lessons WHERE event_id IN (SELECT id FROM del_events)
  UNION
  SELECT * FROM (VALUES
    ('3522b78d-058f-474e-afa6-2de1c7de2a86'::uuid), -- "333"    in bach-dang-938
    ('e1e3aa64-31c3-408c-83cc-132eb132de5a'::uuid)  -- "bí mật" in bach-dang-938
  ) AS t(id);

-- map_locations to delete: every row of del_events + junk rows in event 0001.
CREATE TEMP TABLE del_locations(id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO del_locations
  SELECT id FROM map_locations WHERE event_id IN (SELECT id FROM del_events)
  UNION
  SELECT * FROM (VALUES
    ('a8343942-7412-4a0d-aad9-daf32d297cd1'::uuid), -- "333"  event 0001
    ('42bcd844-0d22-4570-b80f-18b0aca61f4b'::uuid)  -- "test" event 0001 (unlock → bí mật)
  ) AS t(id);

-- lesson_versions belonging to del_lessons.
CREATE TEMP TABLE del_versions(id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO del_versions SELECT id FROM lesson_versions WHERE lesson_id IN (SELECT id FROM del_lessons);

-- learner_attempts to delete: every attempt on del_versions + every attempt by the 2 test users.
CREATE TEMP TABLE del_attempts(id uuid PRIMARY KEY) ON COMMIT DROP;
INSERT INTO del_attempts
  SELECT id FROM learner_attempts
  WHERE lesson_version_id IN (SELECT id FROM del_versions)
     OR user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');

-- ============ 1) ATTEMPT-GRAPH CHILDREN ============
DELETE FROM activity_attempts   WHERE learner_attempt_id IN (SELECT id FROM del_attempts);
DELETE FROM lesson_results      WHERE learner_attempt_id IN (SELECT id FROM del_attempts);
DELETE FROM reward_transactions WHERE learner_attempt_id IN (SELECT id FROM del_attempts);
DELETE FROM user_evidence       WHERE learner_attempt_id IN (SELECT id FROM del_attempts);
DELETE FROM user_inventory      WHERE source_attempt_id  IN (SELECT id FROM del_attempts);
DELETE FROM learner_attempts    WHERE id IN (SELECT id FROM del_attempts);

-- ============ 2) LESSON_GRAPH ============
-- chk_lesson_published_version: PUBLISHED requires current_version_id NOT NULL.
-- Flip status → DRAFT first, then detach current_version_id, then delete.
UPDATE lessons SET status = 'DRAFT' WHERE id IN (SELECT id FROM del_lessons);
UPDATE lessons SET current_version_id = NULL WHERE id IN (SELECT id FROM del_lessons);
UPDATE map_locations SET unlock_lesson_id = NULL
  WHERE unlock_lesson_id IN (SELECT id FROM del_lessons);
-- item_unlock_rule → lesson_id
DELETE FROM item_unlock_rule WHERE lesson_id IN (SELECT id FROM del_lessons);
-- user_inventory.source_lesson_id
DELETE FROM user_inventory WHERE source_lesson_id IN (SELECT id FROM del_lessons);
-- map_locations rows themselves
DELETE FROM map_locations WHERE id IN (SELECT id FROM del_locations);
-- versions then lessons (self-FK lessons.id→lesson_versions handled by replica mode above)
DELETE FROM lesson_versions WHERE id IN (SELECT id FROM del_versions);
DELETE FROM lessons WHERE id IN (SELECT id FROM del_lessons);

-- ============ 3) EVIDENCES of del_events ============
DELETE FROM user_evidence WHERE evidence_id IN (SELECT id FROM evidences WHERE event_id IN (SELECT id FROM del_events));
DELETE FROM evidences WHERE event_id IN (SELECT id FROM del_events);

-- ============ 4) EVENT-SCOPED LEFTOVERS ============
DELETE FROM event_dossiers            WHERE event_id IN (SELECT id FROM del_events);
DELETE FROM event_completion_policies WHERE event_id IN (SELECT id FROM del_events);
DELETE FROM user_event_progress       WHERE event_id IN (SELECT id FROM del_events);
DELETE FROM user_dossier_unlocks      WHERE event_id IN (SELECT id FROM del_events);
DELETE FROM user_inventory            WHERE source_event_id IN (SELECT id FROM del_events);
DELETE FROM animation_scenes          WHERE event_id IN (SELECT id FROM del_events); -- cascade → html/version refs
DELETE FROM historical_events         WHERE id IN (SELECT id FROM del_events);

-- ============ 5) TEST USERS + their leftovers ============
-- activity chains already gone via del_attempts; clean residual user-scope rows.
DELETE FROM user_evidence       WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM user_inventory      WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM user_event_progress WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM user_dossier_unlocks WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM user_energy         WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM energy_transactions WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM reward_transactions WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM idempotency_records WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM auth_refresh_tokens WHERE user_id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');
DELETE FROM users WHERE id IN ('03dbf84c-3c4a-4744-8d7b-c92deb3a7d80','7777f716-ff00-4532-b88a-79f062b833b8');

COMMIT;
