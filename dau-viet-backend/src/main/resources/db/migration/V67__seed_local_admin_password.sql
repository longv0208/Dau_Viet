-- Dấu Việt | V67 | Seed local Content Admin credentials for shared local/dev.
-- Email: admin@dauviet.local
-- Password (plaintext, DEV ONLY): secret
-- BCrypt cost 10. Do not reuse this credential outside local/dev.
-- Idempotent: insert when missing; always reset hash/role/status for that email.

INSERT INTO users (
    id,
    email,
    password_hash,
    display_name,
    role,
    status,
    email_verified_at,
    created_at,
    updated_at,
    row_version
)
SELECT
    '061585cf-42e9-4312-ab4a-3e02c9ac8e70'::uuid,
    'admin@dauviet.local',
    '$2a$10$tfuKlygWoPYVCOCTR3TYNOk/N/bkc9UEHlD0mE/geIbDAEqNLxibG',
    'Admin Dau Viet',
    'CONTENT_ADMIN',
    'ACTIVE',
    now(),
    now(),
    now(),
    0
WHERE NOT EXISTS (
    SELECT 1 FROM users WHERE lower(email) = lower('admin@dauviet.local')
);

UPDATE users
SET password_hash = '$2a$10$tfuKlygWoPYVCOCTR3TYNOk/N/bkc9UEHlD0mE/geIbDAEqNLxibG',
    role = 'CONTENT_ADMIN',
    status = 'ACTIVE',
    display_name = COALESCE(NULLIF(btrim(display_name), ''), 'Admin Dau Viet'),
    updated_at = now(),
    row_version = row_version + 1
WHERE lower(email) = lower('admin@dauviet.local');
