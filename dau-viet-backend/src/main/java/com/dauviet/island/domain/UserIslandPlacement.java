package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Vật phẩm decor đang đặt trên đảo (V32). PK (user_id, slot_id) — một ô
 * chứa tối đa một vật phẩm; UNIQUE(user_id, item_id) — một vật phẩm
 * non-stackable xuất hiện tối đa một lần trên đảo (V1 non-stackable theo
 * BUSINESS §9.1). FK (user_id,item_id) → user_inventory đảm bảo chỉ item
 * đã sở hữu mới được đặt; service check item.placeable trước khi insert.
 */
@Entity
@Table(name = "user_island_placements")
@IdClass(UserIslandPlacementId.class)
public class UserIslandPlacement {

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "slot_id", nullable = false, updatable = false)
    private UUID slotId;

    @Column(name = "item_id", nullable = false, updatable = false)
    private UUID itemId;

    @Column(name = "placed_at", nullable = false, updatable = false)
    private Instant placedAt;

    public UserIslandPlacement() {
    }

    public static UserIslandPlacement of(UUID userId, UUID slotId,
                                         UUID itemId, Instant now) {
        UserIslandPlacement p = new UserIslandPlacement();
        p.userId = userId;
        p.slotId = slotId;
        p.itemId = itemId;
        p.placedAt = now;
        return p;
    }

    public UUID getUserId() { return userId; }
    public UUID getSlotId() { return slotId; }
    public UUID getItemId() { return itemId; }
    public Instant getPlacedAt() { return placedAt; }
}
