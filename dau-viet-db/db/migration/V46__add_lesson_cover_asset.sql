-- =============================================================================
-- Migration V44: Add optional cover_asset_id to lessons
-- Purpose:
--   Add nullable presentation metadata column `cover_asset_id` on `lessons`
--   referencing `assets(id)`. Does not modify or delete existing lesson data
--   or immutable `lesson_versions` snapshots.
-- =============================================================================

ALTER TABLE lessons
    ADD COLUMN IF NOT EXISTS cover_asset_id UUID REFERENCES assets(id);

CREATE INDEX IF NOT EXISTS idx_lessons_cover_asset
    ON lessons (cover_asset_id);
