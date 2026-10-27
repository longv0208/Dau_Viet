package com.dauviet.map.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "map_location_media")
public class MapLocationMedia {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "location_id", nullable = false)
    private UUID locationId;

    @Column(name = "media_type", nullable = false, length = 24)
    private String mediaType;

    @Column(name = "title", nullable = false, length = 255)
    private String title;

    @Column(name = "caption", columnDefinition = "text")
    private String caption;

    @Column(name = "asset_id")
    private UUID assetId;

    @Column(name = "external_url", length = 1024)
    private String externalUrl;

    @Column(name = "visibility", nullable = false, length = 24)
    private String visibility = "UNLOCKED_ONLY";

    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected MapLocationMedia() {}

    public MapLocationMedia(UUID id, UUID locationId, String mediaType, String title,
                            String caption, UUID assetId, String externalUrl,
                            String visibility, int sortOrder) {
        this.id = id != null ? id : UUID.randomUUID();
        this.locationId = locationId;
        this.mediaType = mediaType.trim().toUpperCase();
        this.title = title;
        this.caption = caption;
        this.assetId = assetId;
        this.externalUrl = externalUrl;
        this.visibility = (visibility == null || visibility.isBlank())
                ? "UNLOCKED_ONLY" : visibility.trim().toUpperCase();
        this.sortOrder = sortOrder;
        this.createdAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getLocationId() { return locationId; }
    public String getMediaType() { return mediaType; }
    public String getTitle() { return title; }
    public String getCaption() { return caption; }
    public UUID getAssetId() { return assetId; }
    public String getExternalUrl() { return externalUrl; }
    public String getVisibility() { return visibility; }
    public int getSortOrder() { return sortOrder; }
    public Instant getCreatedAt() { return createdAt; }
}
