-- Dấu Việt MVP | V8 | Historical Map locations (FR-35..38).
-- Location gắn 1 historical_event; unlock rule MVP: learner có >=1 attempt
-- COMPLETED của unlock_lesson (mọi published version) → UNLOCKED.
CREATE TABLE map_locations (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES historical_events(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    unlock_lesson_id UUID REFERENCES lessons(id),
    display_order INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_map_location_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_map_location_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_map_location_lng CHECK (longitude BETWEEN -180 AND 180)
);
CREATE INDEX idx_map_locations_event ON map_locations(event_id, status, display_order);
CREATE INDEX idx_map_locations_unlock_lesson ON map_locations(unlock_lesson_id);

-- unlock_lesson phải thuộc CÙNG event với location — FK composite qua
-- (event_id, lesson_id). Cần unique phụ trên lessons(event_id, id).
ALTER TABLE lessons ADD CONSTRAINT ux_lessons_event_id UNIQUE (event_id, id);
ALTER TABLE map_locations
    ADD CONSTRAINT fk_map_location_unlock_lesson_same_event
    FOREIGN KEY (event_id, unlock_lesson_id)
    REFERENCES lessons(event_id, id);
