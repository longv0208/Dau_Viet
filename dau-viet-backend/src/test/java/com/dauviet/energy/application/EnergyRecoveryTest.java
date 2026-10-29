package com.dauviet.energy.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import com.dauviet.energy.domain.EnergyDepletedException;
import com.dauviet.energy.domain.EnergyRefillExceptions;
import com.dauviet.energy.domain.EnergyRemedy;
import com.dauviet.energy.domain.UserEnergy;
import com.dauviet.energy.infrastructure.persistence.EnergyPolicySettingRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyRemedyRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository.StoredCause;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository.RemedyUsageProjection;
import com.dauviet.energy.infrastructure.persistence.UserEnergyRepository;
import com.dauviet.learning.application.IdempotencyService;
import com.dauviet.wallet.application.WalletService;
import com.dauviet.wallet.infrastructure.persistence.WalletTransactionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Unit test lazy-recovery + settle (GAME-02 §6, §11) với Clock giả lập —
 * không cần Docker/sleep thật. Repo giả lập in-memory đủ để kiểm chứng
 * số học: bảo toàn phần lẻ, clamp 0..max, đầy không tích lũy, debit reset
 * anchor, clock bất thường không tạo balance sai.
 */
class EnergyRecoveryTest {

    private static final Instant T0 = Instant.parse("2026-10-25T10:00:00Z");
    private static final UUID U = UUID.randomUUID();

    private UserEnergyRepository energyRepo;
    private EnergyTransactionRepository ledger;
    private EnergyPolicySettingRepository policyRepo;
    private EnergyRemedyRepository remedyRepo;
    private WalletTransactionRepository walletLedger;
    private WalletService wallet;
    private IdempotencyService idempotency;
    private MutableClock clock;
    private EnergyService service;
    private final Map<UUID, UserEnergy> rows = new HashMap<>();

