package com.dauviet.collection.domain;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import com.dauviet.lesson.domain.SnapshotCorruptException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Chính sách hoàn thành sự kiện theo version (GAME-04). PUBLISHED là
 * immutable — thay đổi = policy_version+1 (cũ ARCHIVED). `requiredLessonIds`
 * / `optionalLessonIds` là snapshot JSONB đóng băng tại publish; service đọc
 * thẳng từ bảng, không hard-code event nào.
 */
@Entity
@Table(name = "event_completion_policies")
public class EventCompletionPolicy {

    public enum Status { DRAFT, PUBLISHED, ARCHIVED }

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Column(name = "policy_version", nullable = false, updatable = false)
    private Integer policyVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 16)
    private Status status = Status.DRAFT;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "required_lesson_ids", nullable = false,
            columnDefinition = "jsonb", updatable = false)
    private String requiredLessonIdsJson = "[]";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "optional_lesson_ids", nullable = false,
            columnDefinition = "jsonb", updatable = false)
    private String optionalLessonIdsJson = "[]";

    /** SMALLINT trong DB — entity map Short (Hibernate validate type). */
    @Column(name = "mastery_threshold")
    private Short masteryThreshold;

    @Column(name = "published_at", updatable = false)
    private Instant publishedAt;

    public EventCompletionPolicy() {
    }

    public UUID getId() { return id; }
    public UUID getEventId() { return eventId; }
    public Integer getPolicyVersion() { return policyVersion; }
    public Status getStatus() { return status; }
    public String getRequiredLessonIdsJson() { return requiredLessonIdsJson; }
    public String getOptionalLessonIdsJson() { return optionalLessonIdsJson; }
    /** Threshold 0..100 hoặc null; trả Integer cho caller dễ dùng. */
    public Integer getMasteryThreshold() {
        return masteryThreshold == null ? null : Integer.valueOf(masteryThreshold);
    }
    public Instant getPublishedAt() { return publishedAt; }

    /** Parse danh sách lesson required (JSON array of UUID strings). */
    public List<UUID> requiredLessonIds(ObjectMapper mapper) {
        return parseUuidList(mapper, requiredLessonIdsJson, "required");
    }

    public List<UUID> optionalLessonIds(ObjectMapper mapper) {
        return parseUuidList(mapper, optionalLessonIdsJson, "optional");
    }

    private static List<UUID> parseUuidList(ObjectMapper mapper, String json,
                                            String field) {
        try {
            JsonNode arr = mapper.readTree(json == null ? "[]" : json);
            java.util.List<UUID> out = new java.util.ArrayList<>();
            for (JsonNode n : arr) {
                if (n.isTextual()) out.add(UUID.fromString(n.asText()));
            }
            return out;
        } catch (Exception e) {
            throw new SnapshotCorruptException("corrupt event policy "
                    + field + " list: " + e.getMessage());
        }
    }
}
