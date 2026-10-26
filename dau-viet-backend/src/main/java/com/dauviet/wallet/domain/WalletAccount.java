package com.dauviet.wallet.domain;

import java.time.Instant;
import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

/**
 * Số dư Điểm Sử Ký của một learner (V32, contract §2.3). PK composite
 * (user_id, currency); V1 chỉ HISTORY_POINTS — EXP không bao giờ vào đây
 * (không chi tiêu được). balance CHECK >= 0 là backstop tầng DB; đường
 * ghi chính serialize qua findForUpdate (PESSIMISTIC_WRITE) trong
 * WalletService — hai thiết bị mua cùng lúc không lost update (POINT-06).
 */
@Entity
@Table(name = "wallet_accounts")
@IdClass(WalletAccountId.class)
public class WalletAccount {

    public static final String CURRENCY_HISTORY_POINTS = "HISTORY_POINTS";

    @Id
    @Column(name = "user_id", nullable = false, updatable = false)
    private UUID userId;

    @Id
    @Column(name = "currency", nullable = false, updatable = false, length = 32)
    private String currency;

    @Column(name = "balance", nullable = false)
    private long balance;

    @Version
    @Column(name = "row_version", nullable = false)
    private Long rowVersion;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public WalletAccount() {
    }

    public static WalletAccount create(UUID userId, Instant now) {
        WalletAccount a = new WalletAccount();
        a.userId = userId;
        a.currency = CURRENCY_HISTORY_POINTS;
        a.balance = 0;
        a.createdAt = now;
        a.updatedAt = now;
        return a;
    }

    /** Caller đảm bảo amount <= balance (CHECK DB backstop). */
    public void debit(long amount, Instant now) {
        this.balance -= amount;
        this.updatedAt = now;
    }

    public void credit(long amount, Instant now) {
        this.balance += amount;
        this.updatedAt = now;
    }

    public UUID getUserId() { return userId; }
    public String getCurrency() { return currency; }
    public long getBalance() { return balance; }
    public Long getRowVersion() { return rowVersion; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}
