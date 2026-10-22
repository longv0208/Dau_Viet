package com.dauviet.reward.application;

import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.reward.domain.RewardTransaction;

/**
 * Chính sách thưởng tập trung (TASK-0023): một nơi duy nhất quyết định
 * LOẠI thưởng + SỐ LƯỢNG cho mỗi sự kiện gameplay. MVP chỉ có first
 * completion — không level, không premium, không shop, không thưởng theo
 * score/mastery (score trong lesson_results là % hoạt động bắt buộc đã
 * làm xong, không phải điểm đánh giá năng lực).
 *
 * <p>Giá trị đọc từ cấu hình `dauviet.rewards.*` (application.yml) nên
 * chỉnh định lượng không cần sửa code; mặc định theo brief: 100 EXP +
 * 50 Điểm Lịch sử cho lần hoàn thành đầu tiên mỗi bài.
 */
@Component
public class RewardPolicy {

    private final long expFirstCompletion;
    private final long historyPointsFirstCompletion;

    public RewardPolicy(
            @org.springframework.beans.factory.annotation.Value(
                    "${dauviet.rewards.first-completion.exp:100}")
            long expFirstCompletion,
            @org.springframework.beans.factory.annotation.Value(
                    "${dauviet.rewards.first-completion.history-points:50}")
            long historyPointsFirstCompletion) {
        this.expFirstCompletion = expFirstCompletion;
        this.historyPointsFirstCompletion = historyPointsFirstCompletion;
    }

    /**
     * cause_key deterministic: một (user, lesson, type) chỉ grant đúng một
     * lần — republish (version mới), attempt mới, retry, backfill đều gặp
     * ON CONFLICT DO NOTHING ở DB.
     */
    public static String causeKey(UUID userId, UUID lessonId, String type) {
        return "LESSON_FIRST_COMPLETE:" + userId + ":" + lessonId + ":" + type;
    }

    /** Các bút toán cho lần hoàn thành đầu tiên một bài. */
    public List<Grant> firstCompletionGrants(UUID userId, UUID lessonId,
                                             UUID attemptId) {
        return List.of(
                new Grant(RewardTransaction.TYPE_EXP, expFirstCompletion,
                        "Hoàn thành lần đầu một bài học",
                        causeKey(userId, lessonId, RewardTransaction.TYPE_EXP)),
                new Grant(RewardTransaction.TYPE_HISTORY_POINTS,
                        historyPointsFirstCompletion,
                        "Hoàn thành lần đầu một bài học",
                        causeKey(userId, lessonId,
                                RewardTransaction.TYPE_HISTORY_POINTS)));
    }

    /** Một bút toán dự kiến ghi — attemptId gắn khi insert. */
    public record Grant(String rewardType, long amount, String reason,
                        String causeKey) {
    }
}
