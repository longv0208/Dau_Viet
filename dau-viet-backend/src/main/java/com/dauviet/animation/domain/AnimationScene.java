package com.dauviet.animation.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * One animation scene draft bound to a template (and optionally a historical
 * event). draft_json holds the editable manifest; published immutable
 * manifests live in animation_scene_versions — current_version_id points at it.
 */
@Entity
@Table(name = "animation_scenes")
public class AnimationScene {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "template_id", nullable = false, updatable = false)
    private UUID templateId;

    /** Nullable: a scene may be shared across events. */
    @Column(name = "event_id")
    private UUID eventId;

    @Column(name = "title", nullable = false)
    private String title;

    /** Editable manifest draft. JSONB object, validated at publish. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "draft_json", nullable = false, columnDefinition = "jsonb")
    private String draftJson = "{}";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 24)
    private AnimationSceneStatus status = AnimationSceneStatus.DRAFT;

    @Column(name = "current_version_id")
    private UUID currentVersionId;

    @Column(name = "created_by", updatable = false)
    private UUID createdBy;

    @Column(name = "updated_by")
    private UUID updatedBy;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public AnimationScene() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTemplateId() { return templateId; }
    public void setTemplateId(UUID templateId) { this.templateId = templateId; }

    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDraftJson() { return draftJson; }
    public void setDraftJson(String draftJson) { this.draftJson = draftJson; }

    public AnimationSceneStatus getStatus() { return status; }
    public void setStatus(AnimationSceneStatus status) { this.status = status; }

    public UUID getCurrentVersionId() { return currentVersionId; }
    public void setCurrentVersionId(UUID currentVersionId) { this.currentVersionId = currentVersionId; }

    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }

    public UUID getUpdatedBy() { return updatedBy; }
    public void setUpdatedBy(UUID updatedBy) { this.updatedBy = updatedBy; }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getRowVersion() { return rowVersion; }
}
