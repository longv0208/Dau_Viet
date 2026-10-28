package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ô đất catalog của layout đảo (V32 + V44). Immutable sau जब version PUBLISHED.
 * Khi ở trạng thái DRAFT, admin có thể thêm, sửa, xóa slot.
 */
@Entity
@Table(name = "island_slots")
public class IslandSlot {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_code", nullable = false)
    private String layoutCode;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "slot_index", nullable = false)
    private int slotIndex;

    @Column(name = "tier_required", nullable = false)
    private int tierRequired;

    @Column(name = "coord_x", nullable = false)
    private double coordX;

    @Column(name = "coord_y", nullable = false)
    private double coordY;

    @Column(name = "stable_slot_key", nullable = false)
    private String stableSlotKey;

    @Column(name = "region_code")
    private String regionCode;

    /**
     * Tile chứa slot này (V48 ISLAND-09-BE). NULL = slot legacy chưa link
     * (layout rect-model) hoặc draft đang chờ gán. Tối đa 1 slot/tile —
     * enforced bởi partial unique ux_island_slot_tile.
     */
    @Column(name = "tile_id")
    private UUID tileId;

    @Column(name = "z_index", nullable = false)
    private int zIndex;

    @Column(name = "anchor_x", nullable = false)
    private double anchorX;

    @Column(name = "anchor_y", nullable = false)
    private double anchorY;

    @Column(name = "width_norm", nullable = false)
    private double widthNorm;

    @Column(name = "height_norm", nullable = false)
    private double heightNorm;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "allowed_categories_json", nullable = false, columnDefinition = "jsonb")
    private String allowedCategoriesJson = "[\"DECOR\"]";

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandSlot() {
    }

    public static IslandSlot create(UUID id, String layoutCode, UUID layoutVersionId,
                                    int slotIndex, int tierRequired,
                                    double coordX, double coordY,
                                    String stableSlotKey, String regionCode,
                                    int zIndex, double anchorX, double anchorY,
                                    double widthNorm, double heightNorm,
                                    String allowedCategoriesJson, Instant now) {
        return create(id, layoutCode, layoutVersionId, slotIndex, tierRequired,
                coordX, coordY, stableSlotKey, regionCode, null,
                zIndex, anchorX, anchorY, widthNorm, heightNorm,
                allowedCategoriesJson, now);
    }

    /**
     * Tạo slot kèm tile host (V48). tileId nullable — slot rect-model legacy
     * hoặc draft chưa gán.
     */
    public static IslandSlot create(UUID id, String layoutCode, UUID layoutVersionId,
                                    int slotIndex, int tierRequired,
                                    double coordX, double coordY,
                                    String stableSlotKey, String regionCode,
                                    UUID tileId,
                                    int zIndex, double anchorX, double anchorY,
                                    double widthNorm, double heightNorm,
                                    String allowedCategoriesJson, Instant now) {
        IslandSlot s = new IslandSlot();
        s.id = id;
        s.layoutCode = layoutCode;
        s.layoutVersionId = layoutVersionId;
        s.slotIndex = slotIndex;
        s.tierRequired = tierRequired;
        s.coordX = coordX;
        s.coordY = coordY;
        s.stableSlotKey = stableSlotKey;
        s.regionCode = regionCode;
        s.tileId = tileId;
        s.zIndex = zIndex;
        s.anchorX = anchorX;
        s.anchorY = anchorY;
        s.widthNorm = widthNorm;
        s.heightNorm = heightNorm;
        s.allowedCategoriesJson = allowedCategoriesJson != null ? allowedCategoriesJson : "[\"DECOR\"]";
        s.createdAt = now;
        return s;
    }

    public void update(int slotIndex, int tierRequired, double coordX, double coordY,
                       String stableSlotKey, String regionCode, int zIndex,
                       double anchorX, double anchorY, double widthNorm, double heightNorm,
                       String allowedCategoriesJson) {
        update(slotIndex, tierRequired, coordX, coordY, stableSlotKey,
                regionCode, this.tileId, zIndex, anchorX, anchorY,
                widthNorm, heightNorm, allowedCategoriesJson);
    }

    /** Update kèm tile host (V48) — truyền null để unlink khỏi tile. */
    public void update(int slotIndex, int tierRequired, double coordX, double coordY,
                       String stableSlotKey, String regionCode, UUID tileId, int zIndex,
                       double anchorX, double anchorY, double widthNorm, double heightNorm,
                       String allowedCategoriesJson) {
        this.slotIndex = slotIndex;
        this.tierRequired = tierRequired;
        this.coordX = coordX;
        this.coordY = coordY;
        this.stableSlotKey = stableSlotKey;
        this.regionCode = regionCode;
        this.tileId = tileId;
        this.zIndex = zIndex;
        this.anchorX = anchorX;
        this.anchorY = anchorY;
        this.widthNorm = widthNorm;
        this.heightNorm = heightNorm;
        if (allowedCategoriesJson != null) {
            this.allowedCategoriesJson = allowedCategoriesJson;
        }
    }

    public UUID getId() { return id; }
    public String getLayoutCode() { return layoutCode; }
    public UUID getLayoutVersionId() { return layoutVersionId; }
    public int getSlotIndex() { return slotIndex; }
    public int getTierRequired() { return tierRequired; }
    public double getCoordX() { return coordX; }
    public double getCoordY() { return coordY; }
    public String getStableSlotKey() { return stableSlotKey; }
    public String getRegionCode() { return regionCode; }
    public UUID getTileId() { return tileId; }
    public int getZIndex() { return zIndex; }
    public double getAnchorX() { return anchorX; }
    public double getAnchorY() { return anchorY; }
    public double getWidthNorm() { return widthNorm; }
    public double getHeightNorm() { return heightNorm; }
    public String getAllowedCategoriesJson() { return allowedCategoriesJson; }
    public Instant getCreatedAt() { return createdAt; }
}
