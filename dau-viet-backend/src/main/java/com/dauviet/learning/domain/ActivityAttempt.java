package com.dauviet.learning.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Append-only record of one submission. attempt_no is monotonic per
 * (learner_attempt_id, activity_id); the DB UNIQUE constraint is the
 * backstop against duplicate submission races.
 */
@Entity
@Table(name = "activity_attempts")
public class ActivityAttempt {

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "learner_attempt_id", nullable = false, updatable = false)
    private UUID learnerAttemptId;

    @Column(name = "activity_id", nullable = false, updatable = false)
    private String activityId;

    @Column(name = "attempt_no", nullable = false, updatable = false)
    private Integer attemptNo;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "submitted_answer_json", nullable = false, updatable = false,
            columnDefinition = "jsonb")
    private String submittedAnswerJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "result_json", nullable = false, updatable = false,
            columnDefinition = "jsonb")
    private String resultJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public ActivityAttempt() {
    }

    public static ActivityAttempt of(UUID learnerAttemptId, String activityId,
                                     int attemptNo, String submittedAnswerJson,
                                     String resultJson) {
        ActivityAttempt a = new ActivityAttempt();
        a.id = UUID.randomUUID();
        a.learnerAttemptId = learnerAttemptId;
        a.activityId = activityId;
        a.attemptNo = attemptNo;
        a.submittedAnswerJson = submittedAnswerJson;
        a.resultJson = resultJson;
        a.createdAt = Instant.now();
        return a;
    }

    public UUID getId() { return id; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public String getActivityId() { return activityId; }
    public Integer getAttemptNo() { return attemptNo; }
    public String getSubmittedAnswerJson() { return submittedAnswerJson; }
    public String getResultJson() { return resultJson; }
    public Instant getCreatedAt() { return createdAt; }
}
