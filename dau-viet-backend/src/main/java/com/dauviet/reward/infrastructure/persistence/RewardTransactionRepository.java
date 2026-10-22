package com.dauviet.reward.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.reward.domain.RewardTransaction;

/**
 * Ledger reward_transactions (V4). Ghi DUY NHẤT qua {@link #insertIgnore}
 * — ON CONFLICT (cause_key) DO NOTHING là backstop idempotent tầng DB cho
 * retry/concurrent/backfill; không bao giờ UPDATE/DELETE.
 */
public interface RewardTransactionRepository
        extends JpaRepository<RewardTransaction, UUID> {

    /**
     * Ghi một bút toán thưởng; cause_key đã tồn tại → bỏ qua.
     * @return số row insert thực tế (0 = đã grant trước đó)
     */
    @Modifying
    @Query(value = """
            INSERT INTO reward_transactions
                (id, user_id, learner_attempt_id, reward_type, amount,
                 reason, cause_key, created_at)
            VALUES (gen_random_uuid(), :userId, :attemptId, :rewardType,
                    :amount, :reason, :causeKey, now())
            ON CONFLICT (cause_key) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("attemptId") UUID attemptId,
                     @Param("rewardType") String rewardType,
                     @Param("amount") long amount,
                     @Param("reason") String reason,
                     @Param("causeKey") String causeKey);

    /** Lịch sử thưởng của learner — mới nhất trước. */
    Page<RewardTransaction> findByUserIdOrderByCreatedAtDesc(
            UUID userId, Pageable pageable);

    /** Tổng đã nhận của một loại thưởng (EXP / HISTORY_POINTS). */
    @Query("""
            SELECT COALESCE(SUM(t.amount), 0) FROM RewardTransaction t
            WHERE t.userId = :userId AND t.rewardType = :rewardType
            """)
    long sumAmount(@Param("userId") UUID userId,
                   @Param("rewardType") String rewardType);

    /** Bút toán gắn với một attempt — enrich GET /attempts/{id}/result. */
    List<RewardTransaction> findByLearnerAttemptId(UUID learnerAttemptId);
}
