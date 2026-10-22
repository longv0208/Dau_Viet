package com.dauviet.collection.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Một mục trong Bộ sưu tập của learner — evidence do backend ghi sau khi
 * chấp nhận submission (TASK-0022). `snapshotJson` giữ bản evidence nhúng
 * trong pinned lesson_version tại thời điểm collect: admin sửa/lưu trữ
 * evidence gốc không đổi được nội dung learner đã sưu tầm.
 * Append-only: mỗi (user_id, evidence_id) tối đa một row — upsert
 * ON CONFLICT DO NOTHING, collected_at lưu lần collect đầu tiên.
 */
@Entity
@Table(name = "user_evidence")
public class UserEvidence {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "learner_attempt_id", nullable = false, updatable = false)
    private UUID learnerAttemptId;

    @Column(name = "evidence_id", nullable = false, updatable = false)
    private UUID evidenceId;

    @Column(name = "evidence_type", updatable = false)
    private String evidenceType;

    /** Event chứa lesson tại thời điểm collect — cột riêng để filter nhanh. */
    @Column(name = "event_id", updatable = false)
    private UUID eventId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "snapshot_json", updatable = false, columnDefinition = "jsonb")
    private String snapshotJson;

    @Column(name = "collected_at", nullable = false, updatable = false)
    private Instant collectedAt;

    public UserEvidence() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public UUID getEvidenceId() { return evidenceId; }
    public String getEvidenceType() { return evidenceType; }
    public UUID getEventId() { return eventId; }
    public String getSnapshotJson() { return snapshotJson; }
    public Instant getCollectedAt() { return collectedAt; }
}
