package com.dauviet.energy.domain;

import java.time.Instant;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ledger Thể lực (V21) — append-only, insert qua ON CONFLICT (cause_key)
 * DO NOTHING nên entity chủ yếu phục vụ đọc/audit. `balance_after` là trạng
 * thái SAU bút toán; `reference_json` truy vết penalty về
 * attempt/activity/attemptNo — không lộ đáp án.
 */
@Entity
@Table(name = "energy_transactions")
public class EnergyTransaction {

    public static final String DIR_CREDIT = "CREDIT";
    public static final String DIR_DEBIT = "DEBIT";

    public static final String REASON_GRADED_INCORRECT = "GRADED_INCORRECT";
    public static final String REASON_NATURAL_RECOVERY = "NATURAL_RECOVERY";
    public static final String REASON_REFILL_PURCHASE = "REFILL_PURCHASE";
    public static final String REASON_ADMIN_ADJUST = "ADMIN_ADJUST";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "direction", nullable = false, updatable = false, length = 8)
    private String direction;

    @Column(name = "amount", nullable = false, updatable = false)
    private int amount;

    @Column(name = "reason", nullable = false, updatable = false, length = 40)
    private String reason;

    @Column(name = "cause_key", nullable = false, updatable = false, length = 200)
    private String causeKey;

    @Column(name = "balance_after", nullable = false, updatable = false)
    private int balanceAfter;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "reference_json", columnDefinition = "jsonb")
    private String referenceJson;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public EnergyTransaction() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public String getDirection() { return direction; }
    public int getAmount() { return amount; }
    public String getReason() { return reason; }
    public String getCauseKey() { return causeKey; }
    public int getBalanceAfter() { return balanceAfter; }
    public String getReferenceJson() { return referenceJson; }
    public Instant getCreatedAt() { return createdAt; }
}
