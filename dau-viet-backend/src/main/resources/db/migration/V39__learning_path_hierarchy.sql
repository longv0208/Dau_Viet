-- Dấu Việt | V38 | Learning Path Hierarchy (ERA -> PERIOD -> PHASE) & Event Date Precision (Issue #11 / B1)

-- 1. Extend learning_path_chapters with tree hierarchy columns
ALTER TABLE learning_path_chapters
    ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES learning_path_chapters(id) ON DELETE RESTRICT,
    ADD COLUMN IF NOT EXISTS node_type VARCHAR(16) NOT NULL DEFAULT 'PERIOD';

ALTER TABLE learning_path_chapters
    DROP CONSTRAINT IF EXISTS chk_chapter_node_type,
    ADD CONSTRAINT chk_chapter_node_type CHECK (node_type IN ('ERA', 'PERIOD', 'PHASE'));

ALTER TABLE learning_path_chapters
    DROP CONSTRAINT IF EXISTS chk_chapter_no_self_parent,
    ADD CONSTRAINT chk_chapter_no_self_parent CHECK (parent_id IS NULL OR parent_id <> id);

-- Scope sort_order uniqueness per (path_version_id, parent_id) so both flat roots and tree siblings can use 1..N
ALTER TABLE learning_path_chapters
    DROP CONSTRAINT IF EXISTS ux_path_chapter_version_sort,
    ADD CONSTRAINT ux_path_chapter_version_sort
        UNIQUE NULLS NOT DISTINCT (path_version_id, parent_id, sort_order) DEFERRABLE;

CREATE INDEX IF NOT EXISTS idx_path_chapter_parent
    ON learning_path_chapters (parent_id, sort_order);

-- 2. Extend historical_events with end_year and date_precision
ALTER TABLE historical_events
    ADD COLUMN IF NOT EXISTS end_year INTEGER,
    ADD COLUMN IF NOT EXISTS date_precision VARCHAR(16) NOT NULL DEFAULT 'EXACT';

ALTER TABLE historical_events
    DROP CONSTRAINT IF EXISTS chk_event_date_precision,
    ADD CONSTRAINT chk_event_date_precision
        CHECK (date_precision IN ('EXACT', 'CIRCA', 'CENTURY', 'PERIOD'));

ALTER TABLE historical_events
    DROP CONSTRAINT IF EXISTS chk_event_year_range,
    ADD CONSTRAINT chk_event_year_range
        CHECK (end_year IS NULL OR start_year IS NULL OR start_year <= end_year);
