package com.dauviet.learning.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * One learner's run through a pinned lesson_versions snapshot.
 * row_version is the optimistic-lock guard; concurrent submits also
 * serialize on the pessimistic lock in LearnerAttemptRepository.findForUpdate.
 */
@Entity
@Table(name = "learner_attempts")
public class LearnerAttempt {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "lesson_version_id", nullable = false, updatable = false)
    private UUID lessonVersionId;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private LearnerAttemptStatus status = LearnerAttemptStatus.IN_PROGRESS;

    @Column(name = "current_stage_id")
    private String currentStageId;

    @Column(name = "current_activity_id")
    private String currentActivityId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "state_json", nullable = false, columnDefinition = "jsonb")
    private String stateJson = "{}";

    @Column(name = "started_at", nullable = false, updatable = false)
    private Instant startedAt;

    @Column(name = "last_active_at", nullable = false)
    private Instant lastActiveAt;

    @Column(name = "completed_at")
    private Instant completedAt;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    public LearnerAttempt() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public UUID getLessonVersionId() { return lessonVersionId; }
    public LearnerAttemptStatus getStatus() { return status; }
    public String getCurrentStageId() { return currentStageId; }
    public String getCurrentActivityId() { return currentActivityId; }
    public String getStateJson() { return stateJson; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getLastActiveAt() { return lastActiveAt; }
    public Instant getCompletedAt() { return completedAt; }

    public static LearnerAttempt start(UUID userId, UUID lessonVersionId) {
        LearnerAttempt a = new LearnerAttempt();
        a.id = UUID.randomUUID();
        a.userId = userId;
        a.lessonVersionId = lessonVersionId;
        a.status = LearnerAttemptStatus.IN_PROGRESS;
        a.startedAt = Instant.now();
        a.lastActiveAt = a.startedAt;
        return a;
    }

    /** Persist the cursor + state after a submit. */
    public void recordProgress(AttemptState state) {
        this.stateJson = state.toJson().toString();
        this.currentStageId = state.currentStageId();
        this.currentActivityId = state.currentActivityId();
        this.lastActiveAt = Instant.now();
    }

    /** TASK-0012 will drive the real completion transition. */
    public void markCompleted() {
        this.status = LearnerAttemptStatus.COMPLETED;
        this.completedAt = Instant.now();
        this.lastActiveAt = this.completedAt;
    }

    public void markAbandoned() {
        this.status = LearnerAttemptStatus.ABANDONED;
        this.lastActiveAt = Instant.now();
    }
}
