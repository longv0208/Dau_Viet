package com.dauviet.animation.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

/**
 * Mutable draft HTML for an HTML_WEBVIEW scene (1:1 with animation_scenes).
 * Re-upload replaces the row; published copies live in
 * animation_scene_version_html and never change.
 */
@Entity
@Table(name = "animation_scene_html")
public class AnimationSceneHtml {

    @Id
    @Column(name = "scene_id", nullable = false, updatable = false)
    private UUID sceneId;

    /**
     * Self-contained UTF-8 HTML document (single file, inline assets).
     * LONGVARCHAR maps straight onto PostgreSQL TEXT — NOT @Lob, which
     * Hibernate 6 can resolve to LOB/OID and breaks ddl-auto=validate
     * against a TEXT column.
     */
    @JdbcTypeCode(SqlTypes.LONGVARCHAR)
    @Column(name = "content", nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(name = "sha256", nullable = false, length = 64)
    private String sha256;

    @Column(name = "size_bytes", nullable = false)
    private Long sizeBytes;

    @Column(name = "original_filename")
    private String originalFilename;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public AnimationSceneHtml() {
    }

    public AnimationSceneHtml(UUID sceneId, String content, String sha256,
                              Long sizeBytes, String originalFilename) {
        this.sceneId = sceneId;
        this.content = content;
        this.sha256 = sha256;
        this.sizeBytes = sizeBytes;
        this.originalFilename = originalFilename;
    }

    public UUID getSceneId() { return sceneId; }
    public void setSceneId(UUID sceneId) { this.sceneId = sceneId; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getSha256() { return sha256; }
    public void setSha256(String sha256) { this.sha256 = sha256; }

    public Long getSizeBytes() { return sizeBytes; }
    public void setSizeBytes(Long sizeBytes) { this.sizeBytes = sizeBytes; }

    public String getOriginalFilename() { return originalFilename; }
    public void setOriginalFilename(String name) { this.originalFilename = name; }

    public Instant getUpdatedAt() { return updatedAt; }
}
