package com.dauviet.path.domain;

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
@Table(name = "user_path_period_state")
public class UserPathPeriodState {

    @Embeddable
    public static class Key implements Serializable {
        @Column(name = "user_id", nullable = false)
        private UUID userId;

        @Column(name = "path_code", nullable = false, length = 64)
        private String pathCode;

        @Column(name = "period_chapter_id", nullable = false)
        private UUID periodChapterId;

        protected Key() {
        }

        public Key(UUID userId, String pathCode, UUID periodChapterId) {
            this.userId = userId;
            this.pathCode = pathCode;
            this.periodChapterId = periodChapterId;
        }

        public UUID getUserId() {
            return userId;
        }

        public String getPathCode() {
            return pathCode;
        }

        public UUID getPeriodChapterId() {
            return periodChapterId;
        }

        @Override
        public boolean equals(Object o) {
            return o instanceof Key that
                    && Objects.equals(userId, that.userId)
                    && Objects.equals(pathCode, that.pathCode)
                    && Objects.equals(periodChapterId, that.periodChapterId);
        }

        @Override
        public int hashCode() {
            return Objects.hash(userId, pathCode, periodChapterId);
        }
    }

    @EmbeddedId
    private Key id;

    @Column(name = "last_touched_at", nullable = false)
    private Instant lastTouchedAt;

    protected UserPathPeriodState() {
    }

    public UserPathPeriodState(UUID userId, String pathCode, UUID periodChapterId, Instant lastTouchedAt) {
        this.id = new Key(userId, pathCode, periodChapterId);
        this.lastTouchedAt = lastTouchedAt == null ? Instant.now() : lastTouchedAt;
    }

    public Key getId() {
        return id;
    }

    public Instant getLastTouchedAt() {
        return lastTouchedAt;
    }

    public void setLastTouchedAt(Instant lastTouchedAt) {
        this.lastTouchedAt = lastTouchedAt;
    }
}
