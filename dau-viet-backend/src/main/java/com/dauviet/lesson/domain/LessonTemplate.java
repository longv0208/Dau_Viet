package com.dauviet.lesson.domain;

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
 * Lesson template (admin authoring). preset_json describes the default
 * stages/activities skeleton applied when a lesson is created from it.
 */
@Entity
@Table(name = "lesson_templates")
public class LessonTemplate {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "code", nullable = false, unique = true, length = 64)
    private String code;

    @Column(name = "name", nullable = false, length = 150)
    private String name;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "schema_version", nullable = false)
    private Integer schemaVersion;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "preset_json", nullable = false, columnDefinition = "jsonb")
    private String presetJson;

    @Column(name = "enabled", nullable = false)
    private Boolean enabled;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public LessonTemplate() {
    }

    /** Factory for creating a new enabled template at the current schema version. */
    public static LessonTemplate create(UUID id, String code, String name, String description,
                                        int schemaVersion, String presetJson) {
        LessonTemplate t = new LessonTemplate();
        t.id = id;
        t.code = code;
        t.name = name;
        t.description = description;
        t.schemaVersion = schemaVersion;
        t.presetJson = presetJson;
        t.enabled = true;
        return t;
    }

    public void setName(String name) { this.name = name; }
    public void setDescription(String description) { this.description = description; }
    public void setPresetJson(String presetJson) { this.presetJson = presetJson; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }

    public UUID getId() { return id; }
    public String getCode() { return code; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public Integer getSchemaVersion() { return schemaVersion; }
    public String getPresetJson() { return presetJson; }
    public Boolean getEnabled() { return enabled; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
