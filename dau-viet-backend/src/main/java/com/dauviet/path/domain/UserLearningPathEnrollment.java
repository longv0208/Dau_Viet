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
@Table(name = "user_learning_path_enrollments")
public class UserLearningPathEnrollment {
    @Embeddable
    public static class Key implements Serializable {
        @Column(name = "user_id") private UUID userId;
        @Column(name = "path_code") private String pathCode;
        protected Key() {}
        public Key(UUID userId, String pathCode) { this.userId = userId; this.pathCode = pathCode; }
        public UUID getUserId() { return userId; }
        public String getPathCode() { return pathCode; }
        @Override public boolean equals(Object other) {
            return other instanceof Key that && Objects.equals(userId, that.userId) && Objects.equals(pathCode, that.pathCode);
        }
        @Override public int hashCode() { return Objects.hash(userId, pathCode); }
    }
    @EmbeddedId private Key id;
    @Column(name = "path_version_id", nullable = false) private UUID pathVersionId;
    @Column(name = "enrolled_at", nullable = false, updatable = false) private Instant enrolledAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    protected UserLearningPathEnrollment() {}
    public UserLearningPathEnrollment(UUID userId, String pathCode, UUID pathVersionId) {
        this.id = new Key(userId, pathCode); this.pathVersionId = pathVersionId;
        this.enrolledAt = Instant.now(); this.updatedAt = this.enrolledAt;
    }
    public Key getId() { return id; }
    public UUID getPathVersionId() { return pathVersionId; }
    public void setPathVersionId(UUID pathVersionId) {
        this.pathVersionId = pathVersionId;
        this.updatedAt = Instant.now();
    }
}