    /** Clock tiến tay — test điều khiển thời gian. */
    static final class MutableClock extends Clock {
        private Instant now;
        MutableClock(Instant start) { this.now = start; }
        void advance(Duration d) { now = now.plus(d); }
        void set(Instant t) { now = t; }
        @Override public Instant instant() { return now; }
        @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId z) { return this; }
    }

    @BeforeEach
    void setUp() {
        rows.clear();
        clock = new MutableClock(T0);
        energyRepo = Mockito.mock(UserEnergyRepository.class);
        ledger = Mockito.mock(EnergyTransactionRepository.class);
        policyRepo = Mockito.mock(EnergyPolicySettingRepository.class);
        remedyRepo = Mockito.mock(EnergyRemedyRepository.class);
        walletLedger = Mockito.mock(WalletTransactionRepository.class);
        wallet = Mockito.mock(WalletService.class);
        idempotency = Mockito.mock(IdempotencyService.class);

        Mockito.when(energyRepo.findForUpdate(Mockito.any()))
                .thenAnswer(inv -> Optional.ofNullable(
                        rows.get(inv.getArgument(0))));
        Mockito.when(energyRepo.insertIgnore(Mockito.any(), Mockito.anyInt(),
                        Mockito.any()))
                .thenAnswer(inv -> {
                    UUID u = inv.getArgument(0);
                    int max = inv.getArgument(1);
                    Instant now = inv.getArgument(2);
                    if (rows.containsKey(u)) return 0;
                    rows.put(u, UserEnergy.start(u, max, now));
                    return 1;
                });
        Mockito.when(energyRepo.save(Mockito.any()))
                .thenAnswer(inv -> inv.getArgument(0));

        // IdempotencyService.execute mặc định chạy supplier trực tiếp
        // (không replay DB) — test thao túng fingerprint ở tầng ledger.
        Mockito.when(idempotency.execute(Mockito.any(), Mockito.any(),
                Mockito.any(), Mockito.any(), Mockito.any(), Mockito.any()))
                .thenAnswer(inv -> {
                    java.util.function.Supplier<Object> sup = inv.getArgument(4);
                    return sup.get();
                });

        service = new EnergyService(new EnergyProperties(true, 100, 10, 5,
                Duration.ofMinutes(15)), energyRepo, ledger, policyRepo,
                remedyRepo, walletLedger, wallet, idempotency, clock,
                new ObjectMapper());
        seedDefaultLedgerBehavior();
        seedDefaultRemedyRepoBehavior();
        seedDefaultPolicyRepoBehavior();
        seedDefaultWalletLedgerBehavior();
    }

    /* ---------- GAME-07 helper seed ---------- */

    /** Remedy mẫu cho test Viện Thái Y. */
    private EnergyRemedy remedy(String code, int energyGain,
                                 long pointsCost, int cooldownSeconds) {
        return EnergyRemedy.create(UUID.randomUUID(), code,
                "Thang " + code, "Test remedy", "COMMON",
                "energy_" + code.toLowerCase(), null,
                energyGain, pointsCost, cooldownSeconds,
                true, 0, T0);
    }

    /** Default: không có policy DB → fallback EnergyProperties. */
    private void seedDefaultPolicyRepoBehavior() {
        Mockito.when(policyRepo.findSingleton())
                .thenReturn(Optional.empty());
    }

    /** Default: remedyRepo trả empty → các test refill phải seed riêng. */
    private void seedDefaultRemedyRepoBehavior() {
        Mockito.when(remedyRepo.findActiveByCode(Mockito.any()))
                .thenReturn(Optional.empty());
        Mockito.when(remedyRepo.findAllActiveOrdered())
                .thenReturn(List.of());
    }

    /** Default: wallet ledger 0 → đủ kiểm tra eligibility matrix. */
    private void seedDefaultWalletLedgerBehavior() {
        Mockito.when(walletLedger.sumCredits(Mockito.any()))
                .thenReturn(80L);
        Mockito.when(walletLedger.sumDebits(Mockito.any()))
                .thenReturn(0L);
    }

    /**
     * FIX 1: ledger mặc định insert thành công (trả 1) — test chuyên sâu về
     * duplicate-cause override riêng. findStoredByCauseKey trả null mặc định.
     */
    private void seedDefaultLedgerBehavior() {
        Mockito.when(ledger.insertIgnore(Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any()))
                .thenReturn(1);
        Mockito.when(ledger.findStoredByCauseKey(Mockito.any(), Mockito.any()))
                .thenReturn(null);
    }

    private UserEnergy seed(int energy, Instant anchor) {
        UserEnergy e = UserEnergy.start(U, 100, anchor);
        e.debit(100 - energy, anchor); // đặt trực tiếp mức cần test
        rows.put(U, e);
        return e;
    }

    @Test
    void newUser_startsAtMax() {
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(100);
        assertThat(s.max()).isEqualTo(100);
        assertThat(s.nextRecoveryAt()).isNull(); // đầy → không chu kỳ chờ
        assertThat(s.canSubmitGraded()).isTrue();
    }

    @Test
    void recovery_belowOneCycle_noCredit() {
        seed(40, T0);
        clock.advance(Duration.ofMinutes(14));
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(40);
    }

    @Test
    void recovery_oneCycle_plusFive() {
        seed(40, T0);
        clock.advance(Duration.ofMinutes(15));
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(45);
    }

    @Test
    void recovery_threeCycles_plusFifteen() {
        seed(40, T0);
        clock.advance(Duration.ofMinutes(45));
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(55);
    }

    @Test
    void recovery_preservesFractionalRemainder() {
        // 10:00 anchor, đọc 10:20 → +5 và anchor -> 10:15; đọc lại 10:30
        // phải +5 tiếp (KHÔNG chờ tới 10:35) — phần lẻ 5 phút giữ nguyên.
        UserEnergy e = seed(40, T0);
        clock.set(T0.plusSeconds(20 * 60));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(45);
        assertThat(e.getLastRecoveryAt())
                .isEqualTo(T0.plusSeconds(15 * 60));
        clock.set(T0.plusSeconds(30 * 60));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(50);
    }

    @Test
    void recovery_clampsAtMax() {
        seed(95, T0);
        clock.advance(Duration.ofMinutes(60));
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(100);
        assertThat(s.nextRecoveryAt()).isNull();
    }

    @Test
    void recovery_atMax_accumulatesNothing_andDebitResetsClock() {
        // Đầy 100 chờ 3 tiếng rồi sai: trừ 10 → 90, anchor = now —
        // KHÔNG hồi ngay từ thời gian tích cũ (trường hợp D).
        seed(100, T0);
        clock.set(T0.plusSeconds(3 * 3600));
        service.stateOf(U); // anchor trượt tới ~13:00, không ledger credit
        UserEnergy e = rows.get(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(100);
        int debited = service.settleAfterSubmission(U,
                UUID.randomUUID(), "mc", 1);
        assertThat(debited).isEqualTo(10);
        assertThat(e.getCurrentEnergy()).isEqualTo(90);
        assertThat(e.getLastRecoveryAt())
                .isEqualTo(clock.instant());
        // 14 phút sau vẫn chưa hồi — đúng nhịp mới.
        clock.advance(Duration.ofMinutes(14));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(90);
        clock.advance(Duration.ofMinutes(1));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(95);
    }

    @Test
    void recovery_futureTimestamp_isSafe() {
        // last_recovery_at ở tương lai (clock skew/NTP jump): elapsed âm →
        // 0 chu kỳ, không cộng, không âm, không reset mốc sai.
        UserEnergy e = seed(50, T0.plusSeconds(3600));
        var s = service.stateOf(U);
        assertThat(s.current()).isEqualTo(50);
        assertThat(e.getLastRecoveryAt()).isEqualTo(T0.plusSeconds(3600));
    }

    @Test
    void penalty_clampsToRemaining() {
        // Trường hợp A: energy=5, sai → trừ hết 5, về 0.
        seed(5, T0);
        int debited = service.settleAfterSubmission(U,
                UUID.randomUUID(), "mc", 1);
        assertThat(debited).isEqualTo(5);
        assertThat(rows.get(U).getCurrentEnergy()).isZero();
    }

    @Test
    void gate_atZero_throwsButRecoveryUnlocks() {
        // Trường hợp B: 0 → 409. Trường hợp C: qua 15 phút → +5 → mở.
        seed(0, T0);
        assertThatThrownBy(() -> service.gateForGradedSubmit(U))
                .isInstanceOf(EnergyDepletedException.class);
        clock.advance(Duration.ofMinutes(15));
        service.gateForGradedSubmit(U); // không ném — đã hồi 5
        int debited = service.settleAfterSubmission(U,
                UUID.randomUUID(), "mc", 1);
        assertThat(debited).isEqualTo(5); // trừ hết phần vừa hồi
        assertThat(rows.get(U).getCurrentEnergy()).isZero();
    }

    @Test
    void disabledFlag_gateAndSettleAreNoOps() {
        EnergyService off = new EnergyService(
                new EnergyProperties(false, 100, 10, 5,
                        Duration.ofMinutes(15)),
                energyRepo, ledger, policyRepo, remedyRepo,
                walletLedger, wallet, idempotency, clock,
                new ObjectMapper());
        seed(0, T0);
        off.gateForGradedSubmit(U);              // không ném
        int debited = off.settleAfterSubmission(U,
                UUID.randomUUID(), "mc", 1);
        assertThat(debited).isZero();
        assertThat(rows.get(U).getCurrentEnergy()).isZero();
    }

    @Test
    void ledger_writesDebitWithBalanceAndCause() {
        seed(50, T0);
        UUID attempt = UUID.randomUUID();
        service.settleAfterSubmission(U, attempt, "mc", 2);
        ArgumentCaptor<String> cause = ArgumentCaptor.forClass(String.class);
        Mockito.verify(ledger).insertIgnore(Mockito.eq(U), Mockito.eq("DEBIT"),
                Mockito.eq(10), Mockito.eq("GRADED_INCORRECT"),
                cause.capture(), Mockito.eq(40), Mockito.any());
        assertThat(cause.getValue())
                .isEqualTo("SUBMIT_PENALTY:" + attempt + ":mc:2");
    }

    /* ---------- FIX 5: chính xác đến nano quanh ranh giới chu kỳ ---------- */

    @Test
    void recovery_14m59s2_noCredit() {
        // Epoch-second diff đã qua 900s nhưng thực tế chưa đủ — không hồi.
        UserEnergy e = seed(40, T0.plusMillis(900));
        clock.set(T0.plusSeconds(15 * 60).plusMillis(100));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(40);
    }

    @Test
    void recovery_exactly15m_credit() {
        UserEnergy e = seed(40, T0);
        clock.set(T0.plusSeconds(15 * 60));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(45);
    }

    @Test
    void recovery_15m0s8_creditAndKeepsFraction() {
        // Đủ 1 chu kỳ + 0,8s lẻ → hồi 5, anchor chỉ tiến đúng 15 phút
        // (0,8s lẻ giữ lại cho chu kỳ sau).
        UserEnergy e = seed(40, T0);
        clock.set(T0.plusSeconds(15 * 60).plusMillis(800));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(45);
        assertThat(e.getLastRecoveryAt())
                .isEqualTo(T0.plusSeconds(15 * 60));
    }

    @Test
    void recovery_29m59s9_onlyOneCycle() {
        UserEnergy e = seed(40, T0);
        clock.set(T0.plusSeconds(29 * 60).plusMillis(900));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(45);
    }

    @Test
    void recovery_exactly30m_twoCycles() {
        UserEnergy e = seed(40, T0);
        clock.set(T0.plusSeconds(30 * 60));
        service.stateOf(U);
        assertThat(e.getCurrentEnergy()).isEqualTo(50);
    }

    /* ---------- FIX 1: duplicate cause không trừ thêm ---------- */

    @Test
    void settle_duplicateCauseKey_doesNotDebitTwice() {
        // Ledger insert trả 0 (đã có cause) → balance phải bù về
        // balance_after đã lưu + recovery từ created_at, KHÔNG debit mới.
        seed(50, T0);
        Mockito.when(ledger.insertIgnore(Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any()))
                .thenReturn(0);
        Mockito.when(ledger.findStoredByCauseKey(Mockito.eq(U), Mockito.any()))
                .thenReturn(new StoredCause(40, T0));
        clock.set(T0.plusSeconds(15 * 60)); // đủ 1 chu kỳ kể từ tx gốc
        int debited = service.settleAfterSubmission(U, UUID.randomUUID(),
                "mc", 1);
        assertThat(debited).isZero(); // không trừ lần hai
        // balance = 40 (stored) + 5 recovery (1 chu kỳ từ T0) = 45.
        assertThat(rows.get(U).getCurrentEnergy()).isEqualTo(45);
    }

    @Test
    void refill_duplicateCauseKey_doesNotCreditTwice() {
        // Đồng hồ đã đứng T0 + 15p TRƯỚC khi refill → reconcile bù về stored
        // balance 60 + recovery tính từ created_at T0 (đủ 1 chu kỳ) = 65.
        seed(50, T0);
        clock.set(T0.plusSeconds(15 * 60));
        Mockito.when(ledger.insertIgnore(Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any()))
                .thenReturn(0);
        Mockito.when(ledger.findStoredByCauseKey(Mockito.eq(U), Mockito.any()))
                .thenReturn(new StoredCause(60, T0));
        int credited = service.applyRefill(U, 20, "PURCHASE:X", null);
        assertThat(credited).isZero(); // không credit lần hai
        // Đọc lại: bút toán RECOVERY do reconcile ghi có thể đổi balance —
        // ở đây mock insertIgnore trả 0 → state ổn định ở stored+recovery.
        service.stateOf(U);
        assertThat(rows.get(U).getCurrentEnergy()).isEqualTo(65);
    }

    @Test
    void settle_ledgerInsertFails_throwsPropagates() {
        // insertIgnore throw (vd. lỗi DB) → exception lan truyền, không có
        // debit bí mật — atomicity do tx đảm bảo (rollback kéo energy).
        seed(50, T0);
        Mockito.when(ledger.insertIgnore(Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any(), Mockito.any(),
                Mockito.anyInt(), Mockito.any()))
                .thenThrow(new RuntimeException("db down"));
        assertThatThrownBy(() -> service.settleAfterSubmission(U,
                UUID.randomUUID(), "mc", 1))
                .hasMessageContaining("db down");
        assertThat(rows.get(U).getCurrentEnergy()).isEqualTo(50); // không đổi
    }

    /* ---------- FIX 4: validate cấu hình ---------- */

    @Test
    void properties_maxOverSchemaCap_failsValidation() {
        assertThatThrownBy(() -> new EnergyProperties(true, 120, 10, 5,
                Duration.ofMinutes(15)).validate())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("schema CHECK cap");
    }

    @Test
    void properties_subSecondInterval_failsValidation() {
        assertThatThrownBy(() -> new EnergyProperties(true, 100, 10, 5,
                Duration.ofMillis(500)).validate())
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining(">= 1s");
    }

    @Test
    void properties_invalidValues_failFast() {
        assertThatThrownBy(() -> new EnergyProperties(true, 0, 10, 5,
                Duration.ofMinutes(15)).validate())
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new EnergyProperties(true, 100, 0, 5,
                Duration.ofMinutes(15)).validate())
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new EnergyProperties(true, 100, 10, 0,
                Duration.ofMinutes(15)).validate())
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> new EnergyProperties(true, 100, 200, 5,
                Duration.ofMinutes(15)).validate())
                .isInstanceOf(IllegalStateException.class); // penalty > max
    }

    /* ---------- GAME-07: refill Viện Thái Y ---------- */

    @Test
    void stateOf_includesRemediesAndPointsBalance() {
        seed(50, T0);
        Mockito.when(remedyRepo.findAllActiveOrdered())
                .thenReturn(List.of(
                        remedy("NUOC_VOI", 20, 0, 86400),
                        remedy("TRA_SEN", 30, 30, 14400)));
        var s = service.stateOf(U);
        assertThat(s.pointsBalance()).isEqualTo(80);
        assertThat(s.remedies()).hasSize(2);
        assertThat(s.remedies().get(0).code()).isEqualTo("NUOC_VOI");
        assertThat(s.remedies().get(0).eligible()).isTrue();
    }

    @Test
    void refill_nuocVoi_free_creditsEnergy() {
        seed(50, T0);
        Mockito.when(remedyRepo.findActiveByCode("NUOC_VOI"))
                .thenReturn(Optional.of(remedy("NUOC_VOI", 20, 0, 86400)));
        var res = service.refill(U, "nuoc_voi", "key-1");
        assertThat(res.remedyCode()).isEqualTo("NUOC_VOI");
        assertThat(res.energyCredited()).isEqualTo(20);
        assertThat(res.pointsSpent()).isZero();
        assertThat(res.energy().current()).isEqualTo(70);
        assertThat(res.nextEligibleAt())
                .isEqualTo(T0.plusSeconds(86400));
        // Không trừ ví (free)
        Mockito.verify(wallet, Mockito.never()).debit(
                Mockito.any(), Mockito.anyInt(), Mockito.any(),
                Mockito.any(), Mockito.any());
    }

    @Test
    void refill_traSen_paid_debitsWallet() {
        seed(50, T0);
        Mockito.when(remedyRepo.findActiveByCode("TRA_SEN"))
                .thenReturn(Optional.of(remedy("TRA_SEN", 30, 30, 14400)));
        Mockito.when(wallet.debit(U, 30,
                com.dauviet.wallet.domain.WalletTransaction.REASON_REFILL_PURCHASE,
                "REFILL:key-2", "TRA_SEN"))
                .thenReturn(50L);
        var res = service.refill(U, "TRA_SEN", "key-2");
        assertThat(res.energyCredited()).isEqualTo(30);
        assertThat(res.pointsSpent()).isEqualTo(30);
        assertThat(res.walletBalance()).isEqualTo(50);
        assertThat(res.energy().current()).isEqualTo(80);
    }

    @Test
    void refill_atMax_throwsEnergyFull() {
        seed(100, T0);
        Mockito.when(remedyRepo.findActiveByCode("NUOC_VOI"))
                .thenReturn(Optional.of(remedy("NUOC_VOI", 20, 0, 86400)));
        assertThatThrownBy(() -> service.refill(U, "NUOC_VOI", "key-3"))
                .isInstanceOf(
                    EnergyRefillExceptions.RefillNotEligibleException.class);
    }

    @Test
    void refill_rateLimited_throwsConflict() {
        seed(50, T0);
        EnergyRemedy r = remedy("TRA_SEN", 30, 30, 14400);
        Mockito.when(remedyRepo.findActiveByCode("TRA_SEN"))
                .thenReturn(Optional.of(r));
        // Lần refill 1 giờ trước → cooldown 4h chưa hết.
        Mockito.when(ledger.findRecentRemedyUsages(Mockito.any(), Mockito.any()))
                .thenReturn(List.of(new RemedyUsageProjection() {
                    @Override public String getRemedyCode() { return "TRA_SEN"; }
                    @Override public Instant getLastUsedAt() {
                        return T0.minusSeconds(3600);
                    }
                }));
        assertThatThrownBy(() -> service.refill(U, "TRA_SEN", "key-4"))
                .isInstanceOf(
                    EnergyRefillExceptions.RefillRateLimitedException.class);
    }

    @Test
    void refill_paidClampToMax_anchorsRecovery() {
        // Ví còn 80 điểm, remedy 30đ → 50 còn lại. Energy 95 → chỉ +5 thay vì 30.
        seed(95, T0);
        Mockito.when(remedyRepo.findActiveByCode("NAM_LINH_CHI"))
                .thenReturn(Optional.of(remedy("NAM_LINH_CHI", 50, 55, 43200)));
        Mockito.when(wallet.debit(U, 55,
                com.dauviet.wallet.domain.WalletTransaction.REASON_REFILL_PURCHASE,
                "REFILL:key-5", "NAM_LINH_CHI"))
                .thenReturn(25L);
        var res = service.refill(U, "NAM_LINH_CHI", "key-5");
        // Clamp: chỉ +5
        assertThat(res.energyCredited()).isEqualTo(5);
        assertThat(res.energy().current()).isEqualTo(100);
        // ENGY-08: đạt max → last_recovery_at neo lại = now
        assertThat(rows.get(U).getLastRecoveryAt()).isEqualTo(T0);
    }
}
