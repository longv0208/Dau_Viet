-- World Map Việt Nam: đánh dấu tọa độ phần trăm ảnh cũ, không sửa giá trị.
-- lng ≤ 100 không phải kinh độ Việt Nam — giữ nguyên số để admin định vị lại.
-- Không đụng user_location_unlocks, lesson completion hay quan hệ sự kiện.

UPDATE map_locations
SET coordinate_precision = 'SCHEMATIC_ONLY',
    updated_at = now()
WHERE longitude <= 100
  AND coordinate_precision <> 'SCHEMATIC_ONLY';
