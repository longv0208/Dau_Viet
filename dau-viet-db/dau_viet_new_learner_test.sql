-- DAU VIET | ONE-TIME LEARNER FOR LOCAL DEV/TEST ONLY
-- Display name: test | Login email: test@dauviet.test
-- Password: 123123 (stored as BCrypt below; NEVER plaintext in DB)
-- NOTE: Flutter login requires an email containing @; literal "test" cannot be used
-- as a login identifier without modifying the Flutter auth validation.
-- Registration endpoint enforces password >=8; this deliberately inserts
-- a dev-only test account directly into PostgreSQL instead.
-- This creates ONE fresh learner. It does NOT modify or reset any existing user.
-- If the email is already taken, insertion FAILS rather than changing their password.

BEGIN;
INSERT INTO users (id, email, password_hash, display_name, role, status)
VALUES (
    '7777f716-ff00-4532-b88a-79f062b833b8'::uuid,
    'test@dauviet.test',
    '$2y$12$VGTXAuVX5cWZAciEqI776uZYUGBgfKtX0gqPFIPryijQ19Q2mBv0C',
    'test',
    'LEARNER',
    'ACTIVE'
);
COMMIT;

-- Confirm all progress counters are ZERO after the first insert.
-- user_energy is lazily initialized to max 100/100 upon first API access.
SELECT
    u.id, u.email, u.display_name, u.role, u.status,
    (SELECT COUNT(*) FROM learner_attempts a WHERE a.user_id=u.id) AS lesson_attempts,
    (SELECT COUNT(*) FROM user_evidence e WHERE e.user_id=u.id) AS evidence_collected,
    (SELECT COUNT(*) FROM user_event_progress p WHERE p.user_id=u.id) AS event_milestones,
    (SELECT COUNT(*) FROM user_dossier_unlocks d WHERE d.user_id=u.id) AS dossiers_unlocked,
    (SELECT COUNT(*) FROM user_inventory i WHERE i.user_id=u.id) AS inventory_items,
    (SELECT COUNT(*) FROM reward_transactions r WHERE r.user_id=u.id) AS reward_transactions,
    (SELECT COUNT(*) FROM user_energy en WHERE en.user_id=u.id) AS energy_rows_before_first_read
FROM users u
WHERE u.id='7777f716-ff00-4532-b88a-79f062b833b8'::uuid;
