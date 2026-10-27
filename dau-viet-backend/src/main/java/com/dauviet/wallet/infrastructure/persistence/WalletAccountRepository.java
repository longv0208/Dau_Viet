package com.dauviet.wallet.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.wallet.domain.WalletAccount;
import com.dauviet.wallet.domain.WalletAccountId;

import jakarta.persistence.LockModeType;

/**
 * Truy cập wallet_accounts (V32). Lazy-create đi qua {@link #insertIgnore}
 * — PK (user_id,currency) + ON CONFLICT chặn duplicate khi hai request đầu
 * chạy đồng thời. Mọi đường ghi serialize trên {@link #findForUpdate}
 * (FOR UPDATE) — lock-order cố định: user_islands → wallet_accounts
 * → user_inventory (contract §5: wallet sau island lock, trước inventory).
 */
public interface WalletAccountRepository
        extends JpaRepository<WalletAccount, WalletAccountId> {

    /** Tạo account HISTORY_POINTS balance=0; đã có → 0. */
    @Modifying
    @Query(value = """
            INSERT INTO wallet_accounts (user_id, currency, balance,
                                         row_version, created_at, updated_at)
            VALUES (:userId, 'HISTORY_POINTS', 0, 0, :now, :now)
            ON CONFLICT (user_id, currency) DO NOTHING
            """, nativeQuery = true)
    int insertIgnore(@Param("userId") UUID userId,
                     @Param("now") java.time.Instant now);

    /** Pessimistic lock — bắt buộc cho mọi thao tác đọc-sửa-ghi balance. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM WalletAccount a WHERE a.userId = :userId "
         + "AND a.currency = 'HISTORY_POINTS'")
    Optional<WalletAccount> findForUpdate(@Param("userId") UUID userId);

    /** Đọc không lock — chỉ cho GET /me/wallet (không mutate). */
    Optional<WalletAccount> findByUserIdAndCurrency(UUID userId,
                                                    String currency);
}
