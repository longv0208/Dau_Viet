package com.dauviet.path.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "learning_path_versions")
public class LearningPathVersion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "path_code", nullable = false, length = 64)
    private String pathCode;

    @Column(name = "version_no", nullable = false)
    private int versionNo;

    @Column(name = "title", nullable = false, length = 255)
    private String title;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 24)
    private LearningPathStatus status = LearningPathStatus.DRAFT;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    protected LearningPathVersion() {}

    public LearningPathVersion(UUID id, String pathCode, int versionNo, String title,
                               String description, LearningPathStatus status, Instant publishedAt) {
        this.id = id != null ? id : UUID.randomUUID();
        this.pathCode = pathCode;
        this.versionNo = versionNo;
        this.title = title;
        this.description = description;
        this.status = status != null ? status : LearningPathStatus.DRAFT;
        this.publishedAt = publishedAt;
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    public UUID getId() { return id; }
    public String getPathCode() { return pathCode; }
    public int getVersionNo() { return versionNo; }
    public String getTitle() { return title; }
    public String getDescription() { return description; }
    public LearningPathStatus getStatus() { return status; }
    public Instant getPublishedAt() { return publishedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void publish(Instant now) {
        this.status = LearningPathStatus.PUBLISHED;
        this.publishedAt = now;
        this.updatedAt = now;
    }

    public void archive(Instant now) {
        this.status = LearningPathStatus.ARCHIVED;
        this.updatedAt = now;
    }
}
