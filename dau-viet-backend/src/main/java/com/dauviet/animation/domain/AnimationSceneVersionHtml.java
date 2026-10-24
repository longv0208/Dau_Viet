package com.dauviet.animation.domain;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Lob;

/**
 * Immutable published HTML bytes for an HTML_WEBVIEW scene version (1:1 with
 * animation_scene_versions). INSERT-only — trg_animation_scene_version_html_immutable
 * (V19) rejects UPDATE/DELETE, mirroring animation_scene_versions.
 */
@Entity
@Table(name = "animation_scene_version_html")
public class AnimationSceneVersionHtml {

    @Id
    @Column(name = "version_id", nullable = false, updatable = false)
    private UUID versionId;

    @Lob
    @Column(name = "content", nullable = false, updatable = false)
    private String content;

    @Column(name = "sha256", nullable = false, length = 64, updatable = false)
    private String sha256;

    @Column(name = "size_bytes", nullable = false, updatable = false)
    private Long sizeBytes;

    @Column(name = "original_filename", updatable = false)
    private String originalFilename;

    public AnimationSceneVersionHtml() {
    }

    public AnimationSceneVersionHtml(UUID versionId, String content, String sha256,
                                     Long sizeBytes, String originalFilename) {
        this.versionId = versionId;
        this.content = content;
        this.sha256 = sha256;
        this.sizeBytes = sizeBytes;
        this.originalFilename = originalFilename;
    }

    public UUID getVersionId() { return versionId; }
    public String getContent() { return content; }
    public String getSha256() { return sha256; }
    public Long getSizeBytes() { return sizeBytes; }
    public String getOriginalFilename() { return originalFilename; }
}
