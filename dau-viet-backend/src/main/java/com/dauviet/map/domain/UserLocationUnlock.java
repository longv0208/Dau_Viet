package com.dauviet.map.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "user_location_unlocks")
public class UserLocationUnlock {

    @Embeddable
    public static class Id implements Serializable {
        @Column(name = "user_id", nullable = false)
        private UUID userId;

        @Column(name = "location_id", nullable = false)
        private UUID locationId;

        protected Id() {}

        public Id(UUID userId, UUID locationId) {
            this.userId = userId;
            this.locationId = locationId;
        }

        public UUID getUserId() { return userId; }
        public UUID getLocationId() { return locationId; }

        @Override
        public boolean equals(Object o) {
            return o instanceof Id other
                    && Objects.equals(userId, other.userId)
                    && Objects.equals(locationId, other.locationId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, locationId);
        }
    }

    @EmbeddedId
    private Id id;

    @Column(name = "source_lesson_id")
    private UUID sourceLessonId;

    @Column(name = "source_attempt_id")
    private UUID sourceAttemptId;

    @Column(name = "unlocked_at", nullable = false)
    private Instant unlockedAt = Instant.now();

    protected UserLocationUnlock() {}

    public UserLocationUnlock(UUID userId, UUID locationId, UUID sourceLessonId, UUID sourceAttemptId) {
        this.id = new Id(userId, locationId);
        this.sourceLessonId = sourceLessonId;
        this.sourceAttemptId = sourceAttemptId;
        this.unlockedAt = Instant.now();
    }

    public Id getId() { return id; }
    public UUID getUserId() { return id.getUserId(); }
    public UUID getLocationId() { return id.getLocationId(); }
    public UUID getSourceLessonId() { return sourceLessonId; }
    public UUID getSourceAttemptId() { return sourceAttemptId; }
    public Instant getUnlockedAt() { return unlockedAt; }
}
