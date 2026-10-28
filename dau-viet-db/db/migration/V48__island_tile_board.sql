-- Dấu Việt | V48 | ISLAND-09-BE — Tile-Based Isometric Board.
-- Phạm vi (additive, không backfill, không sửa dữ liệu cũ):
--   1. Bảng island_layout_boards: cấu hình lưới board 1:1 với layout version.
--      Không có row = layout vẫn dùng rect-model legacy (V44) — adapter chiếu.
--   2. Bảng island_tiles: ô địa hình của board (row_index/col_index logic,
--      KHÔNG pixel). Unique deferrable giống V47 để snapshot-save an toàn.
--   3. ALTER island_slots: thêm tile_id (nullable, FK mềm) + partial unique
--      đảm bảo mỗi tile chứa tối đa 1 buildable slot.
-- Không backfill cho layout v1 đã PUBLISHED (immutable) — LegacyIslandBoardAdapter
-- chiếu board/tiles deterministic lúc đọc; không chạm user_islands/placements.

-- =============================================================================
-- 1. island_layout_boards — cấu hình grid của một layout version (1:1)
-- =============================================================================
CREATE TABLE island_layout_boards (
    layout_version_id UUID PRIMARY KEY REFERENCES island_layout_versions(id),
    grid_rows         INTEGER NOT NULL,
    grid_columns      INTEGER NOT NULL,
    tile_width        DOUBLE PRECISION NOT NULL DEFAULT 128.0,
    tile_height       DOUBLE PRECISION NOT NULL DEFAULT 64.0,
    board_origin_x    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    board_origin_y    DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    projection_type   VARCHAR(24) NOT NULL DEFAULT 'ISOMETRIC',
    -- false = admin cố ý đảo phụ/cầu nối tách cụm; true = kiểm tra liên thông 4-neighbor
    connectivity_required BOOLEAN NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_board_dims CHECK (
        grid_rows BETWEEN 1 AND 32 AND grid_columns BETWEEN 1 AND 32),
    CONSTRAINT chk_board_tile_size CHECK (
        tile_width > 0 AND tile_height > 0),
    CONSTRAINT chk_board_projection CHECK (projection_type IN ('ISOMETRIC'))
);

-- =============================================================================
-- 2. island_tiles — ô địa hình của board (tọa độ logic row/col, không pixel)
-- =============================================================================
-- terrain_type: GRASS/DIRT/PATH/STONE/SAND/DECORATIVE/WATER.
-- WATER = vị trí đánh dấu nước; vị trí không có tile = mặt nước mặc định.
-- region_code liên kết string tới island_layout_regions.region_code (cùng
-- convention với island_slots.region_code — enforce bởi validation, không FK).
-- buildable = tile được phép host một buildable slot (tối đa 1 — ux_island_slot_tile).
CREATE TABLE island_tiles (
    id                UUID PRIMARY KEY,
    layout_version_id UUID NOT NULL REFERENCES island_layout_versions(id),
    tile_key          VARCHAR(48) NOT NULL,
    row_index         INTEGER NOT NULL,
    col_index         INTEGER NOT NULL,
    terrain_type      VARCHAR(24) NOT NULL DEFAULT 'GRASS',
    region_code       VARCHAR(48),
    unlock_tier       INTEGER NOT NULL DEFAULT 1,
    buildable         BOOLEAN NOT NULL DEFAULT false,
    visual_key        VARCHAR(64),
    elevation         INTEGER NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ux_island_tile_key UNIQUE (layout_version_id, tile_key)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT ux_island_tile_coord UNIQUE (layout_version_id, row_index, col_index)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT chk_island_tile_tier CHECK (unlock_tier BETWEEN 1 AND 9),
    CONSTRAINT chk_island_tile_terrain CHECK (terrain_type IN (
        'GRASS', 'DIRT', 'PATH', 'STONE', 'SAND', 'DECORATIVE', 'WATER'))
);
CREATE INDEX idx_island_tiles_version
    ON island_tiles(layout_version_id, row_index, col_index);

-- =============================================================================
-- 3. ALTER island_slots — slot gắn 1:1 với tile (nullable = legacy/unlinked)
-- =============================================================================
ALTER TABLE island_slots
    ADD COLUMN tile_id UUID REFERENCES island_tiles(id);

-- Mỗi tile tối đa 1 buildable slot (partial unique — NULL = chưa link).
CREATE UNIQUE INDEX ux_island_slot_tile
    ON island_slots(tile_id) WHERE tile_id IS NOT NULL;
