package com.dauviet.collection.api.dto;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

/**
 * Tiến độ event của learner hiện tại (GAME-04 §10). `status` precedence:
 * EVENT_MASTERED > EVENT_COMPLETED > IN_PROGRESS (policy tồn tại) >
 * NOT_CONFIGURED. `bestKnowledgeScore` null khi masteryStatus NOT_ASSESSED
 * hoặc lesson chưa completed — không lộ điểm bài không đo được.
 */
public record EventProgressResponse(
        UUID eventId,
        String status,
        Integer policyVersion,
        Integer requiredLessonsTotal,
        Integer requiredLessonsCompleted,
        boolean eventCompleted,
        boolean eventMastered,
        Integer masteryThreshold,
        List<RequiredLessonProgress> requiredLessons,
        int unlockedDossiersCount) {

    /** Một required lesson trong tiến độ event. */
    public record RequiredLessonProgress(
            UUID lessonId,
            String title,
            boolean completed,
            /** MASTERED | BELOW_THRESHOLD | NOT_ASSESSED | NOT_COMPLETED */
            String masteryStatus,
            BigDecimal bestKnowledgeScore) {
    }
}
