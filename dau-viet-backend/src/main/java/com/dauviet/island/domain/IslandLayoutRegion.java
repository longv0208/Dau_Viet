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
 * Vùng đất trong layout (V44). Mỗi region gắn với một layout version và
 * mở khoá tự động khi đảo đủ unlock_tier. bounds_json chứa hình
 * chữ nhật tương đối {x,y,width,height} để Flutter vẽ overlay khoá/mở.
 */
@Entity
@Table(name = "island_layout_regions")
public class IslandLayoutRegion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "layout_version_id", nullable = false, updatable = false)
    private UUID layoutVersionId;

    @Column(name = "region_code", nullable = false)
    private String regionCode;

    @Column(name = "unlock_tier", nullable = false)
    private int unlockTier;

    @Column(name = "label")
    private String label;

    /** JSON string: {x, y, width, height} — tương đối theo canvas (0..1). */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "bounds_json", columnDefinition = "jsonb")
    private String boundsJson;

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandLayoutRegion() {
    }

    public static IslandLayoutRegion create(UUID id, UUID layoutVersionId,
                                            String regionCode, int unlockTier,
                                            String label, String boundsJson,
                                            int sortOrder, Instant now) {
        IslandLayoutRegion r = new IslandLayoutRegion();
        r.id = id;
        r.layoutVersionId = layoutVersionId;
        r.regionCode = regionCode;
        r.unlockTier = unlockTier;
        r.label = label;
        r.boundsJson = boundsJson;
        r.sortOrder = sortOrder;
        r.createdAt = now;
        return r;
    }

    public void update(String regionCode, int unlockTier, String label,
                       String boundsJson, int sortOrder) {
        this.regionCode = regionCode;
        this.unlockTier = unlockTier;
        this.label = label;
        this.boundsJson = boundsJson;
        this.sortOrder = sortOrder;
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
