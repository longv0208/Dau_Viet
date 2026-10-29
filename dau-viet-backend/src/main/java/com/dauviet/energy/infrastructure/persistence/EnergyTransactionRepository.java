package com.dauviet.energy.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.energy.domain.EnergyTransaction;

/**
 * Ledger energy_transactions (V21) — ghi DUY NHẤT qua {@link #insertIgnore}:
 * cause_key UNIQUE là backstop tầng DB chặn ghi trùng dù retry/concurrent.
 * Không UPDATE/DELETE — ledger append-only.
 */
public interface EnergyTransactionRepository
        extends JpaRepository<EnergyTransaction, UUID> {

    /**
     * Ghi một bút toán energy; cause_key đã tồn tại → bỏ qua.
     * @return số row insert thực tế (0 = đã ghi trước đó)
     */
    @Modifying
    @Query(value = """
            INSERT INTO energy_transactions
                (id, user_id, direction, amount, reason, cause_key,
                 balance_after, reference_json, created_at)
            VALUES (gen_random_uuid(), :userId, :direction, :amount, :reason,
                    :causeKey, :balanceAfter, CAST(:referenceJson AS jsonb),
                    now())
            ON CONFLICT (cause_key) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("direction") String direction,
                     @Param("amount") int amount,
                     @Param("reason") String reason,
                     @Param("causeKey") String causeKey,
                     @Param("balanceAfter") int balanceAfter,
                     @Param("referenceJson") String referenceJson);

    /**
     * FIX 1: đọc lại bút toán đã commit của một cause_key — dùng khi
     * insertIgnore trả 0 để biết balance_after + thời điểm của bản ghi gốc
     * (phục vụ reconcile balance mà không double-apply).
     */
    @Query(value = """
            SELECT balance_after, created_at
            FROM energy_transactions
            WHERE user_id = :userId AND cause_key = :causeKey
            """, nativeQuery = true)
    StoredCauseProjection findStoredProjection(@Param("userId") UUID userId,
                                               @Param("causeKey") String causeKey);

    /** Projection interface — Spring Data map balance_after/created_at. */
    interface StoredCauseProjection {
        Integer getBalanceAfter();
        java.time.Instant getCreatedAt();
    }

    /** Value object service dùng (không lộ JPA projection ra ngoài). */
    record StoredCause(int balanceAfter, java.time.Instant createdAt) { }

    /** Convenience: projection → value object, null-safe. */
    default StoredCause findStoredByCauseKey(UUID userId, String causeKey) {
        StoredCauseProjection p = findStoredProjection(userId, causeKey);
        return p == null || p.getBalanceAfter() == null
                ? null
                : new StoredCause(p.getBalanceAfter(), p.getCreatedAt());
    }
    /**
     * GAME-07: lần dùng gần nhất theo từng remedyCode — phục vụ kiểm
     * cooldown per-remedy trong GET /me/energy và POST /me/energy/refills.
     * Chỉ đọc reason='REFILL_PURCHASE'; NATURAL_RECOVERY/GRADED_INCORRECT
     * không ảnh hưởng cooldown. `since` lọc tới cửa sổ cooldown tối đa
     * (86400s) — tránh quét toàn bộ ledger khi user dùng lâu.
     */
    @Query(value = """
            SELECT reference_json->>'remedyCode' AS remedy_code,
                   MAX(created_at) AS last_used_at
            FROM energy_transactions
            WHERE user_id = :userId
              AND reason = 'REFILL_PURCHASE'
              AND created_at >= :since
            GROUP BY reference_json->>'remedyCode'
            """, nativeQuery = true)
    List<RemedyUsageProjection> findRecentRemedyUsages(
            @Param("userId") UUID userId,
            @Param("since") java.time.Instant since);

    /** Projection interface — Spring Data map alias snake_case → camelCase. */
    interface RemedyUsageProjection {
        String getRemedyCode();
        java.time.Instant getLastUsedAt();
    }
}
