package com.dauviet.reward.application;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.reward.domain.RewardTransaction;
import com.dauviet.reward.infrastructure.persistence.RewardTransactionRepository;

/**
 * Ghi thưởng server-authoritative (TASK-0023). Mọi grant chạy TRONG
 * transaction của complete()/backfill — attempt không được coi là hoàn
 * thành nếu thưởng không ghi được, và ngược lại. Idempotent ở tầng DB qua
 * UNIQUE(cause_key) + ON CONFLICT DO NOTHING: retry, concurrent complete,
 * replay Idempotency-Key, backfill — tất cả chỉ tạo đúng một bút toán.
 */
@Service
public class RewardGrantService {

    private static final Logger log =
            LoggerFactory.getLogger(RewardGrantService.class);

    private final RewardPolicy policy;
    private final RewardTransactionRepository rewards;
    private final LearnerAttemptRepository attempts;
    private final LessonResultRepository lessonResults;

    public RewardGrantService(RewardPolicy policy,
                              RewardTransactionRepository rewards,
                              LearnerAttemptRepository attempts,
                              LessonResultRepository lessonResults) {
        this.policy = policy;
        this.rewards = rewards;
        this.attempts = attempts;
        this.lessonResults = lessonResults;
    }

    /**
     * Thưởng lần hoàn thành đầu tiên của một bài. Gọi bên trong
     * doComplete() sau khi lesson_results.save — cùng transaction.
     * "First" xác định bằng DB: đếm attempt COMPLETED khác attempt này của
     * cùng (user, lesson) trước khi ghi; cause_key UNIQUE là backstop cuối
     * cùng nếu hai complete race trên hai version khác nhau.
     *
     * @return số bút toán thực sự ghi (0 = không phải lần đầu / đã grant)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int grantFirstCompletion(UUID userId, UUID lessonId,
                                    UUID attemptId) {
        if (!isFirstCompletion(userId, lessonId, attemptId)) {
            return 0;
        }
        int granted = 0;
        for (RewardPolicy.Grant g : policy.firstCompletionGrants(
                userId, lessonId, attemptId)) {
            granted += rewards.insertIgnore(userId, attemptId, g.rewardType(),
                    g.amount(), g.reason(), g.causeKey());
        }
        if (granted > 0) {
            log.info("reward granted user={} lesson={} attempt={} rows={}",
                    userId, lessonId, attemptId, granted);
        }
        return granted;
    }

    /**
     * Backfill idempotent cho các attempt COMPLETED trước khi tính năng ra
     * mắt: chỉ grant khi attempt đó là lần hoàn thành đầu tiên của bài
     * (không grant thưởng thừa cho lần học lại). Chạy lại bao nhiêu lần
     * cũng an toàn — cause_key chặn ghi trùng.
     *
     * @return số attempt được bổ sung thưởng (chưa có bút toán nào)
     */
    @Transactional(propagation = Propagation.REQUIRED)
    public int backfillFirstCompletions() {
        List<Object[]> rows = lessonResults.findCompletedAttemptsForBackfill();
        // "Lần đầu" của backfill = attempt COMPLETED sớm nhất mỗi (user,
        // lesson) — chỉ attempt đó nhận thưởng; các attempt sau của cùng
        // bài không được bổ sung. Sắp xếp theo completed_at ASC từ query.
        java.util.Set<String> claimedKeys = new java.util.HashSet<>();
        int filled = 0;
        for (Object[] row : rows) {
            UUID attemptId = (UUID) row[0];
            UUID userId = (UUID) row[1];
            UUID lessonId = (UUID) row[2];
            String key = userId + ":" + lessonId;
            // Attempt COMPLETED sớm nhất mỗi (user, lesson) chiếm slot ngay
            // khi gặp — kể cả khi nó đã có bút toán từ lần backfill trước,
            // để các attempt sau cùng bài không bao giờ được bổ sung.
            if (!claimedKeys.add(key)
                    || !rewards.findByLearnerAttemptId(attemptId).isEmpty()) {
                continue;
            }
            // Ghi thưởng trực tiếp: backfill không đi qua isFirstCompletion
            // vì check đó dựa vào "không còn attempt COMPLETED khác" — đúng
            // cho grant realtime nhưng sai khi đã có attempt sau cùng bài
            // hoàn thành trước khi backfill chạy. cause_key vẫn là backstop.
            for (RewardPolicy.Grant g : policy.firstCompletionGrants(
                    userId, lessonId, attemptId)) {
                rewards.insertIgnore(userId, attemptId, g.rewardType(),
                        g.amount(), g.reason(), g.causeKey());
            }
            filled++;
        }
        if (filled > 0) {
            log.info("reward backfill completed attempts={}", filled);
        }
        return filled;
    }

    /**
     * "Lần đầu" = không còn attempt COMPLETED nào khác của cùng (user,
     * lesson). Attempt đang xét đã markCompleted trước khi gọi nên tự nó
     * không được tính vào "khác". Vì complete() serialize trên
     * pessimistic lock của attempt + partial unique index
     * (user,version,IN_PROGRESS), hai attempt của CÙNG bài không thể
     * complete đồng thời trên cùng version; hai version khác nhau (sau
     * republish) race nhau thì cause_key vẫn chặn grant kép.
     */
    private boolean isFirstCompletion(UUID userId, UUID lessonId,
                                      UUID attemptId) {
        return attempts.countCompletedOthersForLesson(userId, lessonId,
                attemptId) == 0;
    }
}
