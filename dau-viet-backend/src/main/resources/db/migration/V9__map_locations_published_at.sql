-- Dấu Việt MVP | V9 | map_locations.published_at — bất biến sau lần publish
-- đầu. unlock_lesson_id immutable khi published_at IS NOT NULL (không thể
-- bypass bằng archive→relink→republish). NULL = chưa từng publish.
ALTER TABLE map_locations
    ADD COLUMN published_at TIMESTAMPTZ;
-- Backfill: location đang PUBLISHED/ARCHIVED đã từng publish → set now()
-- (thời điểm ghi nhận policy, không phải lần publish thật — không có log).
UPDATE map_locations SET published_at = now()
    WHERE status IN ('PUBLISHED','ARCHIVED');
