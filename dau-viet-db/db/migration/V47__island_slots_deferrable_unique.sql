-- Dấu Việt | V47 | ISLAND-08-FIX — Chuyển các ràng buộc UNIQUE trên island_slots, island_layout_regions, island_scene_layers sang DEFERRABLE INITIALLY DEFERRED để hỗ trợ đổi thứ tự/hoán đổi slot_index (1..64) trực tiếp trong transaction mà không dùng giá trị tạm ngoài phạm vi.

ALTER TABLE island_slots
    DROP CONSTRAINT IF EXISTS ux_island_slot_version_index,
    DROP CONSTRAINT IF EXISTS ux_island_slot_version_key,
    ADD CONSTRAINT ux_island_slot_version_index
        UNIQUE (layout_version_id, slot_index) DEFERRABLE INITIALLY DEFERRED,
    ADD CONSTRAINT ux_island_slot_version_key
        UNIQUE (layout_version_id, stable_slot_key) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE island_layout_regions
    DROP CONSTRAINT IF EXISTS ux_island_region,
    ADD CONSTRAINT ux_island_region
        UNIQUE (layout_version_id, region_code) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE island_scene_layers
    DROP CONSTRAINT IF EXISTS ux_island_scene_layer,
    ADD CONSTRAINT ux_island_scene_layer
        UNIQUE (layout_version_id, layer_key) DEFERRABLE INITIALLY DEFERRED;
