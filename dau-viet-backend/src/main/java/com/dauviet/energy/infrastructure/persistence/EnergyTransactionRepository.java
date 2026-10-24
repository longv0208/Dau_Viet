package com.dauviet.energy.infrastructure.persistence;

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
}
