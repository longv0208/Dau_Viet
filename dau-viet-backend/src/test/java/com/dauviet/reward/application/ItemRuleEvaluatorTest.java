package com.dauviet.reward.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.collection.infrastructure.persistence.UserEventProgressRepository;
import com.dauviet.collection.infrastructure.persistence.UserEvidenceRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.reward.application.ItemCondition.Leaf;
import com.dauviet.reward.application.ItemCondition.LeafType;

/**
 * Unit matrix cho {@link ItemRuleEvaluator} (GAME-05) — mock context repos,
 * không cần DB. Khoá chặt 14 trường hợp leaf + ALL/ANY + UNSUPPORTED:
 * mỗi LeafType đúng ngữ nghĩa, không loại nào "luôn đúng" hay "luôn sai".
 */
class ItemRuleEvaluatorTest {

    private final UserEvidenceRepository userEvidence =
            mock(UserEvidenceRepository.class);
    private final UserEventProgressRepository eventProgress =
            mock(UserEventProgressRepository.class);
    private final LearnerAttemptRepository attempts =
            mock(LearnerAttemptRepository.class);
    private final LessonResultRepository lessonResults =
            mock(LessonResultRepository.class);
    private final ItemRuleEvaluator eval = new ItemRuleEvaluator();

    private final UUID userId = UUID.randomUUID();
    private final UUID eventId = UUID.randomUUID();
    private final UUID lessonId = UUID.randomUUID();
    private final UUID e1 = UUID.randomUUID();
    private final UUID e2 = UUID.randomUUID();
    private final UUID e3 = UUID.randomUUID();

    private ItemRuleEvaluationContext ctx() {
        return new ItemRuleEvaluationContext(userId, userEvidence,
                eventProgress, attempts, lessonResults);
    }

    private Leaf leaf(LeafType type, UUID eventId, UUID lessonId,
                      List<UUID> evidenceIds, Integer threshold,
                      Integer level) {
        return new Leaf(type, eventId, lessonId, evidenceIds, threshold,
                level);
    }

    /* ---------- evidence/collection ---------- */

    @Test
    void collectionCount_usesGlobalDistinctEvidence() {
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(5L);
        Leaf l = leaf(LeafType.COLLECTION_COUNT, null, null, null, 5, null);
        assertThat(eval.satisfied(l, ctx())).isTrue();
        // 4 < 5 → fail; count global KHÔNG scope event (D2 gap report).
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(4L);
        assertThat(eval.satisfied(l, ctx())).isFalse();
    }

    @Test
    void eventEvidenceCount_scopedToEvent_notGlobal() {
        // QA-16: 7 evidence global nhưng chỉ 2 thuộc event → 3-threshold
        // không đạt. Context phải gọi countDistinctEvidenceForEvent.
        when(userEvidence.countDistinctEvidenceForEvent(userId, eventId))
                .thenReturn(2L);
        Leaf l = leaf(LeafType.EVENT_EVIDENCE_COUNT, eventId, null, null,
                3, null);
        assertThat(eval.satisfied(l, ctx())).isFalse();
        when(userEvidence.countDistinctEvidenceForEvent(userId, eventId))
                .thenReturn(3L);
        assertThat(eval.satisfied(l, ctx())).isTrue();
    }

    @Test
    void specificEvidenceSet_requiresAllSubset() {
        when(userEvidence.collectedEvidenceIds(userId))
                .thenReturn(Set.of(e1, e2));
        Leaf l = leaf(LeafType.SPECIFIC_EVIDENCE_SET, eventId, null,
                List.of(e1, e2), null, null);
        assertThat(eval.satisfied(l, ctx())).isTrue();
        // Thiếu e3 → fail.
        Leaf missing = leaf(LeafType.SPECIFIC_EVIDENCE_SET, eventId, null,
                List.of(e1, e3), null, null);
        assertThat(eval.satisfied(missing, ctx())).isFalse();
    }

    /* ---------- lesson ---------- */

    @Test
    void lessonCompleted_checksCompletedSet() {
        when(attempts.findDistinctCompletedLessonIds(userId))
                .thenReturn(Set.of(lessonId));
        Leaf l = leaf(LeafType.LESSON_COMPLETED, null, lessonId, null,
                null, null);
        assertThat(eval.satisfied(l, ctx())).isTrue();
        Leaf other = leaf(LeafType.LESSON_COMPLETED, null,
                UUID.randomUUID(), null, null, null);
        assertThat(eval.satisfied(other, ctx())).isFalse();
    }

    @Test
    void lessonCount_countsDistinctCompleted() {
        when(attempts.countDistinctCompletedLessons(userId)).thenReturn(5L);
        Leaf l = leaf(LeafType.LESSON_COUNT, null, null, null, 5, null);
        assertThat(eval.satisfied(l, ctx())).isTrue();
        when(attempts.countDistinctCompletedLessons(userId)).thenReturn(4L);
        assertThat(eval.satisfied(l, ctx())).isFalse();
    }

    @Test
    void lessonMastered_bestScoreVsThreshold() {
        when(lessonResults.bestKnowledgeScoreByLesson(userId, lessonId))
                .thenReturn(BigDecimal.valueOf(70));
        Leaf l = leaf(LeafType.LESSON_MASTERED, null, lessonId, null, 70,
                null);
        assertThat(eval.satisfied(l, ctx())).isTrue(); // boundary đạt
        when(lessonResults.bestKnowledgeScoreByLesson(userId, lessonId))
                .thenReturn(BigDecimal.valueOf(69.9));
        ItemRuleEvaluationContext ctx2 = new ItemRuleEvaluationContext(
                userId, userEvidence, eventProgress, attempts,
                lessonResults);
        assertThat(eval.satisfied(l, ctx2)).isFalse();
        // Chưa có result → false, không ném.
        when(lessonResults.bestKnowledgeScoreByLesson(userId, lessonId))
                .thenReturn(null);
        ItemRuleEvaluationContext ctx3 = new ItemRuleEvaluationContext(
                userId, userEvidence, eventProgress, attempts,
                lessonResults);
        assertThat(eval.satisfied(l, ctx3)).isFalse();
    }

