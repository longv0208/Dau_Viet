package com.dauviet.animation.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * A reusable animation template bound to one rendererCode (RIVER_TIDE,
 * JOURNEY_MAP, ...). capabilities_json declares what the template supports;
 * default_config_json seeds new scene drafts.
 */
@Entity
@Table(name = "animation_templates")
public class AnimationTemplate {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "code", nullable = false, length = 64)
    private String code;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "renderer_code", nullable = false, length = 48)
    private String rendererCode;

    @Column(name = "renderer_version", nullable = false)
    private Integer rendererVersion = 1;

    @Column(name = "schema_version", nullable = false)
    private Integer schemaVersion = 1;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "capabilities_json", nullable = false, columnDefinition = "jsonb")
    private String capabilitiesJson = "{}";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "default_config_json", nullable = false, columnDefinition = "jsonb")
    private String defaultConfigJson = "{}";

    @Column(name = "thumbnail_asset_id")
    private UUID thumbnailAssetId;

    @Column(name = "enabled", nullable = false)
    private Boolean enabled = Boolean.TRUE;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public AnimationTemplate() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getRendererCode() { return rendererCode; }
    public void setRendererCode(String rendererCode) { this.rendererCode = rendererCode; }

    public Integer getRendererVersion() { return rendererVersion; }
    public void setRendererVersion(Integer rendererVersion) { this.rendererVersion = rendererVersion; }

    public Integer getSchemaVersion() { return schemaVersion; }
    public void setSchemaVersion(Integer schemaVersion) { this.schemaVersion = schemaVersion; }

    public String getCapabilitiesJson() { return capabilitiesJson; }
    public void setCapabilitiesJson(String capabilitiesJson) { this.capabilitiesJson = capabilitiesJson; }

    public String getDefaultConfigJson() { return defaultConfigJson; }
    public void setDefaultConfigJson(String defaultConfigJson) { this.defaultConfigJson = defaultConfigJson; }

    public UUID getThumbnailAssetId() { return thumbnailAssetId; }
    public void setThumbnailAssetId(UUID thumbnailAssetId) { this.thumbnailAssetId = thumbnailAssetId; }

    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
