package com.dauviet.island.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ô đất catalog của layout đảo (V32 + V43). Immutable sau seed/publish —
 * không sửa tọa độ hoặc tier của slot đã được xuất bản.
 *
 * <p>V32: id, layout_code, slot_index, tier_required, coord_x, coord_y.
 * <p>V43: layout_version_id, stable_slot_key, region_code, z_index,
 *         anchor_x, anchor_y, width_norm, height_norm.
 *
 * <p>Lookup phổ biến: findByLayoutVersionId (IslandService sau V43) hoặc
 * findByLayoutCode (legacy trước khi backfill hoàn toàn).
 */
@Entity
@Table(name = "island_slots")
public class IslandSlot {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    /** Legacy layout code ('heritage-v1'). Giữ nguyên sau V43 cho query tương thích. */
    @Column(name = "layout_code", nullable = false, updatable = false)
    private String layoutCode;

    /** FK → island_layout_versions.id (V43). NOT NULL sau backfill. */
    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "slot_index", nullable = false, updatable = false)
    private int slotIndex;

    @Column(name = "tier_required", nullable = false, updatable = false)
    private int tierRequired;

    @Column(name = "coord_x", nullable = false, updatable = false)
    private double coordX;

    @Column(name = "coord_y", nullable = false, updatable = false)
    private double coordY;

    /** Key ổn định để client tham chiếu slot sau khi layout publish (V43). */
    @Column(name = "stable_slot_key", updatable = false)
    private String stableSlotKey;

    /** Vùng đất mà slot thuộc về (TIER_1, TIER_2, TIER_3) (V43). */
    @Column(name = "region_code", updatable = false)
    private String regionCode;

    /** Thứ tự xếp lớp render — lớn hơn = phía trước (V43). */
    @Column(name = "z_index", nullable = false)
    private int zIndex;

    /** Điểm neo ngang của widget trang trí, 0..1 (0.5 = center) (V43). */
    @Column(name = "anchor_x", nullable = false)
    private double anchorX;

    /** Điểm neo dọc của widget trang trí, 0..1 (1.0 = bottom) (V43). */
    @Column(name = "anchor_y", nullable = false)
    private double anchorY;

    /** Chiều rộng tương đối theo canvas (V43). */
    @Column(name = "width_norm", nullable = false)
    private double widthNorm;

    /** Chiều cao tương đối theo canvas (V43). */
    @Column(name = "height_norm", nullable = false)
    private double heightNorm;

    public IslandSlot() {
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
    public int getZIndex() { return zIndex; }
    public double getAnchorX() { return anchorX; }
    public double getAnchorY() { return anchorY; }
    public double getWidthNorm() { return widthNorm; }
    public double getHeightNorm() { return heightNorm; }
}
