package com.dauviet.animation.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Immutable published manifest snapshot for one scene. Rows are INSERT-only —
-- a DB trigger (trg_animation_scene_versions_immutable, V14) rejects
 * UPDATE/DELETE, mirroring lesson_versions.
 */
@Entity
@Table(name = "animation_scene_versions")
public class AnimationSceneVersion {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "scene_id", nullable = false, updatable = false)
    private UUID sceneId;

    @Column(name = "version_no", nullable = false, updatable = false)
    private Integer versionNo;

    @Column(name = "schema_version", nullable = false, updatable = false)
    private Integer schemaVersion;

    @Column(name = "renderer_code", nullable = false, length = 48, updatable = false)
    private String rendererCode;

    @Column(name = "renderer_version", nullable = false, updatable = false)
    private Integer rendererVersion;

    /** Full validated manifest + embedded asset metadata. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "snapshot_json", nullable = false, columnDefinition = "jsonb", updatable = false)
    private String snapshotJson;

    /** SHA-256 of the canonical manifest JSON — tamper/drift detection. */
    @Column(name = "manifest_checksum", nullable = false, length = 64, updatable = false)
    private String manifestChecksum;

    @Column(name = "published_at", nullable = false, updatable = false)
    private Instant publishedAt;

    @Column(name = "published_by", nullable = false, updatable = false)
    private UUID publishedBy;

    public AnimationSceneVersion() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getSceneId() { return sceneId; }
    public void setSceneId(UUID sceneId) { this.sceneId = sceneId; }

    public Integer getVersionNo() { return versionNo; }
    public void setVersionNo(Integer versionNo) { this.versionNo = versionNo; }

    public Integer getSchemaVersion() { return schemaVersion; }
    public void setSchemaVersion(Integer schemaVersion) { this.schemaVersion = schemaVersion; }

    public String getRendererCode() { return rendererCode; }
    public void setRendererCode(String rendererCode) { this.rendererCode = rendererCode; }

    public Integer getRendererVersion() { return rendererVersion; }
    public void setRendererVersion(Integer rendererVersion) { this.rendererVersion = rendererVersion; }

    public String getSnapshotJson() { return snapshotJson; }
    public void setSnapshotJson(String snapshotJson) { this.snapshotJson = snapshotJson; }

    public String getManifestChecksum() { return manifestChecksum; }
    public void setManifestChecksum(String manifestChecksum) { this.manifestChecksum = manifestChecksum; }

    public Instant getPublishedAt() { return publishedAt; }
    public void setPublishedAt(Instant publishedAt) { this.publishedAt = publishedAt; }

    public UUID getPublishedBy() { return publishedBy; }
    public void setPublishedBy(UUID publishedBy) { this.publishedBy = publishedBy; }
}
