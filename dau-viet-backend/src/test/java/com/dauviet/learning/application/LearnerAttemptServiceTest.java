package com.dauviet.learning.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.domain.LearnerAttempt;
import com.dauviet.learning.infrastructure.persistence.ActivityAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LearnerAttemptRepository;
import com.dauviet.learning.infrastructure.persistence.LessonResultRepository;
import com.dauviet.learning.resolver.LessonCompletionEvaluator;
import com.dauviet.learning.resolver.StageTransitionResolver;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.dauviet.lesson.application.LearnerProjectionService;
import com.dauviet.lesson.domain.Lesson;
import com.dauviet.lesson.domain.LessonVersion;
import com.dauviet.lesson.infrastructure.persistence.LessonRepository;
import com.dauviet.lesson.infrastructure.persistence.LessonVersionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Learning Flow 2.0: bounded dependent-output invalidation + knowledgeScore.
 * Unit-level — no Spring context, no DB.
 */
class LearnerAttemptServiceTest {

    private static final ObjectMapper OM = new ObjectMapper();

    private LearnerAttemptRepository attempts;
    private ActivityAttemptRepository activityAttempts;
    private LessonResultRepository lessonResults;
    private LessonRepository lessons;
    private LessonVersionRepository versions;
    private LearnerAttemptService service;
    private LearnerProjectionService projection;

    @BeforeEach
    void setUp() {
        attempts = mock(LearnerAttemptRepository.class);
        activityAttempts = mock(ActivityAttemptRepository.class);
        lessonResults = mock(LessonResultRepository.class);
        lessons = mock(LessonRepository.class);
        versions = mock(LessonVersionRepository.class);
        projection = new LearnerProjectionService();
        service = new LearnerAttemptService(attempts, activityAttempts, lessonResults,
                lessons, versions, mock(com.dauviet.learning.handler.ActivityHandlerRegistry.class),
                new StageTransitionResolver(), new LessonCompletionEvaluator(),
                projection, mock(IdempotencyService.class),
                mock(com.dauviet.collection.application.EvidenceCollectionRecorder.class),
                mock(com.dauviet.reward.application.RewardGrantService.class),
                mock(com.dauviet.reward.application.ItemUnlockService.class),
                mock(com.dauviet.reward.application.RewardService.class),
                OM, mock(org.springframework.transaction.PlatformTransactionManager.class),
                mock(jakarta.persistence.EntityManager.class));
    }

    private static JsonNode json(String s) {
        try { return OM.readTree(s); } catch (Exception e) { throw new IllegalStateException(e); }
    }

    /**
     * Snapshot: ev(required) -> rs(required) -> cc(required).
     * es in ev; rc in rs; cer in cc with config.priorEvidenceSource:"es".
     * Re-submitting es now transitively wipes rc AND cer — the conclusion
     * consumed the revised evidence output, so keeping it would leave stale
     * credit behind (TASK-0020 §P1 replaces the old depth-1 bound).
     * "graded":true on es makes it count toward knowledgeScore.
     */
    private static JsonNode snapshotThreeStage() {
        return json("""
                {"stages":[
                  {"id":"ev","type":"EVIDENCE","required":true,"activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true,
                     "config":{"graded":true}}],
                   "nextStageIds":["rs"]},
                  {"id":"rs","type":"REASONING","required":true,"activities":[
                    {"id":"rc","type":"REASONING_CONNECT","required":true}],
                   "nextStageIds":["cc"]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true,
                     "config":{"priorEvidenceSource":"es"}}],
                   "nextStageIds":[]}]}
                """);
    }

    @Test
    void invalidateDependents_transitivelyWipesDownstreamConsumers() {
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        state.markCompleted("es");
        state.recordOutput("es", json("{\"selectedEvidenceIds\":[\"e1\"]}"));
        state.markCompleted("rc");
        state.recordOutput("rc", json("{\"correct\":true}"));
        state.markCompleted("cer");
        state.recordOutput("cer", json("{\"partsCorrect\":3}"));

        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "es");

