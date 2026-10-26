package com.dauviet.streak.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.learning.api.dto.CompleteAttemptResponse;
import com.dauviet.streak.api.dto.LearningStreakCalendarResponse;
import com.dauviet.streak.api.dto.LearningStreakResponse;
import com.dauviet.streak.domain.UserLearningStreak;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakDayRepository;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakRepository;

/**
 * Chuỗi Ngày Học — Ngọn Lửa Hào Khí (STREAK-01, V31).
 *
 * <p>Nguồn sự thật: server-side {@code learner_attempts.completed_at} chuyển
 * sang ngày theo timezone {@link #TZ_HCM}. KHÔNG tin client time — request
 * chỉ mang JWT + attemptId.
 *
 * <p>Ghi streak chỉ xảy ra TRONG transaction của LearnerAttemptService
 * .doComplete() — completion rollback thì streak rollback cùng, không có
 * trạng thái "complete rồi nhưng streak chưa ghi". Idempotency 3 lớp:
 *   1. Caller chỉ gọi khi attempt flip IN_PROGRESS → COMPLETED lần đầu;
     attempt COMPLETED sẵn thì vào nhánh already-completed, không tới đây.
 *   2. UNIQUE(user_id, study_date) trên ledger chống duplicate khi caller
 *      hoặc concurrency bypass lớp 1.
 *   3. advanceTo() của domain là no-op khi newDate == lastQualifiedDate.
 *
 * <p>Concurrency: mọi ghi serialize qua {@code findForUpdate} trên
 * user_learning_streaks — hai thiết bị complete cùng ngày của cùng user,
 * tx sau phải chờ tx trước commit rồi nhìn thấy lastQualifiedDate đã đổi
 * → advanceTo no-op đúng chuẩn.
 *
 * <p>Đọc API ({@link #stateOf}, {@link #calendarOf}) KHÔNG ghi DB —
 * {@code readOnly=true} tránh việc mở transaction "read" vẫn trigger lazy
 * update kiểu energy recovery. Ngày học đã qua KHÔNG tự động reset current
 * streak ở đây — đọc được tính streakAlive để client hiển thị "còn kịp
 * giữ chuỗi hôm nay"; lần ghi tiếp theo sẽ set current=1 đúng quy tắc.
 */
@Service
public class LearningStreakService {

    private static final Logger log = LoggerFactory
            .getLogger(LearningStreakService.class);

    /** Timezone nghiệp vụ — giờ Việt Nam, khớp business rule STREAK-01. */
    public static final ZoneId TZ_HCM = ZoneId.of("Asia/Ho_Chi_Minh");

    /** Số ngày tối đa trả trong calendar — client không được kéo cả lịch sử. */
    private static final int CALENDAR_MAX_DAYS = 92;

    private final UserLearningStreakRepository streaks;
    private final UserLearningStreakDayRepository days;
    private final Clock clock;

    public LearningStreakService(UserLearningStreakRepository streaks,
                                 UserLearningStreakDayRepository days,
                                 Clock clock) {
        this.streaks = streaks;
        this.days = days;
        this.clock = clock;
    }

