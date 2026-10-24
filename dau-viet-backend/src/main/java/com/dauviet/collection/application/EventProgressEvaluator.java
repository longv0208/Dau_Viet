package com.dauviet.collection.application;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Component;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.map.application.MapLocationUnlockQuery;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Đánh giá thuần trạng thái event của learner (GAME-04 §8/§9) — KHÔNG ghi
 * DB; recorder chịu trách nhiệm persist. Tái dùng
 * {@link MapLocationUnlockQuery#completedLessonIds} (completed trên lesson
 * logic, mọi version) để giữ một nguồn semantics cho "LESSON_COMPLETED".
 *
 * Quy tắc:
 *  - EVENT_COMPLETED: mọi required lesson có ≥1 attempt COMPLETED.
 *  - EVENT_MASTERED: đã completed + ≥1 required lesson CÓ graded activity +
 *    mọi required-lesson-có-graded đạt best knowledgeScore ≥ threshold.
 *    Lesson không có graded activity = NOT_ASSESSED — vẫn phải completed
 *    (đã nằm trong required set) nhưng không tính vào mastery.
 *  - Threshold null → event không xét mastered (không bao giờ mastered).
 */
@Component
public class EventProgressEvaluator {

    private final MapLocationUnlockQuery completedLessons;
    private final LessonResultRepository lessonResults;
    private final ObjectMapper mapper;

    public EventProgressEvaluator(MapLocationUnlockQuery completedLessons,
                                  LessonResultRepository lessonResults,
                                  ObjectMapper mapper) {
        this.completedLessons = completedLessons;
        this.lessonResults = lessonResults;
        this.mapper = mapper;
    }

    /** Kết quả đánh giá cho recorder/API. */
    public record Evaluation(
            boolean completed,
            boolean mastered,
            List<UUID> requiredLessonIds,
            Set<UUID> completedLessonIds,
            /** lessonId → trạng thái mastery per-lesson cho progress DTO. */
            Map<UUID, LessonMastery> perLesson) {
    }

    public enum LessonMastery {
        /** Lesson có graded activity và best score ≥ threshold. */
        MASTERED,
        /** Lesson có graded activity nhưng best score < threshold. */
        BELOW_THRESHOLD,
        /** Lesson không có graded activity — không đo được knowledge. */
        NOT_ASSESSED,
        /** Lesson chưa completed. */
        NOT_COMPLETED
    }

    /**
     * Đánh giá learner trên policy PUBLISHED. `requiredLessonIds` đọc từ
     * snapshot của policy — KHÔNG resolve lại lesson table (entitlement ghi
     * theo snapshot tại thời điểm đạt, EVT-04).
     */
    public Evaluation evaluate(UUID userId, EventCompletionPolicy policy) {
        List<UUID> required = policy.requiredLessonIds(mapper);
        if (required.isEmpty()) {
            return new Evaluation(false, false, List.of(), Set.of(), Map.of());
        }
        Set<UUID> done = completedLessons.completedLessonIds(userId, required);
        boolean completed = done.containsAll(required);

        Integer threshold = policy.getMasteryThreshold();
        Map<UUID, LessonMastery> perLesson = new HashMap<>();
        boolean mastered = false;
        if (threshold == null) {
            for (UUID l : required) {
                perLesson.put(l, done.contains(l)
                        ? LessonMastery.NOT_ASSESSED : LessonMastery.NOT_COMPLETED);
            }
        } else {
            Set<UUID> gradedLessons = done.isEmpty() ? Set.of()
                    : lessonResults.lessonsWithGradedActivity(userId, required);
            Map<UUID, BigDecimal> best = bestScores(userId, required);
            boolean hasGraded = false;
            boolean allAbove = true;
            for (UUID l : required) {
                if (!done.contains(l)) {
                    perLesson.put(l, LessonMastery.NOT_COMPLETED);
                    allAbove = false;
                    continue;
                }
                if (!gradedLessons.contains(l)) {
                    perLesson.put(l, LessonMastery.NOT_ASSESSED);
                    continue; // vẫn completed, không chặn mastery
                }
                hasGraded = true;
                BigDecimal score = best.getOrDefault(l, BigDecimal.ZERO);
                boolean pass = score
                        .compareTo(BigDecimal.valueOf(threshold)) >= 0;
                perLesson.put(l, pass
                        ? LessonMastery.MASTERED : LessonMastery.BELOW_THRESHOLD);
                if (!pass) allAbove = false;
            }
            mastered = completed && hasGraded && allAbove;
        }
        return new Evaluation(completed, mastered, required, done, perLesson);
    }

    private Map<UUID, BigDecimal> bestScores(UUID userId, List<UUID> required) {
        Map<UUID, BigDecimal> out = new HashMap<>();
        for (Object[] row : lessonResults.bestKnowledgeScoresByLesson(
                userId, required)) {
            out.put((UUID) row[0], (BigDecimal) row[1]);
        }
        return out;
    }
}
