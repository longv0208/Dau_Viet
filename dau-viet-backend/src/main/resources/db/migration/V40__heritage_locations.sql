-- Dấu Việt | V39 | Independent Heritage Locations, Multi-Event Links, Multi-Lesson Unlock Rules & Media (Issue #15 / C1)

-- 1. Relax same-event constraint & make event_id optional on map_locations
ALTER TABLE map_locations
    DROP CONSTRAINT IF EXISTS fk_map_location_unlock_lesson_same_event;

ALTER TABLE map_locations
    ALTER COLUMN event_id DROP NOT NULL;

-- 2. Extend map_locations with heritage metadata
ALTER TABLE map_locations
    ADD COLUMN IF NOT EXISTS slug VARCHAR(120) UNIQUE,
    ADD COLUMN IF NOT EXISTS kind VARCHAR(32) NOT NULL DEFAULT 'HERITAGE_SITE',
    ADD COLUMN IF NOT EXISTS coordinate_precision VARCHAR(24) NOT NULL DEFAULT 'EXACT',
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(24) NOT NULL DEFAULT 'ALWAYS_VISIBLE',
    ADD COLUMN IF NOT EXISTS unlock_rule_mode VARCHAR(16) NOT NULL DEFAULT 'ANY',
    ADD COLUMN IF NOT EXISTS cover_asset_id UUID REFERENCES assets(id),
    ADD COLUMN IF NOT EXISTS short_summary VARCHAR(500);

ALTER TABLE map_locations
    DROP CONSTRAINT IF EXISTS chk_map_location_kind,
    ADD CONSTRAINT chk_map_location_kind CHECK (kind IN (
        'HERITAGE_SITE', 'BATTLEFIELD', 'ANCIENT_CAPITAL',
        'ARCHAEOLOGICAL_SITE', 'MEMORIAL', 'SCHEMATIC_REGION'
    ));

ALTER TABLE map_locations
    DROP CONSTRAINT IF EXISTS chk_map_location_coord_precision,
    ADD CONSTRAINT chk_map_location_coord_precision CHECK (coordinate_precision IN (
        'EXACT', 'APPROXIMATE', 'SCHEMATIC_ONLY'
    ));

ALTER TABLE map_locations
    DROP CONSTRAINT IF EXISTS chk_map_location_visibility,
    ADD CONSTRAINT chk_map_location_visibility CHECK (visibility IN (
        'ALWAYS_VISIBLE', 'HIDDEN_UNTIL_UNLOCKED'
    ));

ALTER TABLE map_locations
    DROP CONSTRAINT IF EXISTS chk_map_location_unlock_mode,
    ADD CONSTRAINT chk_map_location_unlock_mode CHECK (unlock_rule_mode IN (
        'NONE', 'ANY', 'ALL'
    ));

UPDATE map_locations
SET unlock_rule_mode = 'NONE'
WHERE unlock_lesson_id IS NULL;

-- 3. N-N relation between map_locations and historical_events
CREATE TABLE IF NOT EXISTS map_location_events (
    location_id UUID NOT NULL REFERENCES map_locations(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES historical_events(id) ON DELETE CASCADE,
    role VARCHAR(24) NOT NULL DEFAULT 'PRIMARY',
    sort_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (location_id, event_id),
    CONSTRAINT chk_map_location_event_role CHECK (role IN ('PRIMARY', 'RELATED'))
);

CREATE INDEX IF NOT EXISTS idx_map_location_events_event
    ON map_location_events(event_id);

INSERT INTO map_location_events (location_id, event_id, role, sort_order)
SELECT id, event_id, 'PRIMARY', display_order
FROM map_locations
WHERE event_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 4. Multi-lesson unlock rules (supports ANY / ALL across events)
CREATE TABLE IF NOT EXISTS map_location_unlock_lessons (
    location_id UUID NOT NULL REFERENCES map_locations(id) ON DELETE CASCADE,
    lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
    PRIMARY KEY (location_id, lesson_id)
);

CREATE INDEX IF NOT EXISTS idx_map_location_unlock_lessons_lesson
    ON map_location_unlock_lessons(lesson_id);

INSERT INTO map_location_unlock_lessons (location_id, lesson_id)
SELECT id, unlock_lesson_id
FROM map_locations
WHERE unlock_lesson_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 5. Location rich media (PUBLIC_PREVIEW vs UNLOCKED_ONLY)
CREATE TABLE IF NOT EXISTS map_location_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_id UUID NOT NULL REFERENCES map_locations(id) ON DELETE CASCADE,
    media_type VARCHAR(24) NOT NULL,
    title VARCHAR(255) NOT NULL,
    caption TEXT,
    asset_id UUID REFERENCES assets(id),
    external_url VARCHAR(1024),
    visibility VARCHAR(24) NOT NULL DEFAULT 'UNLOCKED_ONLY',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_location_media_type CHECK (media_type IN (
        'IMAGE_2D', 'PANORAMA_360', 'AUDIO_GUIDE', 'DOCUMENTARY_CLIP'
    )),
    CONSTRAINT chk_location_media_visibility CHECK (visibility IN (
        'PUBLIC_PREVIEW', 'UNLOCKED_ONLY'
    ))
);

CREATE INDEX IF NOT EXISTS idx_map_location_media_loc
    ON map_location_media(location_id, sort_order);

-- 6. User location unlocks ledger
CREATE TABLE IF NOT EXISTS user_location_unlocks (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES map_locations(id) ON DELETE CASCADE,
    source_lesson_id UUID REFERENCES lessons(id),
    source_attempt_id UUID REFERENCES learner_attempts(id),
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, location_id)
);

CREATE INDEX IF NOT EXISTS idx_user_location_unlocks_attempt
    ON user_location_unlocks(source_attempt_id);
