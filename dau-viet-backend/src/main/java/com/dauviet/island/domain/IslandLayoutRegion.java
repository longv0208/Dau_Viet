package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Vùng đất trong layout (V43). Mỗi region gắn với một layout version và
 * mở khoá tự động khi đảo đủ unlock_tier. bounds_json (nullable) chứa hình
 * chữ nhật tương đối {x,y,width,height} để Flutter vẽ overlay khoá/mở.
 * Immutable sau khi layout version PUBLISHED.
 */
@Entity
@Table(name = "island_layout_regions")
public class IslandLayoutRegion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "region_code", nullable = false, updatable = false)
    private String regionCode;

    @Column(name = "unlock_tier", nullable = false, updatable = false)
    private int unlockTier;

    @Column(name = "label")
    private String label;

    /** JSON string: {x, y, width, height} — tương đối theo canvas (0..1). */
    @Column(name = "bounds_json", columnDefinition = "jsonb")
    private String boundsJson;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandLayoutRegion() {
    }

    public UUID getId() { return id; }
    public UUID getLayoutVersionId() { return layoutVersionId; }
    public String getRegionCode() { return regionCode; }
    public int getUnlockTier() { return unlockTier; }
    public String getLabel() { return label; }
    public String getBoundsJson() { return boundsJson; }
    public int getSortOrder() { return sortOrder; }
    public Instant getCreatedAt() { return createdAt; }
}
