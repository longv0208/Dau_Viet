-- =============================================================================
-- Migration V58: Dynamic Heritage Background Configuration
-- Purpose:
--   Add nullable `background_config_json` (JSONB object) to:
--     1. `learning_path_chapters` (ERA / PERIOD / PHASE)
--     2. `historical_events`
--     3. `lessons`
--   Stores reusable Heritage Background settings (backgroundAssetId,
--   backgroundImageUrl, backgroundMode, focusX, focusY, imageOpacity,
--   fadeStrength, tintPreset, enabled) distinct from cover/thumbnail images.
-- =============================================================================

ALTER TABLE learning_path_chapters
    ADD COLUMN IF NOT EXISTS background_config_json JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_learning_path_chapters_bg_config_object'
    ) THEN
        ALTER TABLE learning_path_chapters
            ADD CONSTRAINT chk_learning_path_chapters_bg_config_object
            CHECK (background_config_json IS NULL OR jsonb_typeof(background_config_json) = 'object');
    END IF;
END $$;

ALTER TABLE historical_events
    ADD COLUMN IF NOT EXISTS background_config_json JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_historical_events_bg_config_object'
    ) THEN
        ALTER TABLE historical_events
            ADD CONSTRAINT chk_historical_events_bg_config_object
            CHECK (background_config_json IS NULL OR jsonb_typeof(background_config_json) = 'object');
    END IF;
END $$;

ALTER TABLE lessons
    ADD COLUMN IF NOT EXISTS background_config_json JSONB;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_lessons_bg_config_object'
    ) THEN
        ALTER TABLE lessons
            ADD CONSTRAINT chk_lessons_bg_config_object
            CHECK (background_config_json IS NULL OR jsonb_typeof(background_config_json) = 'object');
    END IF;
END $$;