    /**
     * Ghi nhận một lần hoàn thành bài — gọi TRONG transaction của
     * LearnerAttemptService.doComplete() sau khi attempt đã flip COMPLETED.
     * Idempotent: gọi lại với cùng (userId, studyDate) chỉ là no-op.
     *
     * @param userId         chủ attempt (đã verify từ JWT + loadOwned)
     * @param lessonId       lesson vừa hoàn thành
     * @param attemptId      learner_attempt vừa hoàn thành
     * @param completedAtUtc completed_at do server ghi (UTC)
     * @return StreakInfo cho client hiển thị animation (null nếu ngày đã
     *         được công nhận từ trước — không phát lại animation).
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public CompleteAttemptResponse.StreakInfo recordCompletion(
            UUID userId, UUID lessonId, UUID attemptId,
            Instant completedAtUtc) {
        Instant now = Instant.now(clock);
        LocalDate studyDate = LocalDate.ofInstant(completedAtUtc, TZ_HCM);

        // Ledger-first: UNIQUE(user, date) chặn concurrent duplicate — chỉ
        // tx thắng race mới đi tiếp update aggregate. Row kia chưa commit
        // thì tx này insert thành công và lastQualifiedDate cập nhật đúng;
        // row kia rollback thì tx này vẫn là chủ duy nhất của ngày.
        int written = days.insertIgnore(userId, studyDate, lessonId, attemptId,
                completedAtUtc, now);
        if (written == 0) {
            // Ngày đã công nhận — replay/concurrent same-day. Không đụng
            // aggregate nữa.
            return null;
        }

        // Serialize ghi trên row streak — lock-order nhất quán sau
        // learner_attempts (caller đã lock attempt trước).
        UserLearningStreak s = lockOrCreate(userId, now);
        s.advanceTo(studyDate, now);
        streaks.save(s);
        log.info("streak advance user={} date={} current={} longest={}",
                userId, studyDate, s.getCurrentStreak(), s.getLongestStreak());
        return new CompleteAttemptResponse.StreakInfo(true,
                s.getCurrentStreak(), s.getLongestStreak(), studyDate);
    }

    /**
     * Trạng thái streak hiện tại cho GET /me/streak — đọc-only, KHÔNG ghi
     * DB (đúng contract: "Đọc API không được âm thầm sửa trạng thái").
     * Lazy-create ở đây không áp — user mới chưa học trả bộ default
     * (current=0, alive=false).
     */
    @Transactional(readOnly = true)
    public LearningStreakResponse stateOf(UUID userId) {
        Instant now = Instant.now(clock);
        LocalDate today = LocalDate.ofInstant(now, TZ_HCM);
        UserLearningStreak s = streaks.findById(userId).orElse(null);

        int current = s == null ? 0 : s.getCurrentStreak();
        int longest = s == null ? 0 : s.getLongestStreak();
        LocalDate last = s == null ? null : s.getLastQualifiedDate();
        boolean completedToday = last != null && last.equals(today);
        boolean streakAlive = last != null
                && (last.equals(today) || last.equals(today.minusDays(1)));

        return new LearningStreakResponse(current, longest, completedToday,
                streakAlive, last, today, TZ_HCM.getId(), now);
    }

    /**
     * Lịch sử ngày đã học [from, to] — đọc-only. Giới hạn span để tránh
     * payload vô hạn; client điều chỉnh window theo viewport (theo tháng).
     */
    @Transactional(readOnly = true)
    public LearningStreakCalendarResponse calendarOf(UUID userId,
                                                     LocalDate from,
                                                     LocalDate to) {
        Instant now = Instant.now(clock);
        if (from == null || to == null || from.isAfter(to)) {
            throw new IllegalArgumentException(
                    "invalid range: from must be <= to");
        }
        if (to.isBefore(from.plusDays(0))
                || java.time.temporal.ChronoUnit.DAYS.between(from, to)
                        > CALENDAR_MAX_DAYS) {
            to = from.plusDays(CALENDAR_MAX_DAYS);
        }
        List<LocalDate> list = days.findDatesBetween(userId, from, to);
        return new LearningStreakCalendarResponse(from, to, TZ_HCM.getId(),
                list, now);
    }

    /**
     * Lock row streak của user, lazy-create nếu chưa có. Race hai request
     * đầu tiên: insertIgnore của kẻ thua trả 0 rồi đọc lại — row kẻ thắng
     * đã visible trong tx này.
     */
    private UserLearningStreak lockOrCreate(UUID userId, Instant now) {
        UserLearningStreak s = streaks.findForUpdate(userId).orElse(null);
        if (s == null) {
            streaks.insertIgnore(userId, now);
            s = streaks.findForUpdate(userId).orElseThrow(
                    () -> new IllegalStateException(
                            "user_learning_streaks insert lost for " + userId));
        }
        return s;
    }
}
