package com.dauviet.wallet.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ledger Điểm Sử Ký (V32, contract §2.3) — append-only, ghi duy nhất qua
 * WalletTransactionRepository.insertIgnore (cause_key UNIQUE là backstop).
 * amount luôn > 0, chiều ở direction — KHÔNG BAO GIỜ ghi số âm; balance_after
 * là snapshot ngay sau bút toán, phục vụ audit + reconcile (POINT-08/QA-19).
 * source_ref truy vết nguồn: reward_transactions.id cho BRIDGE credit,
 * purchase key cho SHOP_PURCHASE debit.
 */
@Entity
@Table(name = "wallet_transactions")
public class WalletTransaction {

    public static final String DIR_CREDIT = "CREDIT";
    public static final String DIR_DEBIT = "DEBIT";

    public static final String REASON_BRIDGE = "BRIDGE";
    public static final String REASON_SHOP_PURCHASE = "SHOP_PURCHASE";
    public static final String REASON_REFILL_PURCHASE = "REFILL_PURCHASE";
    public static final String REASON_ADMIN_ADJUST = "ADMIN_ADJUST";
    /** STREAK-02 (V51): đổi 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ Chuỗi. */
    public static final String REASON_STREAK_SHIELD_PURCHASE =
            "STREAK_SHIELD_PURCHASE";

    @Id
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Column(name = "currency", nullable = false, updatable = false, length = 32)
    private String currency;

    @Column(name = "direction", nullable = false, updatable = false, length = 8)
    private String direction;

    @Column(name = "amount", nullable = false, updatable = false)
    private long amount;

    @Column(name = "reason", nullable = false, updatable = false, length = 80)
    private String reason;

    @Column(name = "cause_key", nullable = false, updatable = false, length = 200)
    private String causeKey;

    @Column(name = "source_ref", updatable = false, length = 160)
    private String sourceRef;

    @Column(name = "balance_after", nullable = false, updatable = false)
    private long balanceAfter;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    public WalletTransaction() {
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public String getCurrency() { return currency; }
    public String getDirection() { return direction; }
    public long getAmount() { return amount; }
    public String getReason() { return reason; }
    public String getCauseKey() { return causeKey; }
    public String getSourceRef() { return sourceRef; }
    public long getBalanceAfter() { return balanceAfter; }
    public Instant getCreatedAt() { return createdAt; }
}
