package com.dauviet.energy.application;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.energy.api.dto.EnergyRemedyDto;
import com.dauviet.energy.api.dto.EnergyRefillResponse;
import com.dauviet.energy.api.dto.EnergyStateResponse;
import com.dauviet.energy.domain.EnergyDepletedException;
import com.dauviet.energy.domain.EnergyPolicySetting;
import com.dauviet.energy.domain.EnergyRefillExceptions;
import com.dauviet.energy.domain.EnergyRemedy;
import com.dauviet.energy.domain.EnergyTransaction;
import com.dauviet.energy.domain.UserEnergy;
import com.dauviet.energy.infrastructure.persistence.EnergyPolicySettingRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyRemedyRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository.RemedyUsageProjection;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository.StoredCause;
import com.dauviet.energy.infrastructure.persistence.UserEnergyRepository;
import com.dauviet.learning.application.IdempotencyService;
import com.dauviet.wallet.application.WalletService;
import com.dauviet.wallet.domain.WalletTransaction;
import com.dauviet.wallet.infrastructure.persistence.WalletTransactionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Thể lực server-authoritative (GAME-02, ENGY-01..11) + Viện Thái Y
 * (GAME-07, Issue #28).
 *
 * <p>Lazy recovery — không cron/scheduler: mỗi thao tác cần energy đọc trạng
 * thái DƯỚI KHÓA, tính số chu kỳ {@code recoveryInterval} đã trôi qua kể từ
 * {@code last_recovery_at}, cộng {@code recoveryAmount}/chu kỳ (clamp max),
 * và tiến {@code last_recovery_at} đúng {@code cycles * interval} — GIỮ PHẦN
 * LẺ (10:00 → 10:20 chỉ tiêu 1 chu kỳ, anchor = 10:15 nên 10:30 hồi tiếp,
 * không chờ tới 10:35). Ghi NATURAL_RECOVERY ledger chỉ khi energy thực sự
 * tăng.
 *
 * <p>Quy tắc trừ: chỉ khi {@link #settleAfterSubmission} được gọi với verdict
 * INCORRECT của activity có chấm điểm (do LearnerAttemptService quyết định —
 * GradedActivityClassifier). Số trừ = min(incorrectPenalty, current): energy
 * 1–9 vẫn được submit nhưng sai thì trừ hết phần còn lại (ENGY-10). Debit
 * reset {@code last_recovery_at = now} — không cho phép hồi ngay từ thời
 * gian tích cũ khi đã đầy (trường hợp D của brief).
 *
 * <p>cause_key deterministic theo nguyên nhân — retry/concurrent chỉ tạo đúng
 * một bút toán (UNIQUE + ON CONFLICT DO NOTHING). Atomicity: mọi settle chạy
 * TRONG transaction của caller (REQUIRED) — submission rollback thì
 * energy + ledger rollback cùng.
 *
 * <p>GAME-07 (Issue #28): chính sách Thể lực đọc từ
 * {@code energy_policy_settings} (V49) mỗi request — admin PUT settings có
 * hiệu lực ngay. Fallback về {@link EnergyProperties} khi không có row
 * (unit test không chạy Flyway hoặc DB trống). Endpoint
 * {@code POST /me/energy/refills} thực thi mua/dùng vật phẩm Viện Thái Y
 * nguyên tử: lock {@code user_energy} TRƯỚC → kiểm cooldown → trừ wallet
 * (lock {@code wallet_accounts} SAU — lock order nhất quán contract §5) →
 * ghi ledger + credit clamp max → trả snapshot.
 */
@Service
public class EnergyService {

    private static final Logger log = LoggerFactory.getLogger(EnergyService.class);

    /** Operation name trên idempotency_records cho refill Viện Thái Y. */
    static final String OP_ENERGY_REFILL = "ENERGY_REFILL";

    /** Cửa sổ cooldown tối đa (24h) — lọc query ledger tránh quét vô hạn. */
    private static final Duration MAX_COOLDOWN_WINDOW = Duration.ofDays(2);

    private final EnergyProperties props;
    private final UserEnergyRepository energy;
    private final EnergyTransactionRepository ledger;
    private final EnergyPolicySettingRepository policyRepo;
    private final EnergyRemedyRepository remedyRepo;
    private final WalletTransactionRepository walletLedger;
    private final WalletService wallet;
    private final IdempotencyService idempotency;
    private final Clock clock;
    private final ObjectMapper mapper;

    public EnergyService(EnergyProperties props,
                         UserEnergyRepository energy,
                         EnergyTransactionRepository ledger,
                         EnergyPolicySettingRepository policyRepo,
                         EnergyRemedyRepository remedyRepo,
                         WalletTransactionRepository walletLedger,
                         WalletService wallet,
                         IdempotencyService idempotency,
                         Clock clock,
                         ObjectMapper mapper) {
        this.props = props;
        this.energy = energy;
        this.ledger = ledger;
        this.policyRepo = policyRepo;
        this.remedyRepo = remedyRepo;
        this.walletLedger = walletLedger;
        this.wallet = wallet;
        this.idempotency = idempotency;
        this.clock = clock;
        this.mapper = mapper;
    }

    /* ---------- Policy snapshot ---------- */

    /**
     * Trả chính sách đang áp dụng — đọc DB mỗi request (không cache) để
     * admin PUT settings có hiệu lực ngay. Fallback về EnergyProperties
     * khi không có row (unit test không chạy Flyway, DB trống).
     */
    private PolicySnapshot policy() {
        return policyRepo.findSingleton()
                .map(s -> new PolicySnapshot(
                        s.isEnabled(), s.getMaxEnergy(),
                        s.getIncorrectPenalty(), s.getRecoveryAmount(),
                        s.getRecoveryIntervalSeconds()))
                .orElseGet(() -> new PolicySnapshot(
                        props.enabled(), props.maxEnergy(),
                        props.incorrectPenalty(), props.recoveryAmount(),
                        props.recoveryInterval().getSeconds()));
    }

    /** Value object — tách policy ra khỏi entity để service không phụ thuộc JPA. */
    record PolicySnapshot(boolean enabled, int maxEnergy,
                          int incorrectPenalty, int recoveryAmount,
                          int recoveryIntervalSeconds) {
        /** Convenience overload cho EnergyProperties trả long. */
        PolicySnapshot(boolean enabled, int maxEnergy, int incorrectPenalty,
                       int recoveryAmount, long recoveryIntervalSeconds) {
            this(enabled, maxEnergy, incorrectPenalty, recoveryAmount,
                    (int) recoveryIntervalSeconds);
        }
        Duration recoveryInterval() {
            return Duration.ofSeconds(recoveryIntervalSeconds);
        }
    }

    /* ---------- Read ---------- */

    /**
     * Trạng thái energy hiện tại cho GET /me/energy — lazy-create nếu mới.
     * Trả kèm {@code pointsBalance} (Điểm Sử Ký từ wallet ledger) và
     * {@code remedies[]} (catalog Viện Thái Y với eligible/blockReasons
     * do server quyết).
     */
    @Transactional
    public EnergyStateResponse stateOf(UUID userId) {
        Instant now = Instant.now(clock);
        PolicySnapshot policy = policy();
        UserEnergy e = recoverLocked(userId, now, policy);
        return toResponse(e, now, policy);
    }

    /**
     * Snapshot trạng thái energy NGAY TRONG transaction submit —
     * trả kèm response để client biết balance mới mà không phải gọi lại
     * /me/energy. Hàng đã lock sẵn nên đọc lại rẻ; KHÔNG áp thêm recovery
     * (vừa settle trước đó — chỉ project trạng thái hiện tại).
     */
    public EnergyStateResponse snapshot(UUID userId) {
        Instant now = Instant.now(clock);
        PolicySnapshot policy = policy();
        UserEnergy e = energy.findForUpdate(userId).orElse(null);
        if (e == null) {
            return new EnergyStateResponse(policy.maxEnergy(),
                    policy.maxEnergy(), policy.recoveryAmount(),
                    policy.recoveryIntervalSeconds(), null, now, true,
                    pointsBalance(userId), List.of());
        }
        return toResponse(e, now, policy);
    }

    /* ---------- Refill (GAME-07) ---------- */

    /**
     * Refill Thể lực bằng một vật phẩm Viện Thái Y — idempotent + atomic.
     * Endpoint {@code POST /api/v1/me/energy/refills}, Idempotency-Key bắt
     * buộc ở controller.
     *
     * <p>Thứ tự:
     * <pre>
     *   idempotency.execute(userId, "ENERGY_REFILL", key, "REFILL:"+code, () -> {
     *     PolicySnapshot p = policy();
     *     UserEnergy e = recoverLocked(userId, now, p);      ← lock user_energy
     *     EnergyRemedy r = remedyRepo.findActiveByCode(code) ← 404 nếu !found
     *     if (e.current >= p.maxEnergy) → REFILL_NOT_ELIGIBLE (422)
     *     if (cooldownEndsAt(r, now) > now) → REFILL_RATE_LIMITED (409)
     *     String cause = "REFILL:" + key;
     *     if (r.pointsCost > 0) wallet.debit(...)              ← lock wallet_accounts
     *     int credited = min(r.energyGain, p.maxEnergy - e.current);
     *     ledger.insertIgnore(... CREDIT, REFILL_PURCHASE, cause, projected, ref)
     *     e.credit(credited, projected >= p.maxEnergy ? now : null); // ENGY-08
     *     return EnergyRefillResponse;
     *   })
     * </pre>
     *
     * <p>Lock order: user_energy trước, wallet_accounts sau — khớp contract
     * §5 và không deadlock với ShopService.purchase (vốn cũng lock wallet
     * trước inventory).
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public EnergyRefillResponse refill(UUID userId, String remedyCode,
                                       String idempotencyKey) {
        String normalized = remedyCode == null ? "" : remedyCode.trim()
                .toUpperCase(java.util.Locale.ROOT);
        String fingerprint = "REFILL:" + normalized;
        return idempotency.execute(userId, OP_ENERGY_REFILL,
                idempotencyKey, fingerprint,
                () -> doRefill(userId, normalized, idempotencyKey),
                EnergyRefillResponse.class);
    }

    private EnergyRefillResponse doRefill(UUID userId, String remedyCode,
                                          String idempotencyKey) {
        Instant now = Instant.now(clock);
        PolicySnapshot policy = policy();
        UserEnergy e = recoverLocked(userId, now, policy);
        EnergyRemedy remedy = remedyRepo.findActiveByCode(remedyCode)
                .orElseThrow(() ->
                        new EnergyRefillExceptions.RemedyNotFoundException(
                                remedyCode));
        if (e.getCurrentEnergy() >= policy.maxEnergy()) {
            throw new EnergyRefillExceptions.RefillNotEligibleException(
                    "ENERGY_FULL", e.getCurrentEnergy(), policy.maxEnergy());
        }
        Instant cooldownEndsAt = remedyCooldownEnd(remedy, userId, now);
        if (cooldownEndsAt != null && cooldownEndsAt.isAfter(now)) {
            Instant lastUsed = remedyLastUsedAt(remedy, userId, now);
            throw new EnergyRefillExceptions.RefillRateLimitedException(
                    remedy.getCode(),
                    lastUsed != null ? lastUsed : now,
                    cooldownEndsAt, now);
        }
        String causeKey = "REFILL:" + idempotencyKey;
        long walletBalance = pointsBalance(userId);
        if (remedy.getPointsCost() > 0) {
            walletBalance = wallet.debit(userId, remedy.getPointsCost(),
                    WalletTransaction.REASON_REFILL_PURCHASE,
                    causeKey, remedy.getCode());
        }
        int credited = Math.min(remedy.getEnergyGain(),
                policy.maxEnergy() - e.getCurrentEnergy());
        int projected = e.getCurrentEnergy() + credited;
        ObjectNode ref = mapper.createObjectNode();
        ref.put("remedyCode", remedy.getCode());
        ref.put("remedyId", remedy.getId().toString());
        ref.put("pointsCost", remedy.getPointsCost());
        ref.put("energyGain", remedy.getEnergyGain());
        int written = ledger.insertIgnore(userId, EnergyTransaction.DIR_CREDIT,
                credited, EnergyTransaction.REASON_REFILL_PURCHASE,
                causeKey, projected, ref.toString());
        if (written == 0) {
            // Cause đã commit trước (replay trong cùng Idempotency-Key cấp
            // trên sẽ return sớm — đây là backstop tầng DB): chỉ reconcile
            // balance về stored, không double-apply.
            reconcileFromStoredCause(e, userId, causeKey, now, policy);
        } else {
            // ENGY-08: đạt max → neo last_recovery_at = now; chưa max →
            // giữ anchor cũ để không mất phút đang đếm dở.
            e.credit(credited, projected >= policy.maxEnergy() ? now : null);
            energy.save(e);
        }
        log.info("energy refill user={} remedy={} credited={} cost={} "
                + "balance={}", userId, remedy.getCode(), credited,
                remedy.getPointsCost(), walletBalance);
        EnergyStateResponse newState = toResponse(e, Instant.now(clock),
                policy);
        return new EnergyRefillResponse(
                newState,
                remedy.getCode(),
                credited,
                remedy.getPointsCost(),
                walletBalance,
                now,
                remedy.getCooldownSeconds() > 0
                        ? now.plusSeconds(remedy.getCooldownSeconds())
                        : null,
                Instant.now(clock));
    }

    /* ---------- Cooldown internals ---------- */

    /**
     * Tra cứu cooldown của một remedy cho user — trả Instant kết thúc
     * cooldown (có thể quá khứ nếu đã hết) hoặc null nếu không cooldown
     * hoặc chưa từng dùng.
     */
    private Instant remedyCooldownEnd(EnergyRemedy remedy, UUID userId,
                                      Instant now) {
        if (remedy.getCooldownSeconds() <= 0) return null;
        Instant lastUsed = remedyLastUsedAt(remedy, userId, now);
        if (lastUsed == null) return null;
        return lastUsed.plusSeconds(remedy.getCooldownSeconds());
    }

    /** Lần refill gần nhất của user cho remedy này — từ ledger (reference_json). */
    private Instant remedyLastUsedAt(EnergyRemedy remedy, UUID userId,
                                     Instant now) {
        Instant since = now.minus(MAX_COOLDOWN_WINDOW);
        List<RemedyUsageProjection> usages =
                ledger.findRecentRemedyUsages(userId, since);
        for (RemedyUsageProjection u : usages) {
            if (remedy.getCode().equalsIgnoreCase(u.getRemedyCode())) {
                return u.getLastUsedAt();
            }
        }
        return null;
    }

    /** Tất cả remedyCode → lastUsedAt trong cửa sổ cooldown. */
    private Map<String, Instant> remedyLastUsedMap(UUID userId, Instant now) {
        Instant since = now.minus(MAX_COOLDOWN_WINDOW);
        List<RemedyUsageProjection> usages =
                ledger.findRecentRemedyUsages(userId, since);
        Map<String, Instant> map = new HashMap<>();
        for (RemedyUsageProjection u : usages) {
            if (u.getRemedyCode() != null) {
                map.merge(u.getRemedyCode().toUpperCase(java.util.Locale.ROOT),
                        u.getLastUsedAt(), (a, b) -> a.isAfter(b) ? a : b);
            }
        }
        return map;
    }

    /** Điểm Sử Ký hiện có (credit - debit) — đọc thẳng từ wallet ledger. */
    private long pointsBalance(UUID userId) {
        long earned = walletLedger.sumCredits(userId);
        long spent = walletLedger.sumDebits(userId);
        return Math.max(0L, earned - spent);
    }

    /* ---------- Gate / settle (đọc policy từ DB) ---------- */

    /**
     * Zero-energy gate (ENGY-09) — gọi TRƯỚC handler.evaluate bên trong
     * transaction của submit. Lazy-recover trước rồi mới kiểm tra: energy=0
     * mà đã qua đủ một chu kỳ hồi thì được phép đi tiếp (trường hợp C).
     * Chỉ gọi cho activity có chấm điểm; ungraded không bao giờ bị chặn.
     * Khi {@code enabled=false} → no-op.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public void gateForGradedSubmit(UUID userId) {
        PolicySnapshot policy = policy();
        if (!policy.enabled()) return;
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now, policy);
        if (e.getCurrentEnergy() <= 0) {
            throw new EnergyDepletedException(nextRecoveryAt(e, now, policy),
                    now);
        }
    }

    /**
     * Trừ energy sau submission sai của activity có chấm điểm — gọi SAU
     * handler.evaluate, cùng transaction. amount = min(penalty, current).
     * cause_key = SUBMIT_PENALTY:{attemptId}:{activityId}:{attemptNo} — mỗi
     * lần submit mới hợp lệ trừ một lần, idempotent replay không trừ lại.
     * Khi {@code enabled=false} → no-op.
     *
     * <p>FIX 1 (idempotent ledger-first): ghi energy_transactions TRƯỚC khi
     * đụng balance. cause_key trùng → bút toán đã commit ở tx trước → KHÔNG
     * được trừ thêm phần energy đó; chỉ còn nghĩa vụ cộng recovery đã tích
     * lũy từ created_at của bút toán cũ (lazy-recover theo anchor chung).
     * Nhờ vậy retry/concurrent/duplicate-cause không bao giờ tạo lệch giữa
     * balance hiện hữu và tổng ledger.
     *
     * @return số energy đã trừ CHO submission này (0 = replay/no-op)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int settleAfterSubmission(UUID userId, UUID attemptId,
                                     String activityId, int attemptNo) {
        PolicySnapshot policy = policy();
        if (!policy.enabled()) return 0;
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now, policy);
        String causeKey = "SUBMIT_PENALTY:" + attemptId + ":" + activityId
                + ":" + attemptNo;
        ObjectNode ref = mapper.createObjectNode();
        ref.put("attemptId", attemptId.toString());
        ref.put("activityId", activityId);
        ref.put("attemptNo", attemptNo);

        // Ledger-first: balance_after gửi kèm là "dự kiến" — nếu cause đã
        // tồn tại, insert trả 0 và balance_after kia bị bỏ qua, không hại.
        int amount = Math.min(policy.incorrectPenalty(), e.getCurrentEnergy());
        if (amount <= 0) return 0;
        int projected = e.getCurrentEnergy() - amount;
        int written = ledger.insertIgnore(userId, EnergyTransaction.DIR_DEBIT,
                amount, EnergyTransaction.REASON_GRADED_INCORRECT, causeKey,
                projected, ref.toString());
        if (written == 0) {
            // Cause đã commit: bù balance về đúng ledger + recovery từ
            // created_at của bút toán đã lưu — tx cũ có thể rollback sau khi
            // insert ledger (hiếm), hoặc replay ở tầng trên. Submission này
            // không trừ gì thêm (return 0) — không double-apply.
            reconcileFromStoredCause(e, userId, causeKey, now, policy);
            return 0;
        }
        e.debit(amount, now);
        energy.save(e);
        log.info("energy penalty user={} attempt={} activity={} attemptNo={} "
                + "amount={} balance={}", userId, attemptId, activityId,
                attemptNo, amount, e.getCurrentEnergy());
        return amount;
    }

    /**
     * Atomic refill cho GAME-07 (wallet +N Thể lực) — giữ tương thích với
     * các caller cũ (WalletService hoặc service khác gọi trong cùng tx).
     * Endpoint mới chính là {@link #refill} — đây là chữ ký nguyên tử
     * dùng lại cho các luồng nội bộ.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int applyRefill(UUID userId, int amount, String causeKey,
                           String referenceJson) {
        if (amount <= 0) {
            throw new IllegalArgumentException("refill amount must be > 0");
        }
        Instant now = Instant.now(clock);
        PolicySnapshot policy = policy();
        UserEnergy e = recoverLocked(userId, now, policy);
        // Ledger-first — cause_key đã tồn tại thì chỉ bù recovery,
        // không credit thêm (một giao dịch mua = đúng một lần cộng).
        int credited = Math.min(amount,
                policy.maxEnergy() - e.getCurrentEnergy());
        if (credited <= 0) return 0;
        int projected = e.getCurrentEnergy() + credited;
        int written = ledger.insertIgnore(userId, EnergyTransaction.DIR_CREDIT,
                credited, EnergyTransaction.REASON_REFILL_PURCHASE, causeKey,
                projected, referenceJson);
        if (written == 0) {
            reconcileFromStoredCause(e, userId, causeKey, now, policy);
            return 0;
        }
        e.credit(credited, projected >= policy.maxEnergy() ? now : null);
        energy.save(e);
        return credited;
    }

    /* ---------- internals ---------- */

    /**
     * Đọc trạng thái energy của user DƯỚI KHÓA, lazy-create nếu chưa có và
     * áp lazy-recovery. Mọi đường gọi ghi đều qua đây nên lock order nhất
     * quán: user_energy luôn được lấy sau learner_attempts (submit đã lock
     * attempt trước) — không đảo thứ tự ở đường khác.
     */
    private UserEnergy recoverLocked(UUID userId, Instant now,
                                     PolicySnapshot policy) {
        UserEnergy e = energy.findForUpdate(userId).orElse(null);
        if (e == null) {
            // Race hai request đầu tiên: insertIgnore của kẻ thua trả 0 rồi
            // đọc lại — row của kẻ thắng đã commit-visible trong tx này.
            energy.insertIgnore(userId, policy.maxEnergy(), now);
            e = energy.findForUpdate(userId)
                    .orElseThrow(() -> new IllegalStateException(
                            "user_energy insert lost for " + userId));
        }
        applyLazyRecovery(e, userId, now, policy);
        return e;
    }

    /**
     * cycles = floor(elapsed / interval), elapsed đo bằng Duration giữ
     * nano — 14p59.9s KHÔNG tính là đủ 15 phút (FIX 5). Clock bất thường
     * (lastRecoveryAt ở tương lai) → elapsed âm → cycles = 0, không cộng,
     * không âm, không reset mốc (an toàn với NTP jump/clock skew nhỏ).
     * Đầy max thì anchor neo tới đúng điểm chạm max — không tích lũy chu kỳ
     * ảo cho lần tiêu kế tiếp.
     */
    private void applyLazyRecovery(UserEnergy e, UUID userId, Instant now,
                                   PolicySnapshot policy) {
        long intervalSec = policy.recoveryIntervalSeconds();
        Duration interval = policy.recoveryInterval();
        Duration elapsed = Duration.between(e.getLastRecoveryAt(), now);
        if (elapsed.isNegative()) elapsed = Duration.ZERO;
        long cycles = elapsed.dividedBy(interval);
        if (cycles <= 0 || e.getCurrentEnergy() >= policy.maxEnergy()) {
            // Đang đầy: anchor trượt theo thời gian (không ghi ledger — không
            // có thay đổi energy), giữ hành vi "đầy không tích lũy".
            if (e.getCurrentEnergy() >= policy.maxEnergy() && cycles > 0) {
                e.credit(0, e.getLastRecoveryAt()
                        .plusSeconds(cycles * intervalSec));
            }
            return;
        }
        long wanted = cycles * policy.recoveryAmount();
        int credited = (int) Math.min(wanted,
                policy.maxEnergy() - e.getCurrentEnergy());
        if (credited <= 0) return;
        long cyclesUsed = Math.min(cycles,
                (credited + policy.recoveryAmount() - 1)
                        / policy.recoveryAmount());
        Instant newAnchor = e.getLastRecoveryAt()
                .plusSeconds(cyclesUsed * intervalSec);
        e.credit(credited, newAnchor);
        energy.save(e);
        String causeKey = "RECOVERY:" + userId + ":" + newAnchor.getEpochSecond();
        ledger.insertIgnore(userId, EnergyTransaction.DIR_CREDIT, credited,
                EnergyTransaction.REASON_NATURAL_RECOVERY, causeKey,
                e.getCurrentEnergy(), null);
    }

    /**
     * FIX 1: cause_key đã tồn tại trong ledger → bút toán tương ứng đã được
     * commit trước đó. Cân bằng lại về trạng thái đúng: current =
     * balance_after của bút toán đó, rồi cộng recovery đã trôi qua kể từ
     * created_at của nó (không dùng last_recovery_at hiện hữu — mốc đó có
     * thể đã trôi quá xa và tính gộp thời gian của tx rollback). Trả true
     * nếu tìm thấy stored cause và đã bù.
     */
    private boolean reconcileFromStoredCause(UserEnergy e, UUID userId,
                                             String causeKey, Instant now,
                                             PolicySnapshot policy) {
        StoredCause stored = ledger.findStoredByCauseKey(userId, causeKey);
        if (stored == null) {
            // Conflict với row vừa insert trong CÙNG tx chưa flush — rất
            // hiếm; an toàn nhất là coi như chưa có bút toán: không debit/
            // credit gì (đã kiểm tra trước). Để lại row hiện hữu nguyên.
            log.warn("energy cause {} conflict but no stored row user={}",
                    causeKey, userId);
            return false;
        }
        e.setCurrentEnergy(stored.balanceAfter());
        e.setLastRecoveryAt(stored.createdAt());
        energy.save(e);
        applyLazyRecovery(e, userId, now, policy);
        return true;
    }

    /** Mốc hồi kế tiếp; null khi đã đầy (không có chu kỳ đang chờ). */
    private Instant nextRecoveryAt(UserEnergy e, Instant now,
                                   PolicySnapshot policy) {
        if (e.getCurrentEnergy() >= policy.maxEnergy()) return null;
        Instant next = e.getLastRecoveryAt()
                .plus(policy.recoveryInterval());
        return next.isBefore(now) ? now : next;
    }

    private EnergyStateResponse toResponse(UserEnergy e, Instant now,
                                           PolicySnapshot policy) {
        return new EnergyStateResponse(e.getCurrentEnergy(),
                policy.maxEnergy(), policy.recoveryAmount(),
                policy.recoveryIntervalSeconds(),
                nextRecoveryAt(e, now, policy), now,
                !policy.enabled() || e.getCurrentEnergy() > 0,
                pointsBalance(e.getUserId()),
                remedyDtos(e, now, policy));
    }

    /**
     * Catalog Viện Thái Y cho learner — chỉ remedies active, sort theo
     * sort_order. Server quyết eligible + blockReasons để client chỉ
     * render (backend-authoritative, CODING_RULES §3).
     */
    private List<EnergyRemedyDto> remedyDtos(UserEnergy e, Instant now,
                                             PolicySnapshot policy) {
        List<EnergyRemedy> active = remedyRepo.findAllActiveOrdered();
        Map<String, Instant> lastUsedMap = remedyLastUsedMap(e.getUserId(), now);
        long balance = pointsBalance(e.getUserId());
        return active.stream()
                .map(r -> toRemedyDto(r, e, now, policy,
                        lastUsedMap.get(r.getCode().toUpperCase(
                                java.util.Locale.ROOT)), balance))
                .collect(Collectors.toList());
    }

    private EnergyRemedyDto toRemedyDto(EnergyRemedy r, UserEnergy e,
                                        Instant now, PolicySnapshot policy,
                                        Instant lastUsedAt, long balance) {
        List<String> blockReasons = new java.util.ArrayList<>();
        if (e.getCurrentEnergy() >= policy.maxEnergy()) {
            blockReasons.add("ENERGY_FULL");
        }
        Instant cooldownEndsAt = null;
        if (r.getCooldownSeconds() > 0 && lastUsedAt != null) {
            Instant ends = lastUsedAt.plusSeconds(r.getCooldownSeconds());
            if (ends.isAfter(now)) {
                cooldownEndsAt = ends;
                blockReasons.add("REFILL_RATE_LIMITED");
            }
        }
        if (r.getPointsCost() > 0 && balance < r.getPointsCost()) {
            blockReasons.add("INSUFFICIENT_FUNDS");
        }
        int effectiveGain = Math.max(0, Math.min(r.getEnergyGain(),
                policy.maxEnergy() - e.getCurrentEnergy()));
        return new EnergyRemedyDto(
                r.getId(), r.getCode(), r.getTitle(), r.getDescription(),
                r.getRarity(), r.getIconKey(), r.getAssetId(),
                r.getEnergyGain(), r.getPointsCost(), r.getCooldownSeconds(),
                blockReasons.isEmpty(), effectiveGain, cooldownEndsAt,
                blockReasons);
    }
}
