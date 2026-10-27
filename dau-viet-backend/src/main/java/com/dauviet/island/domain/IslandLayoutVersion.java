package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Phiên bản của một layout definition (V43). Một thời điểm chỉ có một
 * version PUBLISHED cho mỗi definition — partial unique index đảm bảo điều
 * này ở mức DB. Version PUBLISHED là immutable về slots, regions và layers.
 * Thay đổi layout → ARCHIVE version cũ, tạo version mới PUBLISHED.
 */
@Entity
@Table(name = "island_layout_versions")
public class IslandLayoutVersion {

    /** Trạng thái vòng đời của layout version. */
    public enum Status {
        DRAFT, PUBLISHED, ARCHIVED
    }

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "definition_id", nullable = false, updatable = false)
    private UUID definitionId;

    @Column(name = "version_number", nullable = false, updatable = false)
    private int versionNumber;

    @Column(name = "status", nullable = false)
    private String status;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "archived_at")
    private Instant archivedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public IslandLayoutVersion() {
    }

    public UUID getId() { return id; }
    public UUID getDefinitionId() { return definitionId; }
    public int getVersionNumber() { return versionNumber; }
    public String getStatus() { return status; }
    public Status getStatusEnum() { return Status.valueOf(status); }
    public boolean isPublished() { return Status.PUBLISHED.name().equals(status); }
    public Instant getPublishedAt() { return publishedAt; }
    public Instant getArchivedAt() { return archivedAt; }
    public Instant getCreatedAt() { return createdAt; }
}
