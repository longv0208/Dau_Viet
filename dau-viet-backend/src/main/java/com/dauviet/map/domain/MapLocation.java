package com.dauviet.map.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

@Entity
@Table(name = "map_locations")
public class MapLocation {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "slug", unique = true, length = 120)
    private String slug;

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "short_summary", length = 500)
    private String shortSummary;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "latitude", nullable = false)
    private double latitude;

    @Column(name = "longitude", nullable = false)
    private double longitude;

    @Column(name = "kind", nullable = false, length = 32)
    private String kind = "HERITAGE_SITE";

    @Column(name = "coordinate_precision", nullable = false, length = 24)
    private String coordinatePrecision = "EXACT";

    @Column(name = "visibility", nullable = false, length = 24)
    private String visibility = "ALWAYS_VISIBLE";

    @Column(name = "unlock_rule_mode", nullable = false, length = 16)
    private String unlockRuleMode = "NONE";

    @Column(name = "cover_asset_id")
    private UUID coverAssetId;


    @Column(name = "map_asset_id")
    private UUID mapAssetId;
    /** Legacy single-lesson unlock column; null = location always AVAILABLE unless multi-lesson rules exist. */
    @Column(name = "unlock_lesson_id")
    private UUID unlockLessonId;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 24)
    private MapLocationStatus status = MapLocationStatus.DRAFT;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public MapLocation() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }

    public String getSlug() { return slug; }
    public void setSlug(String slug) { this.slug = slug; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getShortSummary() { return shortSummary; }
    public void setShortSummary(String shortSummary) { this.shortSummary = shortSummary; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }

    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }

    public String getKind() { return kind != null ? kind : "HERITAGE_SITE"; }
    public void setKind(String kind) {
        this.kind = (kind == null || kind.isBlank()) ? "HERITAGE_SITE" : kind.trim().toUpperCase();
    }

    public String getCoordinatePrecision() { return coordinatePrecision != null ? coordinatePrecision : "EXACT"; }
    public void setCoordinatePrecision(String coordinatePrecision) {
        this.coordinatePrecision = (coordinatePrecision == null || coordinatePrecision.isBlank())
                ? "EXACT" : coordinatePrecision.trim().toUpperCase();
    }

    public String getVisibility() { return visibility != null ? visibility : "ALWAYS_VISIBLE"; }
    public void setVisibility(String visibility) {
        this.visibility = (visibility == null || visibility.isBlank())
                ? "ALWAYS_VISIBLE" : visibility.trim().toUpperCase();
    }

    public String getUnlockRuleMode() { return unlockRuleMode != null ? unlockRuleMode : "NONE"; }
    public void setUnlockRuleMode(String unlockRuleMode) {
        this.unlockRuleMode = (unlockRuleMode == null || unlockRuleMode.isBlank())
                ? "NONE" : unlockRuleMode.trim().toUpperCase();
    }

    public UUID getCoverAssetId() { return coverAssetId; }
    public void setCoverAssetId(UUID coverAssetId) { this.coverAssetId = coverAssetId; }


    public UUID getMapAssetId() { return mapAssetId; }
    public void setMapAssetId(UUID mapAssetId) { this.mapAssetId = mapAssetId; }
    public UUID getUnlockLessonId() { return unlockLessonId; }
    public void setUnlockLessonId(UUID unlockLessonId) { this.unlockLessonId = unlockLessonId; }

    public int getDisplayOrder() { return displayOrder; }
    public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }

    public MapLocationStatus getStatus() { return status; }
    public void setStatus(MapLocationStatus status) { this.status = status; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }
    public Instant getPublishedAt() { return publishedAt; }
    public void setPublishedAt(Instant publishedAt) { this.publishedAt = publishedAt; }
}
