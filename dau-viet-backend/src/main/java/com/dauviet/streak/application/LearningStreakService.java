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
import com.dauviet.learning.application.IdempotencyService;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;
import com.dauviet.streak.api.dto.LearningStreakCalendarResponse;
import com.dauviet.streak.api.dto.LearningStreakResponse;
import com.dauviet.streak.api.dto.StreakMilestoneDto;
import com.dauviet.streak.api.dto.StreakShieldPurchaseResponse;
import com.dauviet.streak.domain.StreakExceptions;
import com.dauviet.streak.domain.UserLearningStreak;
import com.dauviet.streak.domain.UserLearningStreakDay;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakDayRepository;
import com.dauviet.streak.infrastructure.persistence.UserLearningStreakRepository;
import com.dauviet.wallet.application.WalletService;
import com.dauviet.wallet.domain.WalletTransaction;

/**
 * Chuỗi Ngày Học — Ngọn Lửa Hào Khí (STREAK-01 V31 + STREAK-02 V51).
 *
 * <p>Nguồn sự thật: server-side {@code learner_attempts.completed_at} chuyển
 * sang ngày theo timezone {@link #TZ_HCM}. KHÔNG tin client time — request
 * chỉ mang JWT + attemptId.
 *
 * <p>Ghi streak chỉ xảy ra TRONG transaction của LearnerAttemptService
 * .doComplete() — completion rollback thì streak rollback cùng, không có
 * trạng thái "complete rồi nhưng streak chưa ghi". Idempotency 3 lớp:
 *   1. Caller chỉ gọi khi attempt flip IN_PROGRESS → COMPLETED lần đầu;
 *     attempt COMPLETED sẵn thì vào nhánh already-completed, không tới đây.
 *   2. UNIQUE(user_id, study_date) trên ledger chống duplicate khi caller
 *      hoặc concurrency bypass lớp 1.
 *   3. advanceTo() của domain là no-op khi newDate == lastQualifiedDate.
 *
 * <p>Thưởng chuỗi (STREAK-02): chỉ grant khi server vừa công nhận MỘT
 * ngày học mới (ledger insertIgnore trả 1). RewardTransaction UNIQUE
 * cause_key 'STREAK:{user}:{date}:{type}:{bucket}' là backstop tầng DB —
 * reward rollback cùng attempt nếu complete fail. Ngày SHIELD_PROTECTED
 * không thưởng (user không học ngày đó); mốc tính theo current_streak
 * sau advance nên chuỗi được khiên cứu vẫn cộng bình thường.
 *
 * <p>Mua khiên (STREAK-02): {@link #buyShield} chạy tx riêng, lock
 * streak row → check capacity → debit wallet → addShield. Lock-order
 * streaks→wallet_accounts không xung đột với doComplete (attempts→
 * streak_days→streaks) vì hai đường không chia sẻ lock pair ngược.
 *
 * <p>Concurrency: mọi ghi serialize qua {@code findForUpdate} trên
 * user_learning_streaks — hai thiết bị complete cùng ngày của cùng user,
 * tx sau phải chờ tx trước commit rồi nhìn thấy lastQualifiedDate đã đổi
 * → advanceTo no-op đúng chuẩn.
 *
 * <p>Đọc API ({@link #stateOf}, {@link #calendarOf}) KHÔNG ghi DB —
 * {@code readOnly=true}. Ngày học đã qua KHÔNG tự động reset current
 * streak ở đây — đọc được tính streakAlive để client hiển thị "còn kịp
 * giữ chuỗi hôm nay"; lần ghi tiếp theo sẽ set current=1 đúng quy tắc.
 */
@Service
public class LearningStreakService {

    private static final Logger log = LoggerFactory
            .getLogger(LearningStreakService.class);

    /** Timezone nghiệp vụ — giờ Việt Nam, khớp business rule STREAK-02. */
    public static final ZoneId TZ_HCM = ZoneId.of("Asia/Ho_Chi_Minh");

    /** Số ngày tối đa trả trong calendar — client không được kéo cả lịch sử. */
    private static final int CALENDAR_MAX_DAYS = 92;

    /** Giá đổi một Khiên Bảo Vệ Chuỗi — Điểm Sử Ký (V51). */
    public static final long SHIELD_COST_POINTS = 20;

    /** Operation idempotent cho POST /me/streak/shields. */
    private static final String OP_SHIELD_PURCHASE = "STREAK_SHIELD_PURCHASE";

    private final UserLearningStreakRepository streaks;
    private final UserLearningStreakDayRepository days;
    private final RewardTransactionRepository rewards;
    private final WalletService wallet;
    private final IdempotencyService idempotency;
    private final Clock clock;

