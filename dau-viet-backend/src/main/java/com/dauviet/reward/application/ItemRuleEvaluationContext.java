package com.dauviet.reward.application;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;

/**
 * Batch/cache per-request cho evaluator (GAME-05): một lần đánh giá item
 * không được gây N+1 — mọi số liệu (evidence count, lesson count, milestone
 * map, best knowledge score…) load lười MỘT LẦN rồi tái dùng cho mọi leaf
 * của cùng user. KHÔNG cache xuyên request — evaluator chạy trong tx của
 * submit/complete nên phải thấy ghi vừa flush.
 */
public class ItemRuleEvaluationContext {

    private final UUID userId;
    private final UserEvidenceRepository userEvidence;
    private final UserEventProgressRepository eventProgress;
    private final LearnerAttemptRepository attempts;
    private final LessonResultRepository lessonResults;

    private Long globalEvidenceCount;
    private Long completedLessonCount;
    private final Map<String, Boolean> milestoneCache = new HashMap<>();
    private final Map<UUID, Long> eventEvidenceCounts = new HashMap<>();
    private final Map<UUID, BigDecimal> bestScoreCache = new HashMap<>();
    private Set<UUID> completedLessonIds;
    private Set<UUID> collectedEvidenceIds;
    private Long totalEventsCompleted;
    private Long totalEventsMastered;

    public ItemRuleEvaluationContext(UUID userId,
            UserEvidenceRepository userEvidence,
            UserEventProgressRepository eventProgress,
            LearnerAttemptRepository attempts,
            LessonResultRepository lessonResults) {
        this.userId = userId;
        this.userEvidence = userEvidence;
        this.eventProgress = eventProgress;
        this.attempts = attempts;
        this.lessonResults = lessonResults;
    }

    /** Số evidence KHÁC NHAU learner đã sưu tầm (toàn cục — COLLECTION_COUNT). */
    public long globalEvidenceCount() {
        if (globalEvidenceCount == null) {
            globalEvidenceCount = userEvidence.countDistinctEvidence(userId);
        }
        return globalEvidenceCount;
    }

    /** Số lesson KHÁC NHAU learner đã complete (mọi version). */
    public long completedLessonCount() {
        if (completedLessonCount == null) {
            completedLessonCount =
                    attempts.countDistinctCompletedLessons(userId);
        }
        return completedLessonCount;
    }

    /**
     * EVENT_EVIDENCE_COUNT: đếm DISTINCT evidence_id của user THUỘC event —
     * bắt buộc scope (QA-16: evidence event B không được mở item event A).
     */
    public long evidenceCountForEvent(UUID eventId) {
        return eventEvidenceCounts.computeIfAbsent(eventId,
                id -> userEvidence.countDistinctEvidenceForEvent(userId, id));
    }

    /** SPECIFIC_EVIDENCE_SET: tập evidence_id learner đã collect. */
    public Set<UUID> collectedEvidenceIds() {
        if (collectedEvidenceIds == null) {
            collectedEvidenceIds = userEvidence.collectedEvidenceIds(userId);
        }
        return collectedEvidenceIds;
    }

    /** Lesson đã hoàn thành (bất kỳ version) — set cache một lần. */
    public boolean lessonCompleted(UUID lessonId) {
        if (completedLessonIds == null) {
            completedLessonIds =
                    attempts.findDistinctCompletedLessonIds(userId);
        }
        return completedLessonIds.contains(lessonId);
    }

    /**
     * LESSON_MASTERED: best knowledgeScore của learner trên lesson đạt
     * `threshold` (điểm tuyệt đối theo knowledgeScore — mastery event
     * được định nghĩa bởi policy, leaf này nhận threshold riêng khai báo).
     */
    public boolean lessonMastered(UUID lessonId, int threshold) {
        BigDecimal best = bestScoreCache.computeIfAbsent(lessonId, id ->
                lessonResults.bestKnowledgeScoreByLesson(userId, id));
        if (best == null) return false;
        return best.compareTo(BigDecimal.valueOf(threshold)) >= 0;
    }

    /** Best score thô — phục vụ current/progress trả client. */
    public BigDecimal bestScore(UUID lessonId) {
        return bestScoreCache.computeIfAbsent(lessonId, id ->
                lessonResults.bestKnowledgeScoreByLesson(userId, id));
    }

    /** Milestone đã ghi trong user_event_progress (GAME-04 ledger). */
    public boolean milestone(UUID eventId, String milestone) {
        return milestoneCache.computeIfAbsent(eventId + "|" + milestone,
                k -> eventProgress.exists(userId, eventId, milestone));
    }

    /** Số event khác nhau đã ghi một milestone (TOTAL_EVENTS_*). */
    public long totalMilestone(String milestone) {
        if ("EVENT_COMPLETED".equals(milestone)) {
            if (totalEventsCompleted == null) {
                totalEventsCompleted = eventProgress
                        .countDistinctEventsByMilestone(userId, milestone);
            }
            return totalEventsCompleted;
        }
        if (totalEventsMastered == null) {
            totalEventsMastered = eventProgress
                    .countDistinctEventsByMilestone(userId, milestone);
        }
        return totalEventsMastered;
    }
}
