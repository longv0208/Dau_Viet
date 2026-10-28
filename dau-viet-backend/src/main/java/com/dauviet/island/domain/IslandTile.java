package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ô địa hình của board tile-based (V48 ISLAND-09-BE). Tọa độ row_index/
 * col_index là tọa độ logic trên lưới — Flutter tự chiếu sang isometric
 * (screenX = (col-row)*tileWidth/2 …), backend không lưu pixel.
 *
 * <p>Immutable sau khi version PUBLISHED — chỉ sửa khi version còn DRAFT.
 * buildable = được phép host một buildable slot (tối đa 1 qua ux_island_slot_tile).
 * region_code liên kết string tới island_layout_regions.region_code (cùng
 * convention với island_slots.region_code — validate tại service, không FK).
 */
@Entity
@Table(name = "island_tiles")
public class IslandTile {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "tile_key", nullable = false)
    private String tileKey;

    @Column(name = "row_index", nullable = false)
    private int rowIndex;

    @Column(name = "col_index", nullable = false)
    private int colIndex;

    @Column(name = "terrain_type", nullable = false)
    private String terrainType;

    @Column(name = "region_code")
    private String regionCode;

    @Column(name = "unlock_tier", nullable = false)
    private int unlockTier;

    @Column(name = "buildable", nullable = false)
    private boolean buildable;

    @Column(name = "visual_key")
    private String visualKey;

    @Column(name = "elevation", nullable = false)
    private int elevation;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandTile() {
    }

    public static IslandTile create(UUID id, UUID layoutVersionId,
                                    String tileKey, int rowIndex, int colIndex,
                                    String terrainType, String regionCode,
                                    int unlockTier, boolean buildable,
                                    String visualKey, int elevation,
                                    Instant now) {
        IslandTile t = new IslandTile();
        t.id = id;
        t.layoutVersionId = layoutVersionId;
        t.tileKey = tileKey;
        t.rowIndex = rowIndex;
        t.colIndex = colIndex;
        t.terrainType = terrainType != null ? terrainType : "GRASS";
        t.regionCode = regionCode;
        t.unlockTier = unlockTier;
        t.buildable = buildable;
        t.visualKey = visualKey;
        t.elevation = elevation;
        t.createdAt = now;
        return t;
    }

    public void update(String tileKey, int rowIndex, int colIndex,
                       String terrainType, String regionCode,
                       int unlockTier, boolean buildable,
                       String visualKey, int elevation) {
        this.tileKey = tileKey;
        this.rowIndex = rowIndex;
        this.colIndex = colIndex;
        if (terrainType != null) this.terrainType = terrainType;
        this.regionCode = regionCode;
        this.unlockTier = unlockTier;
        this.buildable = buildable;
        this.visualKey = visualKey;
        this.elevation = elevation;
    }

    public UUID getId() { return id; }
    public UUID getLayoutVersionId() { return layoutVersionId; }
    public String getTileKey() { return tileKey; }
    public int getRowIndex() { return rowIndex; }
    public int getColIndex() { return colIndex; }
    public String getTerrainType() { return terrainType; }
    public String getRegionCode() { return regionCode; }
    public int getUnlockTier() { return unlockTier; }
    public boolean isBuildable() { return buildable; }
    public String getVisualKey() { return visualKey; }
    public int getElevation() { return elevation; }
    public Instant getCreatedAt() { return createdAt; }
}
