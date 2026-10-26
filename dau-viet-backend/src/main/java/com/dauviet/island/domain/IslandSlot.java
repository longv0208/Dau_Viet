package com.dauviet.island.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ô đất catalog của layout đảo (V32). 12 slot cố định cho layout
 * 'heritage-v1', slot_index 1..12; tier_required = bậc đảo tối thiểu để
 * slot mở khoá. Toạ độ 0..1 tương đối — client scale theo màn hình.
 * Đây là catalog reference data, không sửa sau seed (append-only khi thêm
 * layout mới, KHÔNG update ngược tọa độ đã publish).
 */
@Entity
@Table(name = "island_slots")
public class IslandSlot {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_code", nullable = false, updatable = false)
    private String layoutCode;

    @Column(name = "slot_index", nullable = false, updatable = false)
    private int slotIndex;

    @Column(name = "tier_required", nullable = false, updatable = false)
    private int tierRequired;

    @Column(name = "coord_x", nullable = false, updatable = false)
    private double coordX;

    @Column(name = "coord_y", nullable = false, updatable = false)
    private double coordY;

    public IslandSlot() {
    }

    public UUID getId() { return id; }
    public String getLayoutCode() { return layoutCode; }
    public int getSlotIndex() { return slotIndex; }
    public int getTierRequired() { return tierRequired; }
    public double getCoordX() { return coordX; }
    public double getCoordY() { return coordY; }
}
