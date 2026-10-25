package com.dauviet.collection.domain;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.CreationTimestamp;

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

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * Mutable tren DRAFT (service guard status==DRAFT truoc khi set).
     * GAME-06 override: giu policyId on dinh khi admin sua draft —
     * khong delete/reinsert row.
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "required_lesson_ids", nullable = false,
            columnDefinition = "jsonb")
    private String requiredLessonIdsJson = "[]";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "optional_lesson_ids", nullable = false,
            columnDefinition = "jsonb")
    private String optionalLessonIdsJson = "[]";

    /** SMALLINT trong DB — entity map Short (Hibernate validate type). */
    @Column(name = "mastery_threshold")
    private Short masteryThreshold;

    @Column(name = "published_at")
    private Instant publishedAt;

    public EventCompletionPolicy() {
    }

    /**
     * Tạo DRAFT mới (copy-on-write): admin không PATCH row DRAFT cũ mà
     * insert row DRAFT mới cùng `policyVersion` (khi sửa) hoặc version kế
     * tiếp (khi tạo mới trên PUBLISHED). Required/optional serialize sang
     * JSON array of UUID strings — giữ shape V22.
     */
    public static EventCompletionPolicy draft(UUID eventId, int policyVersion,
            List<UUID> requiredLessonIds, List<UUID> optionalLessonIds,
            Short masteryThreshold, ObjectMapper mapper) {
        EventCompletionPolicy p = new EventCompletionPolicy();
        p.id = UUID.randomUUID();
        p.eventId = eventId;
        p.policyVersion = policyVersion;
        p.status = Status.DRAFT;
        p.requiredLessonIdsJson = toJsonArray(requiredLessonIds, mapper);
        p.optionalLessonIdsJson = toJsonArray(optionalLessonIds, mapper);
        p.masteryThreshold = masteryThreshold;
        return p;
    }

    private static String toJsonArray(List<UUID> ids, ObjectMapper mapper) {
        try {
            return mapper.writeValueAsString(
                    ids == null ? List.of() : ids.stream()
                            .map(UUID::toString).toList());
        } catch (Exception e) {
            throw new IllegalStateException("cannot serialize lesson ids", e);
        }
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
    public Instant getCreatedAt() { return createdAt; }

    /* ---- mutable chỉ trên DRAFT (service guard) ---- */

    public void setStatus(Status status) { this.status = status; }
    public void setPublishedAt(Instant publishedAt) {
        this.publishedAt = publishedAt;
    }
    /** Chỉ gọi trên DRAFT — admin sửa ngưỡng trước publish. */
    public void setMasteryThreshold(Short masteryThreshold) {
        this.masteryThreshold = masteryThreshold;
    }

    /** Chỉ gọi trên DRAFT — sửa danh sách required giữ nguyên policyId. */
    public void setRequiredLessonIds(List<UUID> ids, ObjectMapper mapper) {
        this.requiredLessonIdsJson = toJsonArray(ids, mapper);
    }

    /** Chỉ gọi trên DRAFT — sửa danh sách optional giữ nguyên policyId. */
    public void setOptionalLessonIds(List<UUID> ids, ObjectMapper mapper) {
        this.optionalLessonIdsJson = toJsonArray(ids, mapper);
    }

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
