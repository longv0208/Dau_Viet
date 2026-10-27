package com.dauviet.wallet.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.wallet.domain.WalletTransaction;

/**
 * Ledger wallet_transactions (V32) — ghi DUY NHẤT qua {@link #insertIgnore}:
 * cause_key UNIQUE là backstop tầng DB chặn double-credit/debit dù retry/
 * concurrent. Không UPDATE/DELETE — append-only.
 */
public interface WalletTransactionRepository
        extends JpaRepository<WalletTransaction, UUID> {

    /**
     * Ghi một bút toán; cause_key đã tồn tại → bỏ qua.
     * @return số row insert thực tế (0 = cause đã commit trước)
     */
    @Modifying
    @Query(value = """
            INSERT INTO wallet_transactions
                (id, user_id, currency, direction, amount, reason, cause_key,
                 source_ref, balance_after, created_at)
            VALUES (gen_random_uuid(), :userId, 'HISTORY_POINTS', :direction,
                    :amount, :reason, :causeKey, :sourceRef, :balanceAfter,
                    now())
            ON CONFLICT (cause_key) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("direction") String direction,
                     @Param("amount") long amount,
                     @Param("reason") String reason,
                     @Param("causeKey") String causeKey,
                     @Param("sourceRef") String sourceRef,
                     @Param("balanceAfter") long balanceAfter);

    /**
     * Bridge credit: mirror mọi reward_transactions HISTORY_POINTS của user
     * sang wallet_transactions, cause_key='BRIDGE:'||rt.id — idempotent.
     * balance_after = cumulative sum theo created_at để audit đúng; khi
     * re-bridge chạy lại, các row đã có sẽ ON CONFLICT skip — chỉ credit
     * mới hơn mới được chèn, và cumulative đúng nhờ subquery tính lại.
     * @return số row bridge thực sự insert (0 = user chưa có credit cũ)
     */
    @Modifying
    @Query(value = """
            INSERT INTO wallet_transactions
                (id, user_id, currency, direction, amount, reason, cause_key,
                 source_ref, balance_after, created_at)
            SELECT gen_random_uuid(), rt.user_id, 'HISTORY_POINTS', 'CREDIT',
                   rt.amount, 'BRIDGE', 'BRIDGE:' || rt.id::text,
                   rt.id::text,
                   cumulative.running_total,
                   rt.created_at
            FROM reward_transactions rt
            JOIN (
                SELECT id,
                       SUM(amount) OVER (ORDER BY created_at, id) AS running_total
                FROM reward_transactions
                WHERE user_id = :userId AND reward_type = 'HISTORY_POINTS'
            ) cumulative ON cumulative.id = rt.id
            WHERE rt.user_id = :userId
              AND rt.reward_type = 'HISTORY_POINTS'
            ON CONFLICT (cause_key) DO NOTHING
            """, nativeQuery = true)
    int bridgeFromRewardTransactions(@Param("userId") UUID userId);

    /** Đọc lại bút toán của cause_key — reconcile khi insertIgnore trả 0. */
    @Query(value = """
            SELECT balance_after, created_at
            FROM wallet_transactions
            WHERE user_id = :userId AND cause_key = :causeKey
            """, nativeQuery = true)
    StoredCauseProjection findStoredProjection(@Param("userId") UUID userId,
                                               @Param("causeKey") String causeKey);

    /** Lịch sử giao dịch — mới nhất trước. */
    List<WalletTransaction> findByUserIdOrderByCreatedAtDesc(UUID userId,
                                                            Pageable pageable);

    /** Tổng CREDIT của user (earned) — dùng cho wallet summary. */
    @Query(value = """
            SELECT COALESCE(SUM(amount), 0) FROM wallet_transactions
            WHERE user_id = :userId AND direction = 'CREDIT'
            """, nativeQuery = true)
    long sumCredits(@Param("userId") UUID userId);

    /** Tổng DEBIT của user (spent). */
    @Query(value = """
            SELECT COALESCE(SUM(amount), 0) FROM wallet_transactions
            WHERE user_id = :userId AND direction = 'DEBIT'
            """, nativeQuery = true)
    long sumDebits(@Param("userId") UUID userId);

    interface StoredCauseProjection {
        Long getBalanceAfter();
        java.time.Instant getCreatedAt();
    }

    record StoredCause(long balanceAfter, java.time.Instant createdAt) { }

    default StoredCause findStoredByCauseKey(UUID userId, String causeKey) {
        StoredCauseProjection p = findStoredProjection(userId, causeKey);
        return p == null || p.getBalanceAfter() == null
                ? null
                : new StoredCause(p.getBalanceAfter(), p.getCreatedAt());
    }
}
