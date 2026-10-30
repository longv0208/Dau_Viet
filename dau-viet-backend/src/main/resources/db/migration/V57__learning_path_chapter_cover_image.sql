-- Migration V57: Add optional cover_image_key to learning_path_chapters
--
-- Purpose
--   Allow admins to configure a thumbnail image per chapter (typically PERIOD)
--   shown on the learner app's PeriodSelectionScreen card. Key is a logical
--   identifier `periods/<code>/<file>` resolved client-side to a bundled asset
--   or remote URL — never a public URL stored directly in the row.
--
-- Safety
--   Nullable column; existing rows keep cover_image_key = NULL and the mobile
--   AssetResolver falls back to the legacy chapter.code lookup table.
ALTER TABLE learning_path_chapters
    ADD COLUMN IF NOT EXISTS cover_image_key VARCHAR(255);
