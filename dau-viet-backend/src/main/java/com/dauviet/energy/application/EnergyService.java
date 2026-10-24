package com.dauviet.energy.application;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.energy.api.dto.EnergyStateResponse;
import com.dauviet.energy.domain.EnergyDepletedException;
import com.dauviet.energy.domain.EnergyTransaction;
import com.dauviet.energy.domain.UserEnergy;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository;
import com.dauviet.energy.infrastructure.persistence.UserEnergyRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Thể lực server-authoritative (GAME-02, ENGY-01..11).
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
 * <p>Feature flag {@code dauviet.energy.enabled=false}: gate/debit/recover
 * đều no-op (submit không bị chặn, không trừ) dùng khi rollout lệch phiên
 * bản mobile. Không phải thay thế cho idempotency — chỉ tắt áp dụng rule.
 */
@Service
public class EnergyService {

    private static final Logger log = LoggerFactory.getLogger(EnergyService.class);

    private final EnergyProperties props;
    private final UserEnergyRepository energy;
    private final EnergyTransactionRepository ledger;
    private final Clock clock;
    private final ObjectMapper mapper;

    public EnergyService(EnergyProperties props,
                         UserEnergyRepository energy,
                         EnergyTransactionRepository ledger,
                         Clock clock,
                         ObjectMapper mapper) {
        this.props = props;
        this.energy = energy;
        this.ledger = ledger;
        this.clock = clock;
        this.mapper = mapper;
    }

