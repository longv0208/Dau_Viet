package com.dauviet.energy.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import com.dauviet.energy.domain.EnergyDepletedException;
import com.dauviet.energy.domain.UserEnergy;
import com.dauviet.energy.infrastructure.persistence.EnergyTransactionRepository;
import com.dauviet.energy.infrastructure.persistence.UserEnergyRepository;
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

        service = new EnergyService(new EnergyProperties(true, 100, 10, 5,
                Duration.ofMinutes(15)), energyRepo, ledger, clock,
                new ObjectMapper());
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
                energyRepo, ledger, clock, new ObjectMapper());
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
}
