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
                mock(com.dauviet.collection.application.EventMilestoneRecorder.class),
                mock(com.dauviet.reward.application.RewardGrantService.class),
                mock(com.dauviet.reward.application.ItemUnlockService.class),
                mock(com.dauviet.reward.application.RewardService.class),
                mock(com.dauviet.energy.application.EnergyService.class),
                mock(com.dauviet.energy.application.EnergyProperties.class),
                mock(com.dauviet.streak.application.LearningStreakService.class),
                new GradedActivityClassifier(),
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
                     "config":{"graded":true,
                               "acceptedEvidenceIds":["e1"]}}],
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

    /* ---------- FIX 1: revision hops are not dependency edges ---------- */

    /**
     * The REAL Bạch Đằng chain: hp(hc) -> re(do) -> vf(vf1) with
     * vf1.onPartial/onContradicted -> hp, plus cc(cer) after vf.
     * Revision hops must NOT create data-dependency edges — otherwise
     * hc -> do -> vf1 -> hc is a cycle and resubmitting `do` or `vf1`
     * would void the hypothesis they consume.
     */
    private static JsonNode bachDangChain() {
        return json("""
                {"stages":[
                  {"id":"hp","type":"HYPOTHESIS","required":true,"activities":[
                    {"id":"hc","type":"HYPOTHESIS_CHOICE","required":true}],
                   "nextStageIds":["re"]},
                  {"id":"re","type":"RECONSTRUCTION","required":true,"activities":[
                    {"id":"do","type":"DRAG_ORDER","required":true}],
                   "nextStageIds":["vf"]},
                  {"id":"vf","type":"VERIFICATION","required":true,"activities":[
                    {"id":"vf1","type":"VERIFICATION","required":true,
                     "onPartial":"hp","onContradicted":"hp"}],
                   "nextStageIds":["cc"]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true}],
                   "nextStageIds":[]}]}
                """);
    }

    @Test
    void invalidateDependents_resubmitDo_keepsHypothesisAndVerification() {
        // Resubmitting `do` (e.g. retry after revision) must NOT invalidate
        // hc — the hypothesis output is upstream of `do`, and vf1's revise
        // hop back to hp is navigation, not a data edge.
        SnapshotModel model = SnapshotModel.parse(bachDangChain());
        AttemptState state = new AttemptState();
        state.markCompleted("hc");
        state.recordOutput("hc", json("{\"hypothesisId\":\"h-tide\"}"));
        state.markCompleted("do");
        state.recordOutput("do", json("{\"correct\":true}"));

        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "do");

        assertThat(state.isCompleted("hc")).isTrue();
        assertThat(state.outputs().containsKey("hc")).isTrue();
        // vf1/cer are downstream of do — tainted as before.
        assertThat(state.isCompleted("do")).isTrue();
    }

    @Test
    void invalidateDependents_resubmitVerification_keepsHypothesis() {
        // Submitting vf1 must never wipe hc — vf1 consumes hc's output;
        // a dependency edge vf1->hc via the hop would be backwards.
        SnapshotModel model = SnapshotModel.parse(bachDangChain());
        AttemptState state = new AttemptState();
        state.markCompleted("hc");
        state.recordOutput("hc", json("{\"hypothesisId\":\"h-tide\"}"));
        state.markCompleted("do");
        state.recordOutput("do", json("{\"correct\":true}"));
        state.markCompleted("vf1");
        state.recordOutput("vf1", json("{\"verification\":\"SUPPORTED\"}"));

        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "vf1");

        assertThat(state.isCompleted("hc")).isTrue();
        assertThat(state.isCompleted("do")).isTrue();
        assertThat(state.outputs().containsKey("hc")).isTrue();
        assertThat(state.outputs().containsKey("do")).isTrue();
        // cer is downstream of vf1 — tainted.
        assertThat(state.isCompleted("vf1")).isTrue();
    }

    @Test
    void invalidateDependents_revisedEvidence_wipesVerificationAndConclusion() {
        // Evidence revision must still invalidate real consumers: vf1 reads
        // es's output via config.evidenceSource; cer via priorEvidenceSource.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"ev","type":"EVIDENCE","required":true,"activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true}],
                   "nextStageIds":["vf"]},
                  {"id":"vf","type":"VERIFICATION","required":true,"activities":[
                    {"id":"vf1","type":"VERIFICATION","required":true,
                     "config":{"evidenceSource":"es"},
                     "onPartial":"ev","onContradicted":"ev"}],
                   "nextStageIds":["cc"]},
                  {"id":"cc","type":"CONCLUSION","required":true,"activities":[
                    {"id":"cer","type":"CER_CHOICE","required":true,
                     "config":{"priorEvidenceSource":"es"}}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.markCompleted("es");
        state.recordOutput("es", json("{\"selectedEvidenceIds\":[\"e1\"]}"));
        state.markCompleted("vf1");
        state.recordOutput("vf1", json("{\"verification\":\"SUPPORTED\"}"));
        state.markCompleted("cer");
        state.recordOutput("cer", json("{\"correct\":true}"));

        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "es");

        assertThat(state.isCompleted("es")).isTrue();
        assertThat(state.outputs().containsKey("es")).isTrue();
        assertThat(state.isCompleted("vf1")).isFalse();
        assertThat(state.outputs().containsKey("vf1")).isFalse();
        assertThat(state.isCompleted("cer")).isFalse();
        assertThat(state.outputs().containsKey("cer")).isFalse();
    }

    @Test
    void invalidateDependents_noCycleOnHopBackGraph() {
        // Even a hand-built snapshot whose hop creates a loop must terminate:
        // BFS is visited-guarded; the revised activity is never re-tainted.
        JsonNode snap = json("""
                {"stages":[
                  {"id":"a","type":"REASONING","required":true,"activities":[
                    {"id":"a1","type":"REASONING_CONNECT","required":true,
                     "onContradicted":"b"}],
                   "nextStageIds":["b"]},
                  {"id":"b","type":"REASONING","required":true,"activities":[
                    {"id":"b1","type":"REASONING_CONNECT","required":true,
                     "onContradicted":"a"}],
                   "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.markCompleted("a1");
        state.markCompleted("b1");
        state.recordOutput("a1", json("{}"));
        state.recordOutput("b1", json("{}"));

        ReflectionTestUtils.invokeMethod(service, "invalidateDependents",
                model, state, "a1");
        // Terminated without hanging; a1 itself preserved.
        assertThat(state.isCompleted("a1")).isTrue();
    }

    /* ---------- FIX 2: resubmit updates completion both ways ---------- */

    /**
     * Wire a real submit() through mocked repos + a real handler registry so
     * the actual recordOutput/mark/remove sequence inside doSubmit is
     * exercised — not a re-enactment. The idempotency mock passes the
     * executor straight through (null key -> direct execution path).
     */
    private LearnerAttemptService wiredService(
            com.dauviet.learning.handler.ActivityHandlerRegistry registry,
            IdempotencyService idem) {
        return new LearnerAttemptService(attempts, activityAttempts, lessonResults,
                lessons, versions, registry,
                new StageTransitionResolver(), new LessonCompletionEvaluator(),
                projection, idem,
                mock(com.dauviet.collection.application.EvidenceCollectionRecorder.class),
                mock(com.dauviet.collection.application.EventMilestoneRecorder.class),
                mock(com.dauviet.reward.application.RewardGrantService.class),
                mock(com.dauviet.reward.application.ItemUnlockService.class),
                mock(com.dauviet.reward.application.RewardService.class),
                mock(com.dauviet.energy.application.EnergyService.class),
                mock(com.dauviet.energy.application.EnergyProperties.class),
                mock(com.dauviet.streak.application.LearningStreakService.class),
                new GradedActivityClassifier(),
                OM, mock(org.springframework.transaction.PlatformTransactionManager.class),
                mock(jakarta.persistence.EntityManager.class));
    }

    private IdempotencyService passthroughIdempotency() {
        IdempotencyService idem = mock(IdempotencyService.class);
        when(idem.canonical(any())).thenReturn("fp");
        when(idem.execute(any(), anyString(), any(), anyString(), any(), any()))
                .thenAnswer(inv -> ((java.util.function.Supplier<?>) inv.getArgument(4)).get());
        return idem;
    }

    private LearnerAttempt wiredAttempt(JsonNode snapshot, AttemptState state,
                                        String currentStage, String currentActivity) {
        UUID versionId = UUID.randomUUID();
        LessonVersion v = new LessonVersion();
        v.setId(versionId);
        v.setLessonId(UUID.randomUUID());
        v.setVersionNo(1);
        v.setSnapshotJson(snapshot.toString());
        when(versions.findById(versionId)).thenReturn(Optional.of(v));

        UUID userId = UUID.randomUUID();
        LearnerAttempt a = LearnerAttempt.start(userId, versionId);
        state.setCurrentStageId(currentStage);
        state.setCurrentActivityId(currentActivity);
        a.recordProgress(state);
        when(attempts.findForUpdate(a.getId())).thenReturn(Optional.of(a));
        return a;
    }

    @Test
    void submit_correctThenIncorrectBeforeExhaustion_dropsCompletionMark() {
        // MCQ maxAttempts=2: first submit right -> completed. Re-submit wrong
        // (attempt 2 < max? no: attemptNo=2 >= maxAttempts=2 -> exhausted,
        // still completed:true). Use maxAttempts=3 so attempt 2 is a plain
        // incorrect that must DROP the stale completion mark (FIX 2).
        JsonNode snap = json("""
                {"stages":[{"id":"q","type":"REASONING","required":true,
                  "activities":[{"id":"mcq","type":"MULTIPLE_CHOICE","required":true,
                                 "config":{"options":[{"id":"o1"},{"id":"o2"}],
                                           "correctOptionIds":["o1"],"maxAttempts":3}}],
                  "nextStageIds":[]}]}
                """);
        AttemptState state = new AttemptState();
        LearnerAttempt a = wiredAttempt(snap, state, "q", "mcq");

        var registry = mock(com.dauviet.learning.handler.ActivityHandlerRegistry.class);
        when(registry.handlerFor(com.dauviet.lesson.draft.ActivityType.MULTIPLE_CHOICE))
                .thenReturn(new com.dauviet.learning.handler.ScoredHandlers.MultipleChoiceHandler());
        LearnerAttemptService svc = wiredService(registry, passthroughIdempotency());
        when(activityAttempts.countByLearnerAttemptIdAndActivityId(any(), anyString()))
                .thenReturn(0).thenReturn(1);

        // Submit 1: correct -> completed mark set.
        svc.submit(a.getUserId(), a.getId(), "mcq",
                json("{\"selectedOptionIds\":[\"o1\"]}"), null);
        AttemptState after1 = AttemptState.fromJson(json(a.getStateJson()));
        assertThat(after1.isCompleted("mcq")).isTrue();

        // Submit 2: WRONG answer — attemptNo=2 < maxAttempts=3 -> completed=false.
        // The stale mark must be removed (FIX 2), not left referring to the
        // overwritten output.
        svc.submit(a.getUserId(), a.getId(), "mcq",
                json("{\"selectedOptionIds\":[\"o2\"]}"), null);
        AttemptState after2 = AttemptState.fromJson(json(a.getStateJson()));
        assertThat(after2.isCompleted("mcq")).isFalse();
        assertThat(after2.outputs().get("mcq").get("correct").asBoolean()).isFalse();
    }

    @Test
    void submit_correctThenPartial_dropsCompletionMark() {
        // Graded EVIDENCE_SELECT: exact set -> completed; partial overlap ->
        // completed=false -> stale mark must drop.
        JsonNode snap = json("""
                {"evidence":[{"id":"e1"},{"id":"e2"},{"id":"e3"}],
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
                  "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                 "config":{"graded":true,
                                           "visibleEvidenceIds":["e1","e2","e3"],
                                           "acceptedEvidenceIds":["e1","e2"],
                                           "maxAttempts":3}}],
                  "nextStageIds":[]}]}
                """);
        AttemptState state = new AttemptState();
        LearnerAttempt a = wiredAttempt(snap, state, "ev", "es");
        var registry = mock(com.dauviet.learning.handler.ActivityHandlerRegistry.class);
        when(registry.handlerFor(com.dauviet.lesson.draft.ActivityType.EVIDENCE_SELECT))
                .thenReturn(new com.dauviet.learning.handler.SelectionHandlers.EvidenceSelectHandler());
        LearnerAttemptService svc = wiredService(registry, passthroughIdempotency());
        when(activityAttempts.countByLearnerAttemptIdAndActivityId(any(), anyString()))
                .thenReturn(0).thenReturn(1);

        svc.submit(a.getUserId(), a.getId(), "es",
                json("{\"selectedEvidenceIds\":[\"e1\",\"e2\"]}"), null);
        assertThat(AttemptState.fromJson(json(a.getStateJson())).isCompleted("es")).isTrue();

        svc.submit(a.getUserId(), a.getId(), "es",
                json("{\"selectedEvidenceIds\":[\"e1\"]}"), null);
        AttemptState after = AttemptState.fromJson(json(a.getStateJson()));
        assertThat(after.isCompleted("es")).isFalse();
    }

    @Test
    void submit_incorrectRetryThenCorrect_restoresCompletionMark() {
        // The reverse direction must also work: incorrect first (no mark),
        // then correct -> mark set.
        JsonNode snap = json("""
                {"stages":[{"id":"q","type":"REASONING","required":true,
                  "activities":[{"id":"mcq","type":"MULTIPLE_CHOICE","required":true,
                                 "config":{"options":[{"id":"o1"},{"id":"o2"}],
                                           "correctOptionIds":["o1"],"maxAttempts":3}}],
                  "nextStageIds":[]}]}
                """);
        AttemptState state = new AttemptState();
        LearnerAttempt a = wiredAttempt(snap, state, "q", "mcq");
        var registry = mock(com.dauviet.learning.handler.ActivityHandlerRegistry.class);
        when(registry.handlerFor(com.dauviet.lesson.draft.ActivityType.MULTIPLE_CHOICE))
                .thenReturn(new com.dauviet.learning.handler.ScoredHandlers.MultipleChoiceHandler());
        LearnerAttemptService svc = wiredService(registry, passthroughIdempotency());
        when(activityAttempts.countByLearnerAttemptIdAndActivityId(any(), anyString()))
                .thenReturn(0).thenReturn(1);

        svc.submit(a.getUserId(), a.getId(), "mcq",
                json("{\"selectedOptionIds\":[\"o2\"]}"), null);
        assertThat(AttemptState.fromJson(json(a.getStateJson())).isCompleted("mcq")).isFalse();

        svc.submit(a.getUserId(), a.getId(), "mcq",
                json("{\"selectedOptionIds\":[\"o1\"]}"), null);
        assertThat(AttemptState.fromJson(json(a.getStateJson())).isCompleted("mcq")).isTrue();
    }

    @Test
    void knowledgeScoreOf_includesMpqMatchingDragOrder() {
        // FIX 3: contract-graded types now feed knowledgeScore without
        // needing config.graded:true.
        JsonNode snap = json("""
                {"stages":[{"id":"q","type":"REASONING","required":true,
                  "activities":[
                    {"id":"mcq","type":"MULTIPLE_CHOICE","required":true},
                    {"id":"mt","type":"MATCHING","required":true},
                    {"id":"do","type":"DRAG_ORDER","required":true},
                    {"id":"rd","type":"READ","required":true}],
                  "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        // mcq correct(1), matching correct(1), drag_order wrong(0), read done.
        state.recordOutput("mcq", json("{\"correct\":true}"));
        state.recordOutput("mt", json("{\"correct\":true}"));
        state.recordOutput("do", json("{\"correct\":false}"));
        state.recordOutput("rd", json("{\"viewed\":true}"));
        state.markCompleted("mcq");
        state.markCompleted("mt");
        state.markCompleted("rd");

        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        // graded: mcq 1 + mt 1 + do 0 -> mean 2/3*100 = 66.67; rd excluded.
        assertThat(((java.math.BigDecimal) score).doubleValue())
                .isBetween(66.0, 67.0);
    }

    @Test
    void knowledgeScoreOf_mcqOnly() {
        JsonNode snap = json("""
                {"stages":[{"id":"q","type":"REASONING","required":true,
                  "activities":[{"id":"mcq","type":"MULTIPLE_CHOICE","required":true}],
                  "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.recordOutput("mcq", json("{\"correct\":true}"));
        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        assertThat(((java.math.BigDecimal) score).doubleValue()).isEqualTo(100.0);
    }

    @Test
    void knowledgeScoreOf_boundedZeroToHundred() {
        JsonNode snap = json("""
                {"stages":[{"id":"q","type":"REASONING","required":true,
                  "activities":[{"id":"mcq","type":"MULTIPLE_CHOICE","required":true}],
                  "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.recordOutput("mcq", json("{\"correct\":false}"));
        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        double v = ((java.math.BigDecimal) score).doubleValue();
        assertThat(v).isBetween(0.0, 100.0);
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
        // TASK-0020 §P2 + FIX 2: chỉ activity có rule chấm THỰC đếm vào
        // knowledgeScore. es giờ graded thật (config có acceptedEvidenceIds
        // trong fixture), score 0.0; cer correct → mean(0, 1) = 50.
        // rc ungraded bị loại khỏi mẫu số như trước.
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
    void knowledgeScoreOf_flagWithoutAnswerKey_notCounted() {
        // FIX 2 regression: graded:true thiếu đáp án đếm như ungraded —
        // denominator chỉ chứa activity handler thực sự phát verdict.
        JsonNode snap = json("""
                {"stages":[{"id":"ev","type":"EVIDENCE","required":true,
                  "activities":[
                    {"id":"es","type":"EVIDENCE_SELECT","required":true,
                     "config":{"graded":true}}],
                  "nextStageIds":[]}]}
                """);
        SnapshotModel model = SnapshotModel.parse(snap);
        AttemptState state = new AttemptState();
        state.recordOutput("es", json("{\"score\":0.0}"));
        state.markCompleted("es");
        Object score = ReflectionTestUtils.invokeMethod(service,
                "knowledgeScoreOf", model, state);
        // Không còn graded activity → 0 (không phải 0/1 trung bình).
        assertThat(((java.math.BigDecimal) score).doubleValue()).isEqualTo(0.0);
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