    /* ---------- event milestones ---------- */

    @Test
    void eventCompletedAndMastered_readLedger_neverRecompute() {
        when(eventProgress.exists(userId, eventId, "EVENT_COMPLETED"))
                .thenReturn(true);
        when(eventProgress.exists(userId, eventId, "EVENT_MASTERED"))
                .thenReturn(false);
        Leaf c = leaf(LeafType.EVENT_COMPLETED, eventId, null, null, null,
                null);
        Leaf m = leaf(LeafType.EVENT_MASTERED, eventId, null, null, null,
                null);
        ItemRuleEvaluationContext ctx = ctx();
        assertThat(eval.satisfied(c, ctx)).isTrue();
        assertThat(eval.satisfied(m, ctx)).isFalse();
    }

    @Test
    void totalEventsMilestones_countDistinctEvents() {
        when(eventProgress.countDistinctEventsByMilestone(userId,
                "EVENT_COMPLETED")).thenReturn(2L);
        when(eventProgress.countDistinctEventsByMilestone(userId,
                "EVENT_MASTERED")).thenReturn(1L);
        Leaf c2 = leaf(LeafType.TOTAL_EVENTS_COMPLETED, null, null, null,
                2, null);
        Leaf m2 = leaf(LeafType.TOTAL_EVENTS_MASTERED, null, null, null,
                2, null);
        ItemRuleEvaluationContext ctx = ctx();
        assertThat(eval.satisfied(c2, ctx)).isTrue();
        assertThat(eval.satisfied(m2, ctx)).isFalse();
    }

    /* ---------- unsupported ---------- */

    @Test
    void levelAtLeast_neverSatisfied_marksUnsupported() {
        Leaf l = leaf(LeafType.LEVEL_AT_LEAST, null, null, null, null, 5);
        ItemRuleEvaluator.Evaluation ev = eval.evaluate(l, ctx());
        assertThat(ev.satisfied()).isFalse();
        assertThat(ev.root().status()).isEqualTo("UNSUPPORTED");
    }

    /* ---------- operators ---------- */

    @Test
    void allOperator_requiresEveryChild() {
        when(attempts.countDistinctCompletedLessons(userId)).thenReturn(2L);
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(1L);
        ItemCondition all = new ItemCondition.All(List.of(
                leaf(LeafType.LESSON_COUNT, null, null, null, 2, null),
                leaf(LeafType.COLLECTION_COUNT, null, null, null, 2, null)));
        assertThat(eval.satisfied(all, ctx())).isFalse();
        // Cả hai đạt → true.
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(3L);
        assertThat(eval.satisfied(all, ctx())).isTrue();
    }

    @Test
    void anyOperator_oneSatisfiedEnough() {
        when(attempts.countDistinctCompletedLessons(userId)).thenReturn(0L);
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(9L);
        ItemCondition any = new ItemCondition.Any(List.of(
                leaf(LeafType.LESSON_COUNT, null, null, null, 2, null),
                leaf(LeafType.COLLECTION_COUNT, null, null, null, 2, null)));
        ItemRuleEvaluator.Evaluation ev = eval.evaluate(any, ctx());
        assertThat(ev.satisfied()).isTrue();
        // Per-branch status: leaf 1 PENDING, leaf 2 SATISFIED.
        assertThat(ev.root().children().get(0).satisfied()).isFalse();
        assertThat(ev.root().children().get(1).satisfied()).isTrue();
        assertThat(ev.root().children().get(0).status())
                .isEqualTo("PENDING");
    }

    @Test
    void unsupportedLeafInAny_doesNotForceFailNorPass() {
        // ANY(LEVEL_AT_LEAST, COLLECTION_COUNT(2)): LEVEL_AT_LEAST không
        // tính đạt, nhưng ANY vẫn có thể đạt qua leaf kia.
        when(userEvidence.countDistinctEvidence(userId)).thenReturn(2L);
        ItemCondition any = new ItemCondition.Any(List.of(
                leaf(LeafType.LEVEL_AT_LEAST, null, null, null, null, 5),
                leaf(LeafType.COLLECTION_COUNT, null, null, null, 2, null)));
        assertThat(eval.satisfied(any, ctx())).isTrue();
        // ALL: unsupported leaf phá hoại toàn cụm — không bao giờ đạt.
        ItemCondition all = new ItemCondition.All(List.of(
                leaf(LeafType.LEVEL_AT_LEAST, null, null, null, null, 5),
                leaf(LeafType.COLLECTION_COUNT, null, null, null, 2, null)));
        assertThat(eval.satisfied(all, ctx())).isFalse();
    }

    /* ---------- status tree for client ---------- */

    @Test
    void statusTree_carriesCurrentRequiredDescriptions() {
        when(userEvidence.countDistinctEvidenceForEvent(userId, eventId))
                .thenReturn(2L);
        Leaf l = leaf(LeafType.EVENT_EVIDENCE_COUNT, eventId, null, null,
                3, null);
        ItemRuleEvaluator.Evaluation ev = eval.evaluate(l, ctx());
        assertThat(ev.root().current()).isEqualTo(2L);
        assertThat(ev.root().required()).isEqualTo(3L);
        assertThat(ev.root().status()).isEqualTo("PENDING");
        assertThat(ev.root().description()).contains("bằng chứng");
    }
}
