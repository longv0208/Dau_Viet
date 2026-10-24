package com.dauviet.collection.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * Ledger append-only: một row mỗi (user, event, milestone) — EVT-04/EVT-06.
 * `requiredSnapshot` lưu lesson set tại thời điểm ghi để audit khi admin đổi
 * policy; entitlement không bao giờ bị thu hồi (EVT-05). Ghi duy nhất qua
 * repository native insert ON CONFLICT DO NOTHING — idempotent tuyệt đối.
 */
@Entity
@Table(name = "user_event_progress")
@IdClass(UserEventProgress.PK.class)
public class UserEventProgress {

    public enum Milestone { EVENT_COMPLETED, EVENT_MASTERED }

    /** Composite PK (user_id, event_id, milestone). */
    public static class PK implements Serializable {
        private UUID userId;
        private UUID eventId;
        private String milestone;

        public PK() {
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof PK other)) return false;
            return Objects.equals(userId, other.userId)
                    && Objects.equals(eventId, other.eventId)
                    && Objects.equals(milestone, other.milestone);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, eventId, milestone);
        }
    }

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "event_id", nullable = false, updatable = false)
    private UUID eventId;

    @Id
    @Column(name = "milestone", nullable = false, length = 24)
    private String milestone;

    @Column(name = "policy_version", nullable = false, updatable = false)
    private Integer policyVersion;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "required_snapshot", nullable = false,
            columnDefinition = "jsonb", updatable = false)
    private String requiredSnapshot;

    @Column(name = "granted_at", nullable = false, updatable = false)
    private Instant grantedAt;

    public UserEventProgress() {
    }

    public UUID getUserId() { return userId; }
    public UUID getEventId() { return eventId; }
    public String getMilestone() { return milestone; }
    public Integer getPolicyVersion() { return policyVersion; }
    public String getRequiredSnapshot() { return requiredSnapshot; }
    public Instant getGrantedAt() { return grantedAt; }
}