    public LearningStreakService(UserLearningStreakRepository streaks,
                                 UserLearningStreakDayRepository days,
                                 RewardTransactionRepository rewards,
                                 WalletService wallet,
                                 IdempotencyService idempotency,
                                 Clock clock) {
        this.streaks = streaks;
        this.days = days;
        this.rewards = rewards;
        this.wallet = wallet;
        this.idempotency = idempotency;
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
        // tx thắng race mới đi tiếp update aggregate + grant reward.
        int written = days.insertIgnore(userId, studyDate, lessonId,
                attemptId, completedAtUtc,
                UserLearningStreakDay.DAY_TYPE_STUDY, 0, 0, null, now);
        if (written == 0) {
            // Ngày đã công nhận — replay/concurrent same-day.
            return null;
        }

        // Serialize ghi trên row streak — lock-order nhất quán sau
        // learner_attempts (caller đã lock attempt trước).
        UserLearningStreak s = lockOrCreate(userId, now);
        UserLearningStreak.AdvanceResult result = s.advanceTo(studyDate, now);
        streaks.save(s);
        if (!result.dayRecorded()) {
            // Không thể xảy ra (ledger insertIgnore vừa thắng → ngày mới),
            // nhưng phòng thủ: không grant khi advance no-op.
            return null;
        }

        // Ngày bỏ lỡ vừa được khiên cứu → ghi ledger SHIELD_PROTECTED để
        // calendar đánh dấu 🛡️. insertIgnore: nếu một tx khác đã ghi ngày
        // đó là STUDY (race hai thiết bị), STUDY thắng — không ghi đè.
        if (result.shieldConsumed() && result.protectedDate() != null) {
            days.insertIgnore(userId, result.protectedDate(), lessonId,
                    attemptId, completedAtUtc,
                    UserLearningStreakDay.DAY_TYPE_SHIELD_PROTECTED,
                    0, 0, null, now);
            log.info("streak shield consumed user={} protected={} "
                            + "shields_left={} streak={}",
                    userId, result.protectedDate(), s.getShieldCount(),
                    s.getCurrentStreak());
        }

        // Thưởng chuỗi — chỉ ngày học thực, tính trên current_streak sau
        // advance (chuỗi được khiên cứu vẫn cộng bình thường).
        int current = s.getCurrentStreak();
        List<StreakRewardPolicy.Grant> grants =
                StreakRewardPolicyHolder.grantsFor(
                        userId, studyDate, current);
        int bonusExp = 0;
        int bonusPoints = 0;
        for (StreakRewardPolicy.Grant g : grants) {
            int inserted = rewards.insertIgnore(userId, attemptId,
                    g.rewardType(), g.amount(), g.reason(),
                    StreakRewardPolicy.causeKey(userId, studyDate,
                            g.rewardType(), g.bucket()));
            if (inserted > 0) {
                if (com.dauviet.reward.domain.RewardTransaction.TYPE_EXP
                        .equals(g.rewardType())) {
                    bonusExp += (int) g.amount();
                } else {
                    bonusPoints += (int) g.amount();
                }
            }
        }
        Integer milestone = StreakRewardPolicy.milestoneOf(current);
        // Đắp reward vào row ledger vừa ghi — audit sau này.
        if (bonusExp > 0 || bonusPoints > 0 || milestone != null) {
            days.updateReward(userId, studyDate, bonusExp, bonusPoints,
                    milestone);
        }
        log.info("streak advance user={} date={} current={} longest={} "
                        + "bonusExp={} bonusPoints={} milestone={}",
                userId, studyDate, current, s.getLongestStreak(),
                bonusExp, bonusPoints, milestone);
        return new CompleteAttemptResponse.StreakInfo(true,
                current, s.getLongestStreak(), studyDate, now,
                result.shieldConsumed(), s.getShieldCount(),
                bonusExp, bonusPoints, milestone);
    }

