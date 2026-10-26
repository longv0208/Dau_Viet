package com.dauviet.wallet.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.island.domain.IslandExceptions;
import com.dauviet.wallet.api.dto.WalletResponse;
import com.dauviet.wallet.api.dto.WalletTransactionResponse;
import com.dauviet.wallet.domain.WalletAccount;
import com.dauviet.wallet.domain.WalletTransaction;
import com.dauviet.wallet.infrastructure.persistence.WalletAccountRepository;
import com.dauviet.wallet.infrastructure.persistence.WalletTransactionRepository;

/**
 * Điểm Sử Ký server-authoritative (ISLAND-BE-01, contract §2.3/§6).
 *
 * <p>Lazy-create + lazy-bridge: account tạo lần đầu user chạm wallet; bridge
 * một lần mirror reward_transactions(HISTORY_POINTS) → wallet_transactions
 * với cause_key='BRIDGE:'||rt.id — idempotent nhờ UNIQUE cause_key; sau
 * bridge, balance = SUM(bridge credit) + các credit/debit V32 trở đi.
 *
 * <p>Debit: ledger-first (EnergyService FIX-1 pattern) — insertIgnore
 * wallet_transactions TRƯỚC khi trừ balance; cause trùng → reconcile từ
 * balance_after của row gốc rồi return, KHÔNG double-apply. Gọi TRONG
 * transaction của ShopService (REQUIRED) — rollback purchase → rollback
 * debit cùng.
 *
 * <p>Lock order: caller lock user_islands TRƯỚC (IslandService.placeItem),
 * rồi wallet_accounts qua findForUpdate, cuối cùng user_inventory qua
 * insertIgnore — một thứ tự duy nhất, không deadlock (contract §5).
 *
 * <p>Feature flag dauviet.wallet.enabled=false → mọi write ném
 * FeatureDisabledException (503 FEATURE_DISABLED); read vẫn hoạt động.
 */
@Service
public class WalletService {

    private static final Logger log = LoggerFactory.getLogger(WalletService.class);

    private final WalletAccountRepository accounts;
    private final WalletTransactionRepository ledger;
    private final Clock clock;
    private final boolean enabled;

    public WalletService(WalletAccountRepository accounts,
                         WalletTransactionRepository ledger,
                         Clock clock,
                         @Value("${dauviet.wallet.enabled:true}")
                         boolean enabled) {
        this.accounts = accounts;
        this.ledger = ledger;
        this.clock = clock;
        this.enabled = enabled;
    }

    /* ---------- read ---------- */

