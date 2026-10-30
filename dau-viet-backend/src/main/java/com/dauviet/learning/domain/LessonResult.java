package com.dauviet.learning.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Immutable result of a completed learner attempt. Exactly one row per
 * attempt (learner_attempt_id UNIQUE) — the DB constraint is the backstop
 * against duplicate completion; the service checks first so a repeated
 * POST /complete returns the stored row instead of an error.
 */
@Entity
@Table(name = "lesson_results")
public class LessonResult {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "learner_attempt_id", nullable = false, updatable = false)
    private UUID learnerAttemptId;

    /**
     * Completion percentage (0-100, 2 decimals): required activities the
     * learner finished / total required. NOT an assessment score — a required
     * activity counts as completed even when its retries were exhausted on
     * incorrect answers (per the TASK-0011 exhausted-still-advances rule).
     */
    @Column(name = "score", nullable = false, updatable = false)
    private BigDecimal score;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "result_json", nullable = false,
            columnDefinition = "jsonb")
    private String resultJson;

    @Column(name = "completed_at", nullable = false, updatable = false)
    private Instant completedAt;

    public LessonResult() {
    }

    public static LessonResult of(UUID learnerAttemptId, BigDecimal score,
                                  String resultJson, Instant completedAt) {
        LessonResult r = new LessonResult();
        r.id = UUID.randomUUID();
        r.learnerAttemptId = learnerAttemptId;
        r.score = score;
        r.resultJson = resultJson;
        r.completedAt = completedAt;
        return r;
    }

    public UUID getId() { return id; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public BigDecimal getScore() { return score; }
    public String getResultJson() { return resultJson; }
    public Instant getCompletedAt() { return completedAt; }

    public void updateResultJson(String resultJson) {
        this.resultJson = resultJson;
    }
}
