package com.dauviet.streak.application;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.reward.domain.RewardTransaction;

/**
 * Chính sách thưởng Chuỗi Ngày Học (STREAK-02, V51 / Issue #38).
 *
 * <p>Hai loại grant — cả hai chỉ chạy khi server vừa công nhận MỘT ngày
 * học mới (ledger `user_learning_streak_days` insertIgnore trả 1):
 *
 * <ul>
 *   <li><b>Thưởng duy trì</b>: mọi ngày nối chuỗi (current_streak sau
 *       advance &ge; 2) → +5 EXP + +5 Điểm Sử Ký.</li>
 *   <li><b>Thưởng mốc</b>: current_streak sau advance đạt đúng mốc
 *       3/7/14/30 → cộng THÊM lượng lớn tương ứng (15/30/60/120 EXP,
 *       10/25/50/100 Điểm). Mốc cộng dồn lên thưởng duy trì — ngày 3
 *       nhận 5+15 EXP, 5+10 Điểm.</li>
 * </ul>
 *
 * <p>Idempotency: cause_key deterministic theo (user, study_date, type,
 * bucket) → retry, replay Idempotency-Key, concurrent same-day, backfill
 * đều gặp UNIQUE(cause_key) + ON CONFLICT DO NOTHING. Ngày
 * SHIELD_PROTECTED không thưởng (user không học ngày đó).
 */
@Component
public class StreakRewardPolicy {

    /** EXP thưởng duy trì mỗi ngày nối chuỗi (từ ngày 2 trở đi). */
    public static final long DAILY_EXP = 5;
    /** Điểm Sử Ký thưởng duy trì mỗi ngày nối chuỗi. */
    public static final long DAILY_POINTS = 5;

    /**
     * Mốc chuỗi và bonus tương ứng — CỘNG THÊM trên thưởng duy trì.
     * {@code day} là giá trị current_streak sau advance.
     */
    public record Milestone(int day, long bonusExp, long bonusPoints) {
    }

    public static final List<Milestone> MILESTONES = List.of(
            new Milestone(3, 15, 10),
            new Milestone(7, 30, 25),
            new Milestone(14, 60, 50),
            new Milestone(30, 120, 100));

    /** cause_key duy nhất cho một (user, study_date, type, bucket). */
    public static String causeKey(UUID userId, LocalDate studyDate,
                                  String rewardType, String bucket) {
        return "STREAK:" + userId + ":" + studyDate + ":"
                + rewardType + ":" + bucket;
    }

    /**
     * Các bút toán cho một ngày học vừa được công nhận.
     *
     * @param currentStreak current_streak SAU advanceTo của ngày này
     * @return grants; rỗng khi current_streak &lt; 2 (ngày đầu / ngày
     *         reset — phạt đứt chuỗi là mất thu nhập, không trừ điểm)
     */
    public List<Grant> grantsFor(UUID userId, LocalDate studyDate,
                                 int currentStreak) {
        java.util.List<Grant> out = new java.util.ArrayList<>();
        if (currentStreak >= 2) {
            out.add(new Grant(RewardTransaction.TYPE_EXP, DAILY_EXP,
                    "Duy trì chuỗi ngày học", "DAILY"));
            out.add(new Grant(RewardTransaction.TYPE_HISTORY_POINTS,
                    DAILY_POINTS, "Duy trì chuỗi ngày học", "DAILY"));
        }
        for (Milestone m : MILESTONES) {
            if (m.day() == currentStreak) {
                out.add(new Grant(RewardTransaction.TYPE_EXP, m.bonusExp(),
                        "Đạt mốc chuỗi " + m.day() + " ngày",
                        "MILESTONE_" + m.day()));
                out.add(new Grant(RewardTransaction.TYPE_HISTORY_POINTS,
                        m.bonusPoints(), "Đạt mốc chuỗi " + m.day() + " ngày",
                        "MILESTONE_" + m.day()));
            }
        }
        return out;
    }

    /** Mốc chuỗi của current_streak này, null nếu không phải mốc. */
    public static Integer milestoneOf(int currentStreak) {
        for (Milestone m : MILESTONES) {
            if (m.day() == currentStreak) {
                return m.day();
            }
        }
        return null;
    }

    /** Một bút toán dự kiến ghi — attemptId gắn khi insert. */
    public record Grant(String rewardType, long amount, String reason,
                        String bucket) {
    }
}
