package com.dauviet.island.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ngưỡng nâng cấp đảo theo config có version (V32). Mỗi config_version là
 * một tập tier hoàn chỉnh; thay đổi ngưỡng = config_version+1 (row mới),
-- KHÔNG update ngược — giống event_completion_policies (copy-on-write).
 * active=true đánh dấu version đang hiệu lực (partial unique: tối đa 1
 * active version).
 */
@Entity
@Table(name = "island_tier_policies")
public class IslandTierPolicy {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "config_version", nullable = false, updatable = false)
    private int configVersion;

    @Column(name = "tier", nullable = false, updatable = false)
    private int tier;

    @Column(name = "slot_count", nullable = false, updatable = false)
    private int slotCount;

    @Column(name = "required_completed_events", nullable = false,
            updatable = false)
    private int requiredCompletedEvents;

    /**
     * Level tài khoản tối thiểu để nâng lên tier này (V38 ISLAND-01).
     * null = hàng cấu hình cũ (config_version=1, V32) dùng required_completed_events.
     */
    @Column(name = "required_level", updatable = false)
    private Integer requiredLevel;

    @Column(name = "active", nullable = false, updatable = false)
    private boolean active;

    public IslandTierPolicy() {
    }

    public UUID getId()                    { return id; }
    public int getConfigVersion()          { return configVersion; }
    public int getTier()                   { return tier; }
    public int getSlotCount()              { return slotCount; }
    public int getRequiredCompletedEvents(){ return requiredCompletedEvents; }
    /** Null nếu là cấu hình cũ (config_version=1). */
    public Integer getRequiredLevel()      { return requiredLevel; }
    public boolean isActive()              { return active; }
}
