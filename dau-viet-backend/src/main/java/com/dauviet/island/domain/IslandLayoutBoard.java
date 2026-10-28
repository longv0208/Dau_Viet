package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Cấu hình lưới board của một layout version (V48 ISLAND-09-BE) — quan hệ
 * 1:1 với island_layout_versions qua PK layout_version_id.
 *
 * <p>Không có row = version vẫn dùng rect-model legacy (V44 bounds/coords) —
 * LegacyIslandBoardAdapter chiếu board/tiles lúc đọc cho /me/island.
 *
 * <p>connectivity_required=false cho phép Admin khai báo cố ý đảo phụ/cầu
 * nối (bỏ kiểm tra liên thông 4-neighbor khi publish).
 */
@Entity
@Table(name = "island_layout_boards")
public class IslandLayoutBoard {

    @Id
    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "grid_rows", nullable = false)
    private int gridRows;

    @Column(name = "grid_columns", nullable = false)
    private int gridColumns;

    @Column(name = "tile_width", nullable = false)
    private double tileWidth;

    @Column(name = "tile_height", nullable = false)
    private double tileHeight;

    @Column(name = "board_origin_x", nullable = false)
    private double boardOriginX;

    @Column(name = "board_origin_y", nullable = false)
    private double boardOriginY;

    @Column(name = "projection_type", nullable = false)
    private String projectionType;

    @Column(name = "connectivity_required", nullable = false)
    private boolean connectivityRequired;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public IslandLayoutBoard() {
    }

    public static IslandLayoutBoard create(UUID layoutVersionId,
                                           int gridRows, int gridColumns,
                                           double tileWidth, double tileHeight,
                                           double boardOriginX, double boardOriginY,
                                           String projectionType,
                                           boolean connectivityRequired,
                                           Instant now) {
        IslandLayoutBoard b = new IslandLayoutBoard();
        b.layoutVersionId = layoutVersionId;
        b.gridRows = gridRows;
        b.gridColumns = gridColumns;
        b.tileWidth = tileWidth;
        b.tileHeight = tileHeight;
        b.boardOriginX = boardOriginX;
        b.boardOriginY = boardOriginY;
        b.projectionType = projectionType != null ? projectionType : "ISOMETRIC";
        b.connectivityRequired = connectivityRequired;
        b.createdAt = now;
        b.updatedAt = now;
        return b;
    }

    public void update(int gridRows, int gridColumns,
                       double tileWidth, double tileHeight,
                       double boardOriginX, double boardOriginY,
                       String projectionType, boolean connectivityRequired,
                       Instant now) {
        this.gridRows = gridRows;
        this.gridColumns = gridColumns;
        this.tileWidth = tileWidth;
        this.tileHeight = tileHeight;
        this.boardOriginX = boardOriginX;
        this.boardOriginY = boardOriginY;
        if (projectionType != null) this.projectionType = projectionType;
        this.connectivityRequired = connectivityRequired;
        this.updatedAt = now;
    }

    public UUID getLayoutVersionId() { return layoutVersionId; }
    public int getGridRows() { return gridRows; }
    public int getGridColumns() { return gridColumns; }
    public double getTileWidth() { return tileWidth; }
    public double getTileHeight() { return tileHeight; }
    public double getBoardOriginX() { return boardOriginX; }
    public double getBoardOriginY() { return boardOriginY; }
    public String getProjectionType() { return projectionType; }
    public boolean isConnectivityRequired() { return connectivityRequired; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
