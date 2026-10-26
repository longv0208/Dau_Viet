package com.dauviet.island.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/**
 * Composite PK (user_id, slot_id) cho {@link UserIslandPlacement}.
 */
public class UserIslandPlacementId implements Serializable {

    private UUID userId;
    private UUID slotId;

    public UserIslandPlacementId() {
    }

    public UserIslandPlacementId(UUID userId, UUID slotId) {
        this.userId = userId;
        this.slotId = slotId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof UserIslandPlacementId that)) return false;
        return Objects.equals(userId, that.userId)
                && Objects.equals(slotId, that.slotId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, slotId);
    }
}