    /** Trạng thái energy hiện tại cho GET /me/energy — lazy-create nếu mới. */
    @Transactional
    public EnergyStateResponse stateOf(UUID userId) {
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now);
        return toResponse(e, now);
    }

    /**
     * Zero-energy gate (ENGY-09) — gọi TRƯỚC handler.evaluate bên trong
     * transaction của submit. Lazy-recover trước rồi mới kiểm tra: energy=0
     * mà đã qua đủ một chu kỳ hồi thì được phép đi tiếp (trường hợp C).
     * Chỉ gọi cho activity có chấm điểm; ungraded không bao giờ bị chặn.
     * Khi {@code enabled=false} → no-op.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public void gateForGradedSubmit(UUID userId) {
        if (!props.enabled()) return;
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now);
        if (e.getCurrentEnergy() <= 0) {
            throw new EnergyDepletedException(nextRecoveryAt(e, now), now);
        }
    }

    /**
     * Trừ energy sau submission sai của activity có chấm điểm — gọi SAU
     * handler.evaluate, cùng transaction. amount = min(penalty, current).
     * cause_key = SUBMIT_PENALTY:{attemptId}:{activityId}:{attemptNo} — mỗi
     * lần submit mới hợp lệ trừ một lần, idempotent replay không trừ lại.
     * Khi {@code enabled=false} → no-op.
     *
     * @return số energy đã trừ (0 = không bị phạt)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int settleAfterSubmission(UUID userId, UUID attemptId,
                                     String activityId, int attemptNo) {
        if (!props.enabled()) return 0;
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now);
        int amount = Math.min(props.incorrectPenalty(), e.getCurrentEnergy());
        if (amount <= 0) return 0;
        e.debit(amount, now);
        energy.save(e);
        String causeKey = "SUBMIT_PENALTY:" + attemptId + ":" + activityId
                + ":" + attemptNo;
        ObjectNode ref = mapper.createObjectNode();
        ref.put("attemptId", attemptId.toString());
        ref.put("activityId", activityId);
        ref.put("attemptNo", attemptNo);
        int written = ledger.insertIgnore(userId, EnergyTransaction.DIR_DEBIT,
                amount, EnergyTransaction.REASON_GRADED_INCORRECT, causeKey,
                e.getCurrentEnergy(), ref.toString());
        log.info("energy penalty user={} attempt={} activity={} attemptNo={} "
                + "amount={} balance={} ledger={}",
                userId, attemptId, activityId, attemptNo, amount,
                e.getCurrentEnergy(), written);
        return amount;
    }

    /**
     * Atomic refill cho GAME-07 (wallet +20 Thể lực) — đặt sẵn chữ ký nguyên
     * tử để WalletService gọi trong cùng transaction của giao dịch mua;
     * CHƯA có endpoint/flow nào gọi ở GAME-02 (§13 brief). Không expose API.
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int applyRefill(UUID userId, int amount, String causeKey,
                           String referenceJson) {
        if (amount <= 0) {
            throw new IllegalArgumentException("refill amount must be > 0");
        }
        Instant now = Instant.now(clock);
        UserEnergy e = recoverLocked(userId, now);
        int credited = Math.min(amount, props.maxEnergy() - e.getCurrentEnergy());
        if (credited <= 0) return 0;
        e.credit(credited, null);
        energy.save(e);
        ledger.insertIgnore(userId, EnergyTransaction.DIR_CREDIT, credited,
                EnergyTransaction.REASON_REFILL_PURCHASE, causeKey,
                e.getCurrentEnergy(), referenceJson);
        return credited;
    }

    /* ---------- internals ---------- */

    /**
     * Đọc trạng thái energy của user DƯỚI KHÓA, lazy-create nếu chưa có và
     * áp lazy-recovery. Mọi đường gọi ghi đều qua đây nên lock order nhất
     * quán: user_energy luôn được lấy sau learner_attempts (submit đã lock
     * attempt trước) — không đảo thứ tự ở đường khác.
     */
    private UserEnergy recoverLocked(UUID userId, Instant now) {
        UserEnergy e = energy.findForUpdate(userId).orElse(null);
        if (e == null) {
            // Race hai request đầu tiên: insertIgnore của kẻ thua trả 0 rồi
            // đọc lại — row của kẻ thắng đã commit-visible trong tx này.
            energy.insertIgnore(userId, props.maxEnergy(), now);
            e = energy.findForUpdate(userId)
                    .orElseThrow(() -> new IllegalStateException(
                            "user_energy insert lost for " + userId));
        }
        applyLazyRecovery(e, userId, now);
        return e;
    }

    /**
     * cycles = floor((now - lastRecoveryAt) / interval). Clock bất thường
     * (lastRecoveryAt ở tương lai) → elapsed âm → cycles = 0, không cộng,
     * không âm, không reset mốc (an toàn với NTP jump/clock skew nhỏ).
     * Đầy max thì anchor neo tới đúng điểm chạm max — không tích lũy chu kỳ
     * ảo cho lần tiêu kế tiếp.
     */
    private void applyLazyRecovery(UserEnergy e, UUID userId, Instant now) {
        long intervalSec = props.recoveryInterval().getSeconds();
        long elapsedSec = Math.max(0,
                now.getEpochSecond() - e.getLastRecoveryAt().getEpochSecond());
        long cycles = elapsedSec / intervalSec;
        if (cycles <= 0 || e.getCurrentEnergy() >= props.maxEnergy()) {
            // Đang đầy: anchor trượt theo thời gian (không ghi ledger — không
            // có thay đổi energy), giữ hành vi "đầy không tích lũy".
            if (e.getCurrentEnergy() >= props.maxEnergy() && cycles > 0) {
                e.credit(0, e.getLastRecoveryAt()
                        .plusSeconds(cycles * intervalSec));
            }
            return;
        }
        long wanted = cycles * props.recoveryAmount();
        int credited = (int) Math.min(wanted,
                props.maxEnergy() - e.getCurrentEnergy());
        if (credited <= 0) return;
        long cyclesUsed = Math.min(cycles,
                (credited + props.recoveryAmount() - 1) / props.recoveryAmount());
        Instant newAnchor = e.getLastRecoveryAt()
                .plusSeconds(cyclesUsed * intervalSec);
        e.credit(credited, newAnchor);
        energy.save(e);
        String causeKey = "RECOVERY:" + userId + ":" + newAnchor.getEpochSecond();
        ledger.insertIgnore(userId, EnergyTransaction.DIR_CREDIT, credited,
                EnergyTransaction.REASON_NATURAL_RECOVERY, causeKey,
                e.getCurrentEnergy(), null);
    }

    /** Mốc hồi kế tiếp; null khi đã đầy (không có chu kỳ đang chờ). */
    private Instant nextRecoveryAt(UserEnergy e, Instant now) {
        if (e.getCurrentEnergy() >= props.maxEnergy()) return null;
        Instant next = e.getLastRecoveryAt().plus(props.recoveryInterval());
        return next.isBefore(now) ? now : next;
    }

    private EnergyStateResponse toResponse(UserEnergy e, Instant now) {
        return new EnergyStateResponse(e.getCurrentEnergy(), props.maxEnergy(),
                props.recoveryAmount(), props.recoveryInterval().getSeconds(),
                nextRecoveryAt(e, now), now,
                !props.enabled() || e.getCurrentEnergy() > 0);
    }
}
