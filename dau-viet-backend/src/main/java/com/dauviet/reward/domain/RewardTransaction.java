package com.dauviet.reward.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Bút toán thưởng của learner — ledger authoritative (V4). `causeKey`
 * UNIQUE chặn grant lặp: cùng (user, lesson, type) chỉ ghi một lần dù
 * complete() bị retry/concurrent/backfill. Insert qua ON CONFLICT DO
 * NOTHING nên entity này chủ yếu phục vụ đọc.
 */
@Entity
@Table(name = "reward_transactions")
public class RewardTransaction {

    public static final String TYPE_EXP = "EXP";
    public static final String TYPE_HISTORY_POINTS = "HISTORY_POINTS";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "learner_attempt_id", updatable = false)
    private UUID learnerAttemptId;

    @Column(name = "reward_type", nullable = false, updatable = false)
    private String rewardType;

    @Column(name = "amount", nullable = false, updatable = false)
    private Long amount;

    @Column(name = "reason", nullable = false, updatable = false)
    private String reason;

    @Column(name = "cause_key", nullable = false, updatable = false)
    private String causeKey;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public RewardTransaction() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public UUID getLearnerAttemptId() { return learnerAttemptId; }
    public String getRewardType() { return rewardType; }
    public Long getAmount() { return amount; }
    public String getReason() { return reason; }
    public String getCauseKey() { return causeKey; }
    public Instant getCreatedAt() { return createdAt; }
}
