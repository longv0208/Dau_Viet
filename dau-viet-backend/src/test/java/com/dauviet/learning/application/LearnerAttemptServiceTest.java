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
     * es in ev; rc in rs; cer in cc. Re-submitting es must wipe rc + cer.
     */
    private static JsonNode snapshotThreeStage() {
        return json("""
                {"stages":[
                  {"id":"ev","type":"EVIDENCE","required":true,"activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["rs"]},
                  {"id":"rs","type":"REASONING","required":true,"activities":[
                    {"id":"rc","type":"REASONING_CONNECT","required":true}],
                   "nextStageIds":["cc"]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true}],
                   "nextStageIds":[]}]}
                """);
    }

    @Test
    void invalidateDependents_wipesLaterSiblingsAndDirectDescendants() {
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

        assertThat(state.isCompleted("rc")).isFalse();
        assertThat(state.isCompleted("cer")).isFalse();
        assertThat(state.outputs().containsKey("rc")).isFalse();
        assertThat(state.outputs().containsKey("cer")).isFalse();
        // Upstream activity itself is untouched
        assertThat(state.isCompleted("es")).isTrue();
        assertThat(state.outputs().containsKey("es")).isTrue();
    }

    @Test
    void invalidateDependents_doesNotCrossBeyondDepthOne() {
        // es -> rs -> cc: invalidating es wipes rc (direct descendant) but
        // cc is depth-2 — left alone so a mid-chain revise cannot cascade
        // a wipe across the whole attempt.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ev","type":"EVIDENCE","required":true,"activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["rs"]},
                  {"id":"rs","type":"REASONING","required":true,"activities":[
                    {"id":"rc","type":"REASONING_CONNECT","required":true}],
                   "nextStageIds":["cc"]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.markCompleted("es");
        state.markCompleted("rc");
        state.markCompleted("cer");
        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "es");
        assertThat(state.isCompleted("cer")).isTrue();
    }

    @Test
    void knowledgeScoreOf_usesGradedOutputsOverCompletionMarks() {
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        // es: graded partial score 0.5; rc: correct=true; cer: partsCorrect=3
        state.recordOutput("es", json("{\"score\":0.5}"));
        state.recordOutput("rc", json("{\"correct\":true}"));
        state.recordOutput("cer", json("{\"partsCorrect\":3,\"correct\":true}"));
        state.markCompleted("es");
        state.markCompleted("rc");
        state.markCompleted("cer");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(score).isNotNull();
        // mean of (0.5, 1.0, 1.0) * 100 = 83.33
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(83.0, 84.0);
    }

    @Test
    void knowledgeScoreOf_ungradedCompletionCountsFull() {
        SnapshotModel model = SnapshotModel.parse(snapshotThreeStage());
        AttemptState state = new AttemptState();
        // es exhausted with score 0.0; rc/cer completed without outputs
        state.recordOutput("es", json("{\"score\":0.0}"));
        state.markCompleted("rc");
        state.markCompleted("cer");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(66.0, 67.0);
    }

    @Test
    void knowledgeScoreOf_emptySnapshot_returnsZero() {
        JsonNode snap = json("{\"stages\":[]}");
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
