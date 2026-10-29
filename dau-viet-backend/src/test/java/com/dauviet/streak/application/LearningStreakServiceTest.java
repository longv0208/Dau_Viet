package com.dauviet.streak.application;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.dauviet.learning.api.dto.CompleteAttemptResponse;
import com.dauviet.learning.application.IdempotencyService;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;
import com.dauviet.streak.domain.UserLearningStreak;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakDayRepository;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakRepository;
import com.dauviet.wallet.application.WalletService;

/**
 * Unit test STREAK-01 — kiểm chứng luật streak với Clock giả lập (không cần
 * Docker). Repo mock in-memory giữ rows theo PK để mô phỏng ON CONFLICT +
 * findForUpdate đúng semantics.
 *
 * Kịch bản phủ:
 *   - user mới = 0
 *   - complete lần đầu = 1
 *   - 2 bài cùng ngày VN vẫn = 1
 *   - ngày kế = 2
 *   - bỏ lỡ 1 ngày, học lại = 1 (longest giữ)
 *   - replay cùng attempt không tăng
 *   - 23:59 vs 00:01 VN = 2 ngày khác nhau
 *   - concurrent same-day (ledger trùng) → chỉ 1 ngày
 */
class LearningStreakServiceTest {

    private static final UUID U = UUID.randomUUID();
    private static final UUID LESSON = UUID.randomUUID();
    private static final Instant T0 = Instant.parse("2026-10-25T17:00:00Z");
    // T0 = 26-10-2026 00:00 theo giờ VN — thuận tiện cho date math.

    private UserLearningStreakRepository streakRepo;
    private UserLearningStreakDayRepository dayRepo;
    private RewardTransactionRepository rewardRepo;
    private WalletService wallet;
    private IdempotencyService idempotency;
    private MutableClock clock;
    private LearningStreakService service;

    private final Map<UUID, UserLearningStreak> streaks = new HashMap<>();
    private final Set<String> dayKeys = new HashSet<>();