    /**
     * GET /me/wallet — lazy-create account nếu mới, lazy-bridge credit cũ,
     * trả balance/earned/spent + 20 giao dịch gần nhất.
     */
    @Transactional
    public WalletResponse walletOf(UUID userId) {
        ensureAccountAndBridge(userId);
        WalletAccount a = accounts.findByUserIdAndCurrency(userId,
                        WalletAccount.CURRENCY_HISTORY_POINTS)
                .orElseThrow(() -> new IllegalStateException(
                        "wallet missing after ensure for " + userId));
        long earned = ledger.sumCredits(userId);
        long spent = ledger.sumDebits(userId);
        List<WalletTransactionResponse> recent = ledger
                .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(0, 20))
                .stream().map(this::toResponse).toList();
        return new WalletResponse(a.getCurrency(), a.getBalance(), earned,
                spent, recent, Instant.now(clock));
    }

    /* ---------- write ---------- */

    /**
     * Debit Điểm Sử Ký cho một giao dịch mua (POINT-05/06/07). Ledger-first:
     * insertIgnore wallet_transactions trước, cause trùng → reconcile từ
     * balance_after gốc (idempotent, không double-debit). Caller đảm bảo
     * user có đủ balance sau check eligibility.
     *
     * @param userId     chủ ví (từ JWT)
     * @param amount     số điểm trừ (>0)
     * @param reason     mã nguồn (SHOP_PURCHASE/REFILL_PURCHASE/...)
     * @param causeKey   khóa idempotent tầng nghiệp vụ — retry cùng key trả
     *                   stored balance_after mà không trừ lại
     * @param sourceRef  tham chiếu ngoài (purchaseId / itemId)
     * @return balance_after sau debit (hoặc sau reconcile nếu replay)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public long debit(UUID userId, long amount, String reason,
                      String causeKey, String sourceRef) {
        if (!enabled) throw new IslandExceptions.FeatureDisabledException();
        if (amount <= 0) {
            throw new IllegalArgumentException("debit amount must be > 0");
        }
        Instant now = Instant.now(clock);
        WalletAccount a = lockAccount(userId, now);
        if (a.getBalance() < amount) {
            throw new IslandExceptions.InsufficientFundsException(
                    a.getBalance(), amount);
        }
        long projected = a.getBalance() - amount;
        int written = ledger.insertIgnore(userId,
                WalletTransaction.DIR_DEBIT, amount, reason, causeKey,
                sourceRef, projected);
        if (written == 0) {
            // Cause đã commit trước: bù balance về đúng stored balance_after
            // rồi return — KHÔNG debit lại (idempotent replay).
            WalletTransactionRepository.StoredCause stored =
                    ledger.findStoredByCauseKey(userId, causeKey);
            if (stored != null) {
                a.credit(stored.balanceAfter() - a.getBalance(), now);
                accounts.save(a);
                return stored.balanceAfter();
            }
            log.warn("wallet debit cause {} conflict, no stored row user={}",
                    causeKey, userId);
            return a.getBalance();
        }
        a.debit(amount, now);
        accounts.save(a);
        log.info("wallet debit user={} amount={} reason={} balance={}",
                userId, amount, reason, a.getBalance());
        return a.getBalance();
    }

    /* ---------- internals ---------- */

    /** Lazy-create + lazy-bridge — mọi đường vào wallet đi qua đây. */
    private void ensureAccountAndBridge(UUID userId) {
        Instant now = Instant.now(clock);
        accounts.insertIgnore(userId, now);
        // Bridge chỉ chạy một lần thực chất: ON CONFLICT cause_key DO
        // NOTHING — lần 2 chỉ select + no-op.
        ledger.bridgeFromRewardTransactions(userId);
        // Sau bridge: nếu wallet_transactions có row mà wallet_accounts
        // vẫn balance=0 → user mới hoàn toàn, sync balance = tổng credit.
        // Nếu user đã debit trước đó → balance đúng, không ghi đè.
        WalletAccount a = accounts.findForUpdate(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "wallet insert lost for " + userId));
        long bridged = ledger.sumCredits(userId);
        long spent = ledger.sumDebits(userId);
        long expected = bridged - spent;
        if (a.getBalance() != expected) {
            // Đồng bộ balance với ledger — chỉ xảy ra lần đầu sau bridge
            // (hoặc khi reconcile thủ công); log để audit.
            log.info("wallet balance sync user={} old={} new={}",
                    userId, a.getBalance(), expected);
            a.credit(expected - a.getBalance(), now);
            accounts.save(a);
        }
    }

    /** Lock account dưới khóa ghi — caller đã lazy-create sẵn. */
    private WalletAccount lockAccount(UUID userId, Instant now) {
        accounts.insertIgnore(userId, now);
        ledger.bridgeFromRewardTransactions(userId);
        WalletAccount a = accounts.findForUpdate(userId)
                .orElseThrow(() -> new IllegalStateException(
                        "wallet insert lost for " + userId));
        long bridged = ledger.sumCredits(userId);
        long spent = ledger.sumDebits(userId);
        long expected = bridged - spent;
        if (a.getBalance() != expected) {
            a.credit(expected - a.getBalance(), now);
            accounts.save(a);
        }
        return a;
    }

    private WalletTransactionResponse toResponse(WalletTransaction t) {
        return new WalletTransactionResponse(t.getId(), t.getDirection(),
                t.getAmount(), t.getReason(), t.getCauseKey(),
                t.getSourceRef(), t.getBalanceAfter(), t.getCreatedAt());
    }
}