    /**
     * Đổi 20 Điểm Sử Ký lấy 1 Khiên Bảo Vệ Chuỗi — idempotent qua
     * Idempotency-Key bắt buộc (một key = một giao dịch).
     *
     * <p>Thứ tự trong tx: lock streak row (lazy-create) → check capacity
     * → wallet.debit → addShield → save. Debit throw thì rollback cả
     * increment; shieldCount kiểm tra DƯỚI lock nên hai request concurrent
     * không thể vượt MAX_SHIELDS.
     *
     * @return shieldCount mới + balance sau debit
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public StreakShieldPurchaseResponse buyShield(UUID userId,
                                                  String idempotencyKey) {
        return idempotency.execute(userId, OP_SHIELD_PURCHASE,
                idempotencyKey, "shield=1",
                () -> doBuyShield(userId, idempotencyKey),
                StreakShieldPurchaseResponse.class);
    }

    private StreakShieldPurchaseResponse doBuyShield(UUID userId,
                                                     String idempotencyKey) {
        Instant now = Instant.now(clock);
        UserLearningStreak s = lockOrCreate(userId, now);
        if (s.getShieldCount() >= UserLearningStreak.MAX_SHIELDS) {
            throw new StreakExceptions.ShieldAtMaxCapacityException(
                    s.getShieldCount(), UserLearningStreak.MAX_SHIELDS);
        }
        long balanceAfter = wallet.debit(userId, SHIELD_COST_POINTS,
                WalletTransaction.REASON_STREAK_SHIELD_PURCHASE,
                "STREAK_SHIELD:" + idempotencyKey,
                "streak-shield");
        s.addShield(now);
        streaks.save(s);
        log.info("streak shield purchased user={} shields={} balance={}",
                userId, s.getShieldCount(), balanceAfter);
        return new StreakShieldPurchaseResponse(s.getShieldCount(),
                UserLearningStreak.MAX_SHIELDS, SHIELD_COST_POINTS,
                balanceAfter, now);
    }

    /**
     * Trạng thái streak hiện tại cho GET /me/streak — đọc-only, KHÔNG ghi
     * DB. Lazy-create ở đây không áp — user mới chưa học trả bộ default.
     */
    @Transactional(readOnly = true)
    public LearningStreakResponse stateOf(UUID userId) {
        Instant now = Instant.now(clock);
        LocalDate today = LocalDate.ofInstant(now, TZ_HCM);
        UserLearningStreak s = streaks.findById(userId).orElse(null);

        // STRK contract: chuỗi HIỆU LỰC tại thời điểm GET — aggregate giữ
        // giá trị lần ghi cuối; last < hôm qua VN → chuỗi thực tế đã ngắt
        // → trả 0, longest giữ nguyên. KHÔNG ghi reset ở đây (read-only);
        // advanceTo() lần complete tiếp theo đặt current=1 đúng luật.
        LocalDate last = s == null ? null : s.getLastQualifiedDate();
        boolean completedToday = last != null && last.equals(today);
        boolean streakAlive = last != null
                && (last.equals(today) || last.equals(today.minusDays(1)));
        int effectiveCurrent = (s == null || !streakAlive)
                ? 0
                : s.getCurrentStreak();
        int longest = s == null ? 0 : s.getLongestStreak();
        int shieldCount = s == null ? 0 : s.getShieldCount();
        // Chuỗi đang có nguy cơ đứt HÔM NAY: học hôm qua nhưng chưa học
        // hôm nay → nếu không học sẽ vào nhánh shield/reset ở lần sau.
        boolean atRiskToday = last != null && last.equals(today.minusDays(1));
        // Khiên sẽ tự cứu NẾU hôm nay không học (bỏ lỡ đúng 1 ngày) —
        // client hiển thị "yên tâm, khiên sẽ bảo vệ".
        boolean shieldWillProtectToday = atRiskToday && shieldCount > 0;

        return new LearningStreakResponse(effectiveCurrent, longest,
                completedToday, streakAlive, last, today, TZ_HCM.getId(),
                now, shieldCount, UserLearningStreak.MAX_SHIELDS,
                SHIELD_COST_POINTS, atRiskToday, shieldWillProtectToday,
                milestoneDtos());
    }

    /**
     * Lịch sử ngày đã học + ngày được khiên bảo vệ [from, to] — đọc-only.
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
        if (java.time.temporal.ChronoUnit.DAYS.between(from, to)
                > CALENDAR_MAX_DAYS) {
            to = from.plusDays(CALENDAR_MAX_DAYS);
        }
        List<LocalDate> list = days.findDatesBetween(userId, from, to);
        List<LocalDate> protectedDates =
                days.findProtectedDatesBetween(userId, from, to);
        return new LearningStreakCalendarResponse(from, to, TZ_HCM.getId(),
                list, protectedDates, now);
    }

    /** Bảng mốc thưởng tĩnh cho response — client không hard-code. */
    private static List<StreakMilestoneDto> milestoneDtos() {
        return StreakRewardPolicy.MILESTONES.stream()
                .map(m -> new StreakMilestoneDto(m.day(), m.bonusExp(),
                        m.bonusPoints()))
                .toList();
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

    /** Giữ policy ở một nơi test được mà không inject bean (static table). */
    private static final class StreakRewardPolicyHolder {
        static List<StreakRewardPolicy.Grant> grantsFor(UUID userId,
                                                        LocalDate studyDate,
                                                        int currentStreak) {
            return new StreakRewardPolicy().grantsFor(userId, studyDate,
                    currentStreak);
        }
    }
}
