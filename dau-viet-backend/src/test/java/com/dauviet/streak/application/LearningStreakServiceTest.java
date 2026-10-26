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
import com.dauviet.streak.domain.UserLearningStreak;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakDayRepository;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakRepository;

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
                        Mockito.any()))
                .thenAnswer(inv -> {
                    UUID u = inv.getArgument(0);
                    LocalDate d = inv.getArgument(1);
                    return dayKeys.add(u + ":" + d) ? 1 : 0;
                });

        service = new LearningStreakService(streakRepo, dayRepo, clock);
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
}
