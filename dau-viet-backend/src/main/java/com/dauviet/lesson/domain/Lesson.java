package com.dauviet.lesson.domain;

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
 * A lesson draft bound to one historical event and one template.
 * `draftJson`/`objectivesJson` are JSONB; the published snapshot lives in
 * lesson_versions (immutable) — lessons.current_version_id points at it.
 */
@Entity
@Table(name = "lessons")
public class Lesson {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Column(name = "template_id", nullable = false)
    private UUID templateId;

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "central_question", nullable = false, columnDefinition = "text")
    private String centralQuestion;

    /** JSON array of learning objectives. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "objectives_json", nullable = false, columnDefinition = "jsonb")
    private String objectivesJson = "[]";

    /** Structured draft content (stages/activities). JSONB object. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "draft_json", nullable = false, columnDefinition = "jsonb")
    private String draftJson = "{}";

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 24)
    private LessonStatus status = LessonStatus.DRAFT;

    /** Current published lesson_versions.id — nullable until first publish. */
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

    public Lesson() {
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }

    public UUID getTemplateId() { return templateId; }
    public void setTemplateId(UUID templateId) { this.templateId = templateId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getCentralQuestion() { return centralQuestion; }
    public void setCentralQuestion(String centralQuestion) { this.centralQuestion = centralQuestion; }

    public String getObjectivesJson() { return objectivesJson; }
    public void setObjectivesJson(String objectivesJson) { this.objectivesJson = objectivesJson; }

    public String getDraftJson() { return draftJson; }
    public void setDraftJson(String draftJson) { this.draftJson = draftJson; }

    public LessonStatus getStatus() { return status; }
    public void setStatus(LessonStatus status) { this.status = status; }

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
