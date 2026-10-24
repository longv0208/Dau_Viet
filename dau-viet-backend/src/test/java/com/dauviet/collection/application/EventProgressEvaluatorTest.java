package com.dauviet.collection.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.collection.domain.EventCompletionPolicy;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.map.application.MapLocationUnlockQuery;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Unit test matrix cho EventProgressEvaluator (GAME-04 §8/§9) — mock
 * MapLocationUnlockQuery + LessonResultRepository, không cần DB. Khóa chặt:
 * NOT_ASSESSED cho lesson không chấm, boundary threshold, hasGraded=false,
 * best-score-cao-hơn-threshold, và threshold null.
 */
class EventProgressEvaluatorTest {

    private final MapLocationUnlockQuery completed = mock(MapLocationUnlockQuery.class);
    private final LessonResultRepository results = mock(LessonResultRepository.class);
    private final EventProgressEvaluator eval =
            new EventProgressEvaluator(completed, results, new ObjectMapper());

    private final UUID userId = UUID.randomUUID();
    private final UUID ev = UUID.randomUUID();
    private final UUID l1 = UUID.randomUUID();
    private final UUID l2 = UUID.randomUUID();
    private final UUID l3 = UUID.randomUUID();

    /** Policy PUBLISHED mock — required list + threshold tuỳ chọn. */
    private EventCompletionPolicy policy(List<UUID> required,
                                         Integer threshold) {
        EventCompletionPolicy p = mock(EventCompletionPolicy.class);
        when(p.getEventId()).thenReturn(ev);
        when(p.getPolicyVersion()).thenReturn(1);
        when(p.getStatus()).thenReturn(EventCompletionPolicy.Status.PUBLISHED);
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < required.size(); i++) {
            if (i > 0) sb.append(',');
            sb.append('"').append(required.get(i)).append('"');
        }
        String json = sb.append(']').toString();
        when(p.getRequiredLessonIdsJson()).thenReturn(json);
        when(p.requiredLessonIds(org.mockito.ArgumentMatchers.any(ObjectMapper.class)))
                .thenReturn(required);
        when(p.getMasteryThreshold()).thenReturn(threshold);
        return p;
    }

    private void completedAre(UUID... ids) {
        when(completed.completedLessonIds(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(Set.of(ids));
    }

    private void gradedLessons(UUID... ids) {
        when(results.lessonsWithGradedActivity(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.anyList()))
                .thenReturn(Set.of(ids));
    }

    private void bestScores(Map<UUID, Double> scores) {
        java.util.List<Object[]> rows = new java.util.ArrayList<>();
        for (var e : scores.entrySet()) {
            rows.add(new Object[]{e.getKey(), BigDecimal.valueOf(e.getValue())});
        }
        when(results.bestKnowledgeScoresByLesson(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.anyList()))
                .thenReturn(rows);
    }

    @Test
    void emptyRequired_notCompleted_notMastered() {
        EventCompletionPolicy p = policy(List.of(), 70);
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isFalse();
        assertThat(r.mastered()).isFalse();
        assertThat(r.requiredLessonIds()).isEmpty();
        assertThat(r.perLesson()).isEmpty();
        verifyNoInteractions(completed);
    }

    @Test
    void thresholdNull_neverMastered_completedFlagStillSet() {
        EventCompletionPolicy p = policy(List.of(l1, l2), null);
        completedAre(l1, l2);
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isFalse();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.NOT_ASSESSED);
        assertThat(r.perLesson().get(l2))
                .isEqualTo(EventProgressEvaluator.LessonMastery.NOT_ASSESSED);
    }

    @Test
    void partiallyCompleted_notCompleted_notMastered() {
        EventCompletionPolicy p = policy(List.of(l1, l2), 70);
        completedAre(l1); // l2 chưa xong
        gradedLessons(l1);
        bestScores(Map.of(l1, 80.0));
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isFalse();
        assertThat(r.mastered()).isFalse();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.MASTERED);
        assertThat(r.perLesson().get(l2))
                .isEqualTo(EventProgressEvaluator.LessonMastery.NOT_COMPLETED);
    }

    @Test
    void allCompleted_noGraded_completedButNotMastered() {
        EventCompletionPolicy p = policy(List.of(l1, l2), 70);
        completedAre(l1, l2);
        gradedLessons(); // không lesson nào graded
        bestScores(Map.of());
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isFalse(); // hasGraded = false
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.NOT_ASSESSED);
    }

    @Test
    void allCompleted_gradedBelowThreshold_notMastered() {
        EventCompletionPolicy p = policy(List.of(l1), 70);
        completedAre(l1);
        gradedLessons(l1);
        bestScores(Map.of(l1, 60.0));
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isFalse();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.BELOW_THRESHOLD);
    }

    @Test
    void allCompleted_boundaryScore_mastered() {
        EventCompletionPolicy p = policy(List.of(l1), 70);
        completedAre(l1);
        gradedLessons(l1);
        bestScores(Map.of(l1, 70.0)); // đúng bằng threshold → pass
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isTrue();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.MASTERED);
    }

    @Test
    void mixGradedAndNotAssessed_masteredWhenAllGradedPass() {
        // l1 graded pass, l2 completed nhưng không graded → event mastered.
        EventCompletionPolicy p = policy(List.of(l1, l2), 70);
        completedAre(l1, l2);
        gradedLessons(l1);
        bestScores(Map.of(l1, 85.0));
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isTrue();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.MASTERED);
        assertThat(r.perLesson().get(l2))
                .isEqualTo(EventProgressEvaluator.LessonMastery.NOT_ASSESSED);
    }

    @Test
    void bestScoreAcrossAttempts_picksMax() {
        // Hai attempt trên l1: 40 và 90 — lấy best (90) ≥ threshold → mastered.
        EventCompletionPolicy p = policy(List.of(l1), 70);
        completedAre(l1);
        gradedLessons(l1);
        java.util.List<Object[]> rows = new java.util.ArrayList<>();
        rows.add(new Object[]{l1, BigDecimal.valueOf(90)});
        when(results.bestKnowledgeScoresByLesson(
                org.mockito.ArgumentMatchers.eq(userId),
                org.mockito.ArgumentMatchers.anyList()))
                .thenReturn(rows);
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.mastered()).isTrue();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.MASTERED);
    }

    @Test
    void noCompleted_lessonsNotCompleted() {
        EventCompletionPolicy p = policy(List.of(l1, l2), 70);
        completedAre(); // rỗng
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isFalse();
        assertThat(r.mastered()).isFalse();
        assertThat(r.perLesson().values()).containsOnly(
                EventProgressEvaluator.LessonMastery.NOT_COMPLETED);
    }

    @Test
    void completedViaGradedButNoScoreRow_treatedAsZero() {
        // Lesson có graded activity nhưng không có lesson_results row
        // (edge: score null → coi 0 → below threshold).
        EventCompletionPolicy p = policy(List.of(l1), 70);
        completedAre(l1);
        gradedLessons(l1);
        bestScores(Map.of()); // không row nào
        EventProgressEvaluator.Evaluation r = eval.evaluate(userId, p);
        assertThat(r.completed()).isTrue();
        assertThat(r.mastered()).isFalse();
        assertThat(r.perLesson().get(l1))
                .isEqualTo(EventProgressEvaluator.LessonMastery.BELOW_THRESHOLD);
    }
}