    static final class MutableClock extends Clock {
        private Instant now;
        MutableClock(Instant start) { this.now = start; }
        void set(Instant t) { now = t; }
        void advance(Duration d) { now = now.plus(d); }
        @Override public Instant instant() { return now; }
        @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId z) { return this; }
    }

    @BeforeEach
    void setUp() {
        streaks.clear();
        dayKeys.clear();
        clock = new MutableClock(T0);
        streakRepo = Mockito.mock(UserLearningStreakRepository.class);
        dayRepo = Mockito.mock(UserLearningStreakDayRepository.class);

        Mockito.when(streakRepo.findForUpdate(Mockito.any()))
                .thenAnswer(inv -> Optional.ofNullable(
                        streaks.get(inv.getArgument(0))));
        Mockito.when(streakRepo.findById(Mockito.any(UUID.class)))
                .thenAnswer(inv -> Optional.ofNullable(
                        streaks.get(inv.getArgument(0))));
        Mockito.when(streakRepo.insertIgnore(Mockito.any(), Mockito.any()))
                .thenAnswer(inv -> {
                    UUID u = inv.getArgument(0);
                    if (streaks.containsKey(u)) return 0;
                    UserLearningStreak s = new UserLearningStreak();
                    // Tạo row "blank" giống insertIgnore của migration V31.
                    streaks.put(u, s);
                    return 1;
                });
        Mockito.when(streakRepo.save(Mockito.any()))
                .thenAnswer(inv -> inv.getArgument(0));

        Mockito.when(dayRepo.insertIgnore(Mockito.any(), Mockito.any(),
                        Mockito.any(), Mockito.any(), Mockito.any(),
                        Mockito.any(), Mockito.anyInt(), Mockito.anyInt(),
                        Mockito.any(), Mockito.any()))
                .thenAnswer(inv -> {
                    UUID u = inv.getArgument(0);
                    LocalDate d = inv.getArgument(1);
                    return dayKeys.add(u + ":" + d) ? 1 : 0;
                });

        rewardRepo = Mockito.mock(RewardTransactionRepository.class);
        Mockito.when(rewardRepo.insertIgnore(Mockito.any(), Mockito.any(),
                        Mockito.any(), Mockito.anyLong(), Mockito.any(),
                        Mockito.any()))
                .thenReturn(1); // mọi grant đều insert thành công trong unit

        wallet = Mockito.mock(WalletService.class);
        // Idempotency thật trên repo mock in-memory — buyShield cần
        // execute() hoạt động (claim → executor → storeResponse).
        var records = new java.util.HashMap<String,
                com.dauviet.learning.domain.IdempotencyRecord>();
        var idemRepo = Mockito.mock(
                com.dauviet.learning.infrastructure.persistence
                        .IdempotencyRecordRepository.class);
        Mockito.when(idemRepo.findByUserIdAndOperationAndIdempotencyKey(
                        Mockito.any(), Mockito.any(), Mockito.any()))
                .thenAnswer(inv -> java.util.Optional.ofNullable(
                        records.get(inv.getArgument(0) + "|"
                                + inv.getArgument(1) + "|"
                                + inv.getArgument(2))));
        Mockito.when(idemRepo.saveAndFlush(Mockito.any()))
                .thenAnswer(inv -> {
                    var rec = inv.getArgument(0,
                            com.dauviet.learning.domain.IdempotencyRecord.class);
                    records.put(rec.getUserId() + "|" + rec.getOperation()
                            + "|" + rec.getIdempotencyKey(), rec);
                    return rec;
                });
        Mockito.when(idemRepo.save(Mockito.any()))
                .thenAnswer(inv -> inv.getArgument(0));
        var mapper = new com.fasterxml.jackson.databind.ObjectMapper()
                .registerModule(new com.fasterxml.jackson.datatype.jsr310
                        .JavaTimeModule());
        idempotency = new IdempotencyService(idemRepo, mapper, 86400);

        service = new LearningStreakService(streakRepo, dayRepo, rewardRepo,
                wallet, idempotency, clock);
    }

    private Instant utcOnVnDate(int year, int month, int day, int hour, int min) {
        // Trả Instant UTC tương đương HH:mm ngày đó theo giờ VN.
        return LocalDate.of(year, month, day)
                .atTime(hour, min)
                .atZone(LearningStreakService.TZ_HCM)
                .toInstant();
    }

    @Test
    void newUserReadsZero() {
        var r = service.stateOf(U);
        assertThat(r.currentStreak()).isZero();
        assertThat(r.longestStreak()).isZero();
        assertThat(r.completedToday()).isFalse();
        assertThat(r.streakAlive()).isFalse();
        assertThat(r.lastQualifiedDate()).isNull();
    }

    @Test
    void firstCompletionSetsStreakOne() {
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        assertThat(info).isNotNull();
        assertThat(info.dayRecorded()).isTrue();
        assertThat(info.currentStreak()).isEqualTo(1);
        assertThat(info.studyDate()).isEqualTo(LocalDate.of(2026, 10, 26));
    }

    @Test
    void sameDayTwoLessonsCountsOnce() {
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var second = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 14, 0));
        assertThat(second).isNull(); // ledger ON CONFLICT → no animation
        var r = service.stateOf(U);
        assertThat(r.currentStreak()).isEqualTo(1);
        assertThat(r.longestStreak()).isEqualTo(1);
        assertThat(r.completedToday()).isTrue();
    }

    @Test
    void nextDayIncrementsToTwo() {
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var next = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 8, 0));
        assertThat(next).isNotNull();
        assertThat(next.currentStreak()).isEqualTo(2);
        // Tick clock tới 27-10 VN để stateOf nhìn last==today.
        clock.set(Instant.parse("2026-10-27T02:00:00Z"));
        var r = service.stateOf(U);
        assertThat(r.longestStreak()).isEqualTo(2);
        assertThat(r.completedToday()).isTrue();
    }

    @Test
    void skipOneDayResetsToOneButKeepsLongest() {
        // 26 + 27 → streak 2. Bỏ 28. 29 học lại → reset 1, longest vẫn 2.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        var after = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 29, 9, 0));
        assertThat(after).isNotNull();
        assertThat(after.currentStreak()).isEqualTo(1);
        // Di chuyển clock tới 29 để đọc state đúng
        clock.set(Instant.parse("2026-10-29T02:00:00Z"));
        var r = service.stateOf(U);
        assertThat(r.currentStreak()).isEqualTo(1);
        assertThat(r.longestStreak()).isEqualTo(2);
    }

    @Test
    void replayAttemptDoesNotIncrement() {
        UUID attempt = UUID.randomUUID();
        service.recordCompletion(U, LESSON, attempt,
                utcOnVnDate(2026, 10, 26, 9, 0));
        // Replay: ledger ON CONFLICT user+date → null
        var replay = service.recordCompletion(U, LESSON, attempt,
                utcOnVnDate(2026, 10, 26, 9, 0));
        assertThat(replay).isNull();
        assertThat(streaks.get(U).getCurrentStreak()).isEqualTo(1);
    }

    @Test
    void timezoneBoundary2359Vs0001() {
        // 23:59 VN 26-10 → studyDate 26-10. 00:01 VN 27-10 → studyDate 27-10.
        var a = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 23, 59));
        var b = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 0, 1));
        assertThat(a.studyDate()).isEqualTo(LocalDate.of(2026, 10, 26));
        assertThat(b.studyDate()).isEqualTo(LocalDate.of(2026, 10, 27));
        assertThat(b.currentStreak()).isEqualTo(2);
    }

    @Test
    void streakAliveAfterYesterdayOnly() {
        // Học hôm qua, chưa học hôm nay → chuỗi còn duy trì được.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        // Tick tới sáng hôm sau theo VN
        clock.set(Instant.parse("2026-10-26T17:00:01Z")); // = 27-10 00:00:01 VN
        var r = service.stateOf(U);
        assertThat(r.streakAlive()).isTrue();
        assertThat(r.completedToday()).isFalse();
        assertThat(r.currentStreak()).isEqualTo(1);
    }

    @Test
    void stateOfReturnsZeroEffectiveStreakWhenStreakBroken() {
        // Học 26 + 27 → current=2, longest=2. Bỏ lỡ 28 + 29 (không gọi
        // recordCompletion). Đọc stateOf vào 30 → chuỗi đã ngắt: aggregate
        // vẫn lưu current_streak=2 (lần ghi cuối) nhưng HIỆU LỰC = 0.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        assertThat(streaks.get(U).getCurrentStreak()).isEqualTo(2);
        // Tick clock tới 30-10 VN — last = 27-10 < today-1 → broken.
        clock.set(Instant.parse("2026-10-29T17:30:00Z")); // 30-10 00:30 VN
        var r = service.stateOf(U);
        assertThat(r.currentStreak()).isZero();
        assertThat(r.streakAlive()).isFalse();
        assertThat(r.completedToday()).isFalse();
        assertThat(r.longestStreak()).isEqualTo(2); // kỷ lục không giảm
        assertThat(r.lastQualifiedDate())
                .isEqualTo(LocalDate.of(2026, 10, 27));
        // Aggregate KHÔNG bị ghi đè — đọc API là read-only.
        assertThat(streaks.get(U).getCurrentStreak()).isEqualTo(2);
    }

    @Test
    void completionAfterBreakRestartsAtOne() {
        // Sau khi chuỗi ngắt (đọc effective=0), học lại → bắt đầu từ 1.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        // Học lại vào 30-10 (sau gap 28, 29).
        var again = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 30, 8, 0));
        assertThat(again).isNotNull();
        assertThat(again.currentStreak()).isEqualTo(1);
        assertThat(again.longestStreak()).isEqualTo(2);
    }

    @Test
    void concurrentSameDayWritesOneDay() {
        // Mock ON CONFLICT: insert lần 2 cùng (user, date) trả 0 — giống
        // hai thiết bị complete đồng thời nhưng PK chặn duplicate.
        var a = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var b = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        assertThat(a).isNotNull();
        assertThat(b).isNull();
        assertThat(dayKeys).hasSize(1);
    }

    @Test
    void readOnlyDoesNotPersistAnything() {
        // stateOf trên user mới: KHÔNG lazy-create row (đúng contract).
        service.stateOf(U);
        assertThat(streaks).isEmpty();
        assertThat(dayKeys).isEmpty();
    }

    @Test
    void differentUsersIndependent() {
        UUID other = UUID.randomUUID();
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        service.recordCompletion(other, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        service.recordCompletion(other, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        assertThat(streaks.get(U).getCurrentStreak()).isEqualTo(1);
        assertThat(streaks.get(other).getCurrentStreak()).isEqualTo(2);
        assertThat(streaks.get(other).getLongestStreak()).isEqualTo(2);
    }

    @Test
    void calendarReturnsSortedDatesWithinRange() {
        UUID u = U;
        LocalDate from = LocalDate.of(2026, 10, 20);
        LocalDate to = LocalDate.of(2026, 10, 31);
        java.util.List<LocalDate> expected = java.util.List.of(
                LocalDate.of(2026, 10, 22),
                LocalDate.of(2026, 10, 25),
                LocalDate.of(2026, 10, 27));
        Mockito.when(dayRepo.findDatesBetween(u, from, to))
                .thenReturn(expected);
        var r = service.calendarOf(u, from, to);
        assertThat(r.days()).containsExactlyElementsOf(expected);
        assertThat(r.timezone()).isEqualTo("Asia/Ho_Chi_Minh");
    }

    @Test
    void calendarRejectsInvertedRange() {
        org.junit.jupiter.api.Assertions.assertThrows(
                IllegalArgumentException.class,
                () -> service.calendarOf(U,
                        LocalDate.of(2026, 10, 30),
                        LocalDate.of(2026, 10, 20)));
    }

    @Test
    void streakInfoIsNullWhenCompletionReturnsNull() {
        // Đảm bảo caller không crash khi ngày đã có — doComplete dùng
        // streak == null để quyết định không trả animation.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        CompleteAttemptResponse.StreakInfo second =
                service.recordCompletion(U, LESSON, UUID.randomUUID(),
                        utcOnVnDate(2026, 10, 26, 10, 0));
        assertThat(second).isNull();
    }

    /* ================= STREAK-02: Khiên Bảo Vệ + Thưởng Chuỗi ================= */

    /** Helper: tạo streak row rồi nạp sẵn khiên cho user. */
    private void grantShields(int count) {
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 20, 9, 0));
        UserLearningStreak s = streaks.get(U);
        for (int i = 0; i < count; i++) {
            s.addShield(clock.instant());
        }
    }

    @Test
    void shieldAutoConsumesOnExactlyOneMissedDay() {
        // Học 26-10, bỏ 27-10, học lại 28-10 với 1 khiên → khiên tự trừ,
        // chuỗi nối tiếp 2, ngày 27 đánh dấu SHIELD_PROTECTED.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        streaks.get(U).addShield(clock.instant()); // 1 khiên
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 28, 9, 0));
        assertThat(info).isNotNull();
        assertThat(info.currentStreak()).isEqualTo(2);
        assertThat(info.shieldConsumed()).isTrue();
        assertThat(info.shieldCount()).isZero();
        assertThat(streaks.get(U).getShieldCount()).isZero();
        // Ledger có row SHIELD_PROTECTED cho 27-10.
        assertThat(dayKeys).contains(U + ":" + LocalDate.of(2026, 10, 27));
    }

    @Test
    void missedOneDayWithoutShieldResetsToOne() {
        // Cùng kịch bản trên nhưng shieldCount=0 → chuỗi reset về 1.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 28, 9, 0));
        assertThat(info).isNotNull();
        assertThat(info.currentStreak()).isEqualTo(1);
        assertThat(info.shieldConsumed()).isFalse();
        assertThat(dayKeys)
                .doesNotContain(U + ":" + LocalDate.of(2026, 10, 27));
    }

    @Test
    void missedTwoOrMoreDaysWithShieldsStillResets() {
        // Bỏ >= 2 ngày liên tiếp: khiên KHÔNG cứu được, cũng không bị
        // trừ vô ích — chuỗi reset về 1.
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        UserLearningStreak s = streaks.get(U);
        s.addShield(clock.instant());
        s.addShield(clock.instant());
        s.addShield(clock.instant()); // 3 khiên
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 29, 9, 0)); // bỏ 27+28
        assertThat(info).isNotNull();
        assertThat(info.currentStreak()).isEqualTo(1);
        assertThat(info.shieldConsumed()).isFalse();
        assertThat(s.getShieldCount()).isEqualTo(3); // khiên giữ nguyên
    }

    @Test
    void dailyRewardGrantedFromDayTwo() {
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        assertThat(info.bonusExp()).isEqualTo(5);
        assertThat(info.bonusPoints()).isEqualTo(5);
        assertThat(info.milestoneDay()).isNull();
    }

    @Test
    void milestoneRewardAtDayThree() {
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 25, 9, 0));
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 27, 9, 0));
        // Ngày 3: daily 5+5 cộng mốc 15 EXP + 10 điểm.
        assertThat(info.milestoneDay()).isEqualTo(3);
        assertThat(info.bonusExp()).isEqualTo(20);
        assertThat(info.bonusPoints()).isEqualTo(15);
    }

    @Test
    void noRewardOnStreakReset() {
        // Đứt chuỗi → current=1 → không daily, không mốc (phạt = mất
        // thu nhập, không trừ điểm).
        service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 29, 9, 0));
        assertThat(info.bonusExp()).isZero();
        assertThat(info.bonusPoints()).isZero();
        assertThat(info.milestoneDay()).isNull();
    }

    @Test
    void noDailyRewardOnFirstDay() {
        var info = service.recordCompletion(U, LESSON, UUID.randomUUID(),
                utcOnVnDate(2026, 10, 26, 9, 0));
        assertThat(info.bonusExp()).isZero();
        assertThat(info.bonusPoints()).isZero();
    }

    @Test
    void buyShieldDebitsPointsAndIncrements() {
        Mockito.when(wallet.debit(Mockito.any(), Mockito.anyLong(),
                        Mockito.any(), Mockito.any(), Mockito.any()))
                .thenReturn(30L);
        var res = service.buyShield(U, "key-1");
        assertThat(res.shieldCount()).isEqualTo(1);
        assertThat(res.balanceAfter()).isEqualTo(30L);
        assertThat(streaks.get(U).getShieldCount()).isEqualTo(1);
        Mockito.verify(wallet).debit(Mockito.eq(U), Mockito.eq(20L),
                Mockito.eq("STREAK_SHIELD_PURCHASE"),
                Mockito.eq("STREAK_SHIELD:key-1"), Mockito.any());
    }

    @Test
    void buyShieldBlockedAtMaxCapacity() {
        grantShields(3); // streak row + 3 khiên
        org.junit.jupiter.api.Assertions.assertThrows(
                com.dauviet.streak.domain.StreakExceptions
                        .ShieldAtMaxCapacityException.class,
                () -> service.buyShield(U, "key-2"));
        Mockito.verify(wallet, Mockito.never()).debit(Mockito.any(),
                Mockito.anyLong(), Mockito.any(), Mockito.any(),
                Mockito.any());
    }

    @Test
    void buyShieldIdempotentReplaySameKey() {
        Mockito.when(wallet.debit(Mockito.any(), Mockito.anyLong(),
                        Mockito.any(), Mockito.any(), Mockito.any()))
                .thenReturn(10L);
        var first = service.buyShield(U, "key-3");
        var replay = service.buyShield(U, "key-3");
        // Cùng key → stored response, debit chỉ gọi 1 lần.
        assertThat(replay.shieldCount()).isEqualTo(first.shieldCount());
        Mockito.verify(wallet, Mockito.times(1)).debit(Mockito.any(),
                Mockito.anyLong(), Mockito.any(), Mockito.any(),
                Mockito.any());
        assertThat(streaks.get(U).getShieldCount()).isEqualTo(1);
    }

    @Test
    void stateOfExposesShieldFields() {
        grantShields(2);
        var r = service.stateOf(U);
        assertThat(r.shieldCount()).isEqualTo(2);
        assertThat(r.maxShields()).isEqualTo(3);
        assertThat(r.shieldCostPoints()).isEqualTo(20L);
        assertThat(r.milestones()).hasSize(4);
    }
}
