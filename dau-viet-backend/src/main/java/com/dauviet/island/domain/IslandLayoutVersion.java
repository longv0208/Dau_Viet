package com.dauviet.island.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Phiên bản của một layout definition (V44). Một thời điểm chỉ có một
 * version PUBLISHED cho mỗi definition. Version PUBLISHED/ARCHIVED là immutable.
 */
@Entity
@Table(name = "island_layout_versions")
public class IslandLayoutVersion {

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

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "archived_at")
    private Instant archivedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public IslandLayoutVersion() {
    }

    public static IslandLayoutVersion createDraft(UUID id, UUID definitionId,
                                                  int versionNumber, Instant now) {
        IslandLayoutVersion v = new IslandLayoutVersion();
        v.id = id;
        v.definitionId = definitionId;
        v.versionNumber = versionNumber;
        v.status = Status.DRAFT.name();
        v.createdAt = now;
        v.updatedAt = now;
        return v;
    }

    public void touch(Instant now) {
        this.updatedAt = now;
    }

    public void publish(Instant now) {
        this.status = Status.PUBLISHED.name();
        this.publishedAt = now;
        this.updatedAt = now;
    }

    public void archive(Instant now) {
        this.status = Status.ARCHIVED.name();
        this.archivedAt = now;
        this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public UUID getDefinitionId() { return definitionId; }
    public int getVersionNumber() { return versionNumber; }
    public String getStatus() { return status; }
    public Status getStatusEnum() { return Status.valueOf(status); }
    public boolean isDraft() { return Status.DRAFT.name().equals(status); }
    public boolean isPublished() { return Status.PUBLISHED.name().equals(status); }
    public boolean isArchived() { return Status.ARCHIVED.name().equals(status); }
    public Long getRowVersion() { return rowVersion; }
    public Instant getPublishedAt() { return publishedAt; }
    public Instant getArchivedAt() { return archivedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
