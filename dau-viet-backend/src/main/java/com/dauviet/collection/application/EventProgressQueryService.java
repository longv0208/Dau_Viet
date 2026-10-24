package com.dauviet.collection.application;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.collection.api.dto.EventProgressResponse;
import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.collection.domain.UserEventProgress;
import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;

/**
 * Compose progress DTO cho GET /me/events/{id}/progress (GAME-04 §10) +
 * reconcile-on-read: attempt COMPLETED trước khi policy tồn tại vẫn được
 * ghi milestone lần đầu đọc tiến độ — cùng đường evaluator/recorder nên
 * idempotent tuyệt đối (EVT-06).
 *
 * Không readOnly: reconcile có thể ghi. Không 404 khi event thiếu —
 * controller check existsById trước; service này thuần learner-scoped.
 */
@Service
public class EventProgressQueryService {

    private final EventCompletionPolicyService policyService;
    private final EventProgressEvaluator evaluator;
    private final EventMilestoneRecorder recorder;
    private final UserEventProgressRepository progress;
    private final LessonResultRepository lessonResults;
    private final LessonRepository lessons;

    public EventProgressQueryService(EventCompletionPolicyService policyService,
            EventProgressEvaluator evaluator,
            EventMilestoneRecorder recorder,
            UserEventProgressRepository progress,
            LessonResultRepository lessonResults,
            LessonRepository lessons) {
        this.policyService = policyService;
        this.evaluator = evaluator;
        this.recorder = recorder;
        this.progress = progress;
        this.lessonResults = lessonResults;
        this.lessons = lessons;
    }

    @Transactional(propagation = Propagation.REQUIRED)
    public EventProgressResponse progressOf(UUID userId, UUID eventId) {
        var policyOpt = policyService.publishedPolicyOf(eventId);
        if (policyOpt.isEmpty()) {
            return new EventProgressResponse(eventId, "NOT_CONFIGURED",
                    null, 0, 0, false, false, null, List.of(),
                    (int) progress.countUnlockedDossiersForEvent(userId, eventId),
                    null);
        }
        EventCompletionPolicy policy = policyOpt.get();

        // FIX 3: reconcile luôn qua recorder (idempotent) — kể cả khi đã có
        // EVENT_COMPLETED để fan-out dossier admin vừa publish (FIX 4).
        recorder.recordIfEarned(userId, eventId);

        EventProgressEvaluator.Evaluation ev = evaluator.evaluate(userId, policy);
        boolean completed = ev.completed() || progress.exists(userId, eventId,
                UserEventProgress.Milestone.EVENT_COMPLETED.name());
        boolean mastered = ev.mastered() || progress.exists(userId, eventId,
                UserEventProgress.Milestone.EVENT_MASTERED.name());
        String status = mastered ? "EVENT_MASTERED"
                : completed ? "EVENT_COMPLETED" : "IN_PROGRESS";

        Map<UUID, String> titles = lessonTitles(ev.requiredLessonIds());
        Map<UUID, BigDecimal> best = bestScores(userId, ev.requiredLessonIds());
        List<EventProgressResponse.RequiredLessonProgress> lessonDtos =
                ev.requiredLessonIds().stream().map(lessonId -> {
                    var m = ev.perLesson().getOrDefault(lessonId,
                            EventProgressEvaluator.LessonMastery.NOT_COMPLETED);
                    BigDecimal score = (m == EventProgressEvaluator.LessonMastery.MASTERED
                            || m == EventProgressEvaluator.LessonMastery.BELOW_THRESHOLD)
                            ? best.get(lessonId) : null;
                    return new EventProgressResponse.RequiredLessonProgress(
                            lessonId, titles.get(lessonId),
                            ev.completedLessonIds().contains(lessonId),
                            m.name(), score);
                }).collect(Collectors.toList());

        int unlocked = (int) progress.countUnlockedDossiersForEvent(userId, eventId);
        // FIX 7: policyVersion mà milestone được cấp theo — UI phân biệt
        // "đã completed policy cũ" vs "đang theo policy hiện tại".
        Integer earnedVersion = progress.earnedPolicyVersion(userId, eventId);
        return new EventProgressResponse(eventId, status,
                policy.getPolicyVersion(),
                ev.requiredLessonIds().size(), ev.completedLessonIds().size(),
                completed, mastered, policy.getMasteryThreshold(),
                lessonDtos, unlocked, earnedVersion);
    }

    private Map<UUID, BigDecimal> bestScores(UUID userId, List<UUID> required) {
        Map<UUID, BigDecimal> out = new java.util.HashMap<>();
        for (Object[] row : lessonResults.bestKnowledgeScoresByLesson(
                userId, required)) {
            out.put((UUID) row[0], (BigDecimal) row[1]);
        }
        return out;
    }

    private Map<UUID, String> lessonTitles(List<UUID> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        return lessons.findAllById(ids).stream()
                .collect(Collectors.toMap(Lesson::getId, Lesson::getTitle));
    }
}
