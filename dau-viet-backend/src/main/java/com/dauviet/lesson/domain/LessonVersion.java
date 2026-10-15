package com.dauviet.lesson.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Immutable published snapshot of a lesson. The DB trigger
 * trg_lesson_versions_immutable forbids UPDATE/DELETE; this entity is
 * read+insert only and deliberately exposes no mutators beyond construction.
 */
@Entity
@Table(name = "lesson_versions")
public class LessonVersion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "lesson_id", nullable = false, updatable = false)
    private UUID lessonId;

    @Column(name = "version_no", nullable = false, updatable = false)
    private Integer versionNo;

    @Column(name = "schema_version", nullable = false, updatable = false)
    private Integer schemaVersion;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "snapshot_json", nullable = false, updatable = false, columnDefinition = "jsonb")
    private String snapshotJson;

    @Column(name = "published_at", nullable = false, updatable = false)
    private Instant publishedAt;

    @Column(name = "published_by", nullable = false, updatable = false)
    private UUID publishedBy;

    public LessonVersion() {
    }

    public UUID getId() { return id; }
    public UUID getLessonId() { return lessonId; }
    public Integer getVersionNo() { return versionNo; }
    public Integer getSchemaVersion() { return schemaVersion; }
    public String getSnapshotJson() { return snapshotJson; }
    public Instant getPublishedAt() { return publishedAt; }
    public UUID getPublishedBy() { return publishedBy; }

    // Insert-time mutators only: every column is updatable=false and the DB
    // trigger forbids UPDATE, so these can never change a persisted row.
    public void setId(UUID id) { this.id = id; }
    public void setLessonId(UUID lessonId) { this.lessonId = lessonId; }
    public void setVersionNo(Integer versionNo) { this.versionNo = versionNo; }
    public void setSchemaVersion(Integer schemaVersion) { this.schemaVersion = schemaVersion; }
    public void setSnapshotJson(String snapshotJson) { this.snapshotJson = snapshotJson; }
    public void setPublishedAt(Instant publishedAt) { this.publishedAt = publishedAt; }
    public void setPublishedBy(UUID publishedBy) { this.publishedBy = publishedBy; }
}