        // Both downstream consumers lose outputs + completion marks —
        // depth-1 and depth-2 alike (transitive dependency invalidation).
        assertThat(state.isCompleted("rc")).isFalse();
        assertThat(state.outputs().containsKey("rc")).isFalse();
        assertThat(state.isCompleted("cer")).isFalse();
        assertThat(state.outputs().containsKey("cer")).isFalse();
        // Upstream activity itself is untouched
        assertThat(state.isCompleted("es")).isTrue();
        assertThat(state.outputs().containsKey("es")).isTrue();
    }

    @Test
    void invalidateDependents_taintsDownstreamOrder_preservesSource() {
        // Parallel branch: opt stage hangs off ev (sibling of the rs->cc
        // chain). Ordered propagation taints everything reachable after es —
        // a conservative bound: the runtime cannot prove a later output did
        // not observe the revised one via priorOutputs.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ev","type":"EVIDENCE","required":true,"activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["rs","opt"]},
                  {"id":"rs","type":"REASONING","required":true,"activities":[
                    {"id":"rc","type":"REASONING_CONNECT","required":true}],
                   "nextStageIds":["cc"]},
                  {"id":"opt","type":"REFLECTION","required":false,"activities":[
                    {"id":"rf1","type":"REFLECTION_PROMPT"}],
                   "nextStageIds":[]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.markCompleted("es");
        state.recordOutput("es", json("{\"selectedEvidenceIds\":[\"e1\"]}"));
        state.markCompleted("rc");
        state.markCompleted("cer");
        state.recordOutput("rf1", json("{\"text\":\"x\"}"));
        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "es");
        // Consumer chain tainted.
        assertThat(state.isCompleted("rc")).isFalse();
        assertThat(state.isCompleted("cer")).isFalse();
        // Ordered propagation also voids rf1 — it ran AFTER es, so the
        // attempt flow cannot prove its context is unchanged (conservative
        // taint). The revised activity's own output is preserved.
        assertThat(state.outputs().containsKey("rf1")).isFalse();
        assertThat(state.outputs().containsKey("es")).isTrue();
    }

    @Test
    void knowledgeScoreOf_usesGradedOutputsOverCompletionMarks() {
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        // es: graded partial score 0.5; cer: correct combo (score 1.0).
        // rc is ungraded — it never enters the denominator.
        state.recordOutput("es", json("{\"score\":0.5}"));
        state.recordOutput("rc", json("{\"correct\":true}"));
        state.recordOutput("cer", json("{\"partsCorrect\":3,\"correct\":true,\"score\":1.0}"));
        state.markCompleted("es");
        state.markCompleted("rc");
        state.markCompleted("cer");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(score).isNotNull();
        // mean of (0.5, 1.0) over graded-only = 75.00
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(74.0, 76.0);
    }

    @Test
    void knowledgeScoreOf_ungradedCompletionDoesNotCount() {
        // TASK-0020 §P2: only activities with a real grading rule feed
        // knowledgeScore. rc is ungraded -> dropped from the denominator;
        // es score 0.0 and cer correct -> mean(0,1)*100 = 50.
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        state.recordOutput("es", json("{\"score\":0.0}"));
        state.recordOutput("cer", json("{\"correct\":true}"));
        state.markCompleted("rc");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(49.0, 51.0);
    }

    @Test
    void knowledgeScoreOf_noGradedActivities_returnsZero() {
        // A lesson whose required work is all ungraded (READ, count-only
        // EVIDENCE_SELECT) has no measured knowledge — report 0 explicitly
        // rather than confusing completion with correctness.
        JsonNode snap = json("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                  "activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true}],
                  "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.markCompleted("es");
        state.recordOutput("es", json("{\"selectedEvidenceIds\":[\"e1\"]}"));
        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue()).isEqualTo(0.0);
    }

    @Test
    void knowledgeScoreOf_exhaustedIncorrectKeepsZeroCredit() {
        // Exhausted-for-progress cer (correct:false, score 0) contributes 0 —
        // completing the attempt never converts failed work into credit.
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        state.recordOutput("es", json("{\"score\":1.0}"));
        state.recordOutput("cer", json("{\"correct\":false,\"score\":0.0,\"exhausted\":true}"));
        state.markCompleted("es");
        state.markCompleted("cer");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(49.0, 51.0);
    }

    @Test
    void knowledgeScoreOf_noRequiredActivities_returnsZero() {
        // stage exists but carries no required activity -> score base is empty
        JsonNode snap = json("""
                {"stages":[{"id":"s1","type":"CONTEXT","activities":[
                    {"id":"opt","type":"READ"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue()).isEqualTo(0.0);
    }

    @Test
    void resultJsonOf_includesKnowledgeScore() {
        LearnerAttempt a = LearnerAttempt.start(UUID.randomUUID(), UUID.randomUUID());
        a.recordProgress(new AttemptState());
        var progress = new com.dauviet.learning.api.dto.AttemptProgressResponse.Progress(2, 2);
        var verdict = new com.dauviet.learning.contract.LessonCompletion(
                true, com.dauviet.learning.contract.LessonCompletion.ALL_REQUIRED_STAGES,
                json("{\"ok\":true}"));
        String json = ReflectionTestUtils.invokeMethod(service, "resultJsonOf",
                a, verdict, progress,
                new java.math.BigDecimal("100.00"), new java.math.BigDecimal("75.50"));
        assertThat(json).contains("knowledgeScore").contains("75.5");
    }
}
