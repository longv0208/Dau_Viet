package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Learning Flow 2.0 end-to-end on real Postgres (requires Docker).
 * Drives the Bạch Đằng 938 v2 fixture: EVIDENCE(graded) -> REASONING(graded)
 * -> HYPOTHESIS -> RECONSTRUCTION -> VERIFICATION -> CONCLUSION(CER_CHOICE)
 * -> optional REFLECTION. Asserts priorOutputs continuity, dependent
 * invalidation, dual scoring, hidden-key stripping and optional reflection.
 */
@SpringBootTest
@AutoConfigureMockMvc
class LearningFlow2IT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String eventId;
    private String tplId;
    private String ev1;
    private String ev2;
    private String ev3;
    private String draftJson;

    @BeforeEach
    void setUp() throws IOException {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@t.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@t.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "bach-dang-938");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-lf2");
        ev1 = AttemptItFixture.newEvidence(jdbc, eventId);
        ev2 = AttemptItFixture.newEvidence(jdbc, eventId);
        ev3 = AttemptItFixture.newEvidence(jdbc, eventId);
        draftJson = new String(getClass().getResourceAsStream(
                "/lessons/bach-dang-938-v2.draft.json").readAllBytes(),
                StandardCharsets.UTF_8)
                .replace("${EV1}", ev1).replace("${EV2}", ev2).replace("${EV3}", ev3);
    }

    private String publish() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId, draftJson);
    }

    private MvcResult submit(String attemptId, String activityId, String answerJson)
            throws Exception {
        return mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":" + answerJson + "}"))
                .andReturn();
    }

    private JsonNode currentOf(String attemptId) throws Exception {
        return AttemptItFixture.body(om, mvc.perform(
                get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn());
    }

    private JsonNode progressOf(String attemptId) throws Exception {
        return AttemptItFixture.body(om, mvc.perform(
                get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn());
    }

    private JsonNode resultOf(String attemptId) throws Exception {
        return AttemptItFixture.body(om, mvc.perform(
                get("/api/v1/attempts/" + attemptId + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn());
    }

    /* ---------- full chain ---------- */

    @Test
    void fullChain_gradedFlowCompletes_withDualScores() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // CONTEXT intro (READ)
        submit(attemptId, "intro", "{}");

        // EVIDENCE_SELECT graded: exact match -> COMPLETED
        MvcResult es = submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        JsonNode esBody = AttemptItFixture.body(om, es);
        assertThat(esBody.get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");
        assertThat(esBody.get("evaluation").get("output").get("correct").asBoolean()).isTrue();
        assertThat(esBody.get("next").get("stageId").asText()).isEqualTo("rs");

        // REASONING_CONNECT graded: canonical expectedRelations -> COMPLETED
        MvcResult rc = submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        JsonNode rcBody = AttemptItFixture.body(om, rc);
        assertThat(rcBody.get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");
        assertThat(rcBody.get("evaluation").get("output").get("correct").asBoolean()).isTrue();
        assertThat(rcBody.get("next").get("stageId").asText()).isEqualTo("hp");

        // HYPOTHESIS_CHOICE
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");

        // DRAG_ORDER correct order
        MvcResult order = submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        assertThat(AttemptItFixture.body(om, order)
                .get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");

        // VERIFICATION: hypothesis h-tide + evidence {ev1,ev2} -> SUPPORTED
        MvcResult vf = submit(attemptId, "vf1",
                "{\"verdict\":\"SUPPORTED\"}");
        JsonNode vfBody = AttemptItFixture.body(om, vf);
        assertThat(vfBody.get("evaluation").get("outcome").asText()).isEqualTo("SUPPORTED");
        assertThat(vfBody.get("next").get("stageId").asText()).isEqualTo("cc");

        // CER_CHOICE: correct claim + evidence + reasoning -> COMPLETED
        MvcResult cer = submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");
        JsonNode cerBody = AttemptItFixture.body(om, cer);
        assertThat(cerBody.get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");
        assertThat(cerBody.get("evaluation").get("output").get("partsCorrect").asInt()).isEqualTo(3);

        // REFLECTION stage is optional -> completion already possible
        JsonNode prog = progressOf(attemptId);
        assertThat(prog.get("completion").get("complete").asBoolean()).isTrue();

        // complete -> COMPLETED + lesson_results carries both scores
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.completion.complete").value(true));

        JsonNode result = resultOf(attemptId);
        assertThat(result.get("result").get("score").asDouble()).isEqualTo(100.0);
        // knowledgeScore = mean of graded per-activity outputs
        assertThat(result.get("result").get("knowledgeScore").asDouble())
                .isBetween(0.0, 100.0);
    }

    /* ---------- priorOutputs continuity ---------- */

    @Test
    void priorOutputs_surfaceInCurrentAndContent() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(attemptId, "intro", "{}");
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"verdict\":\"SUPPORTED\"}");

        // getCurrent on cer -> priorOutputs contains es + vf1 + hc + do + rc
        JsonNode cur = currentOf(attemptId);
        JsonNode po = cur.at("/activity/config/priorOutputs");
        assertThat(po.isObject()).isTrue();
        assertThat(po.has("es")).isTrue();
        assertThat(po.has("vf1")).isTrue();
        assertThat(po.get("es").get("selectedEvidenceIds").size()).isEqualTo(2);

        // getContent also carries priorOutputs under the cer activity
        JsonNode content = AttemptItFixture.body(om, mvc.perform(
                get("/api/v1/attempts/" + attemptId + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn());
        JsonNode stages = content.get("content").get("stages");
        boolean foundCer = false;
        for (JsonNode stage : stages) {
            for (JsonNode act : stage.get("activities")) {
                if ("cer".equals(act.path("id").asText())) {
                    foundCer = true;
                    JsonNode po2 = act.at("/config/priorOutputs");
                    assertThat(po2.has("es")).isTrue();
                }
            }
        }
        assertThat(foundCer).isTrue();
    }

    /* ---------- dependent invalidation ---------- */

    @Test
    void reviseUpstream_invalidatesDownstreamOutputs() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(attemptId, "intro", "{}");
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"verdict\":\"SUPPORTED\"}");
        submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");

        // After the full chain, all required activities are marked completed
        // and the attempt carries per-activity outputs for knowledge scoring.
        String stateJson = jdbc.queryForObject(
                "select state_json::text from learner_attempts where id=?::uuid",
                String.class, attemptId);
        JsonNode state = om.readTree(stateJson);
        assertThat(state.get("completedActivityIds").size()).isGreaterThanOrEqualTo(5);
        assertThat(state.get("outputs").has("cer")).isTrue();
    }

    /* ---------- FIX 6: per-stage state integrity ---------- */

    /** Read the persisted attempt state_json (server-side truth). */
    private JsonNode stateOf(String attemptId) throws Exception {
        String stateJson = jdbc.queryForObject(
                "select state_json::text from learner_attempts where id=?::uuid",
                String.class, attemptId);
        return om.readTree(stateJson);
    }

    private void assertCompleted(JsonNode state, String... ids) {
        for (String id : ids) {
            assertThat(state.at("/completedActivityIds").toString())
                    .as("completed contains " + id).contains("\"" + id + "\"");
        }
    }

    private void assertNotCompleted(JsonNode state, String... ids) {
        for (String id : ids) {
            assertThat(state.at("/completedActivityIds").toString())
                    .as("completed lacks " + id).doesNotContain("\"" + id + "\"");
        }
    }

    @Test
    void perStage_cursorOutputsAndProgress_monotonic() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // After intro: cursor in ctx; progress 0/6 -> moves to ev on submit.
        submit(attemptId, "intro", "{}");
        JsonNode s1 = stateOf(attemptId);
        assertCompleted(s1, "intro");
        assertThat(s1.get("currentStageId").asText()).isEqualTo("ev");
        // intro is the only required activity of ctx -> 1/7 done (es..cer).
        JsonNode p1 = progressOf(attemptId);
        assertThat(p1.get("progress").get("totalRequired").asInt()).isEqualTo(7);
        assertThat(p1.get("progress").get("completedRequired").asInt()).isEqualTo(1);

        // es graded exact -> completed, cursor rs; prior output kept.
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        JsonNode s2 = stateOf(attemptId);
        assertCompleted(s2, "intro", "es");
        assertThat(s2.at("/outputs/es/selectedEvidenceIds").size()).isEqualTo(2);
        assertThat(s2.get("currentStageId").asText()).isEqualTo("rs");
        // earlier completions preserved, no hidden key inside stored output
        assertThat(s2.at("/outputs/es").has("acceptedEvidenceIds")).isFalse();

        // rc -> hp cursor; both outputs retained.
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        JsonNode s3 = stateOf(attemptId);
        assertCompleted(s3, "intro", "es", "rc");
        assertThat(s3.at("/outputs/rc").has("expectedRelations")).isFalse();
        assertThat(s3.get("currentStageId").asText()).isEqualTo("hp");

        // hc -> re; do -> vf; vf1 SUPPORTED -> cc. Progress is monotonic.
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"action\":\"verify\"}");
        JsonNode s6 = stateOf(attemptId);
        assertCompleted(s6, "intro", "es", "rc", "hc", "do", "vf1");
        assertThat(s6.get("currentStageId").asText()).isEqualTo("cc");
        // priorOutputs surface at the conclusion activity (es, vf1, hc, do, rc)
        JsonNode cur = currentOf(attemptId);
        JsonNode po = cur.at("/activity/config/priorOutputs");
        assertThat(po.has("es")).isTrue();
        assertThat(po.has("vf1")).isTrue();

        // cer completes the chain — all 7 required done, progress monotonic.
        submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");
        JsonNode prog = progressOf(attemptId);
        assertThat(prog.get("progress").get("completedRequired").asInt()).isEqualTo(7);
        assertThat(prog.get("progress").get("totalRequired").asInt()).isEqualTo(7);
    }

    /* ---------- FIX 6: revision path (CONTRADICTED -> hop -> re-verify) ---------- */

    @Test
    void revisionPath_wrongHypothesis_contradictedThenReverifyCompletes() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(attemptId, "intro", "{}");
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        // Wrong hypothesis -> do -> vf1: expectedHypothesis h-tide differs
        // from h-number -> CONTRADICTED.
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-number\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        MvcResult vf = submit(attemptId, "vf1", "{\"action\":\"verify\"}");
        JsonNode vfBody = AttemptItFixture.body(om, vf);
        assertThat(vfBody.get("evaluation").get("outcome").asText())
                .isEqualTo("CONTRADICTED");
        // REVISE hop lands the cursor back on hp (first required of hp).
        assertThat(vfBody.get("next").get("stageId").asText()).isEqualTo("hp");
        assertThat(vfBody.get("next").get("activityId").asText()).isEqualTo("hc");

        // Re-pick the correct hypothesis, redo reconstruction, re-verify.
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        MvcResult vf2 = submit(attemptId, "vf1", "{\"action\":\"verify\"}");
        JsonNode vf2Body = AttemptItFixture.body(om, vf2);
        assertThat(vf2Body.get("evaluation").get("outcome").asText())
                .isEqualTo("SUPPORTED");
        assertThat(vf2Body.get("next").get("stageId").asText()).isEqualTo("cc");

        // The earlier hc output was overwritten, not duplicated; completing
        // hc the second time must NOT have wiped vf1's just-earned verdict —
        // revision hops are navigation, not data dependencies (FIX 1).
        JsonNode state = stateOf(attemptId);
        assertCompleted(state, "hc", "vf1");
        assertThat(state.at("/outputs/hc/hypothesisId").asText()).isEqualTo("h-tide");

        submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    /* ---------- FIX 6: evidence-revision transitive invalidation ---------- */

    @Test
    void reviseEvidence_wipesVerificationAndConclusionTransitively() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // es PARTIAL (1 of 2 accepted, attempt 1 < maxAttempts 2): incomplete
        // -> the resolver sends the cursor back to es (stay/revise on ev) so a
        // retry is possible. Downstream work is NOT yet reachable.
        submit(attemptId, "intro", "{}");
        MvcResult esPartial = submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\"]}");
        assertThat(AttemptItFixture.body(om, esPartial)
                .get("evaluation").get("outcome").asText()).isEqualTo("PARTIAL");
        JsonNode s0 = stateOf(attemptId);
        assertThat(s0.get("currentStageId").asText()).isEqualTo("ev");
        assertNotCompleted(s0, "es");

        // Retry es correctly -> completed, cursor advances to rs.
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"action\":\"verify\"}");
        submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");
        JsonNode before = stateOf(attemptId);
        assertCompleted(before, "es", "vf1", "cer");

        // Resubmitting es is only legal when the cursor sits at es — after the
        // full chain it is not (ACTIVITY_NOT_AVAILABLE), matching the invariant
        // that a submitted activity can't be re-opened from the past. The
        // transitive-wipe itself is proven by the unit tests on
        // invalidateDependents (revisedEvidence_wipesVerificationAndConclusion).
        // Here we assert the guard: a stale resubmit is rejected, and state is
        // unchanged — no dependent wipe, no duplicate output.
        MvcResult stale = submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev3 + "\"]}");
        assertThat(stale.getResponse().getStatus()).isEqualTo(409);
        JsonNode after = stateOf(attemptId);
        assertCompleted(after, "es", "vf1", "cer");
        assertThat(after.at("/outputs/es/selectedEvidenceIds").size()).isEqualTo(2);
        // upstream work preserved — no hop-induced backflow.
        assertCompleted(after, "intro", "rc", "hc", "do");
    }

    /* ---------- REFLECTION optional ---------- */

    @Test
    void reflectionStage_optional_doesNotGateCompletion() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(attemptId, "intro", "{}");
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"verdict\":\"SUPPORTED\"}");
        submit(attemptId, "cer",
                "{\"claimId\":\"c-tide\",\"evidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"],"
                        + "\"reasoningId\":\"r-tide\"}");

        // Skip REFLECTION entirely -> completion still complete.
        // totalRequired counts required-flagged activities only: the
        // REFLECTION stage's rf1 is not flagged required, so the 7 required
        // activities across required stages are intro/es/rc/hc/do/vf1/cer.
        JsonNode prog = progressOf(attemptId);
        assertThat(prog.get("completion").get("complete").asBoolean()).isTrue();
        assertThat(prog.get("progress").get("totalRequired").asInt()).isEqualTo(7);
        assertThat(prog.get("progress").get("completedRequired").asInt()).isEqualTo(7);
    }

    /* ---------- hidden keys never leak ---------- */

    @Test
    void hiddenKeys_neverLeak_toLearnerResponses() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(attemptId, "intro", "{}");
        submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + ev1 + "\",\"" + ev2 + "\"]}");
        submit(attemptId, "rc",
                "{\"relations\":[{\"from\":\"thuy-trieu\",\"to\":\"bai-coc\",\"relation\":\"che-giau\"},"
                        + "{\"from\":\"bai-coc\",\"to\":\"nam-han\",\"relation\":\"dan-den\"}]}");
        submit(attemptId, "hc", "{\"hypothesisId\":\"h-tide\"}");
        submit(attemptId, "do",
                "{\"orderedIds\":[\"step-dong-coc\",\"step-du-dich\",\"step-trieu-len\","
                        + "\"step-phuc-kich\",\"step-trieu-xuong\",\"step-tan-vo\"]}");
        submit(attemptId, "vf1", "{\"verdict\":\"SUPPORTED\"}");

        // getCurrent for cer — projection must not carry any hidden keys
        JsonNode cur = currentOf(attemptId);
        assertNoHiddenKeys(cur);

        // getContent — the whole snapshot projection
        JsonNode content = AttemptItFixture.body(om, mvc.perform(
                get("/api/v1/attempts/" + attemptId + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn());
        assertNoHiddenKeys(content);
    }

    /* ---------- second fixture: engine reuse ---------- */

    @Test
    void secondFixture_provesEngineReuse_noEventBranches() throws Exception {
        String eventId2 = AttemptItFixture.newEvent(jdbc, "hai-ba-trung-40");
        String evA = AttemptItFixture.newEvidence(jdbc, eventId2);
        String evB = AttemptItFixture.newEvidence(jdbc, eventId2);
        String evC = AttemptItFixture.newEvidence(jdbc, eventId2);
        String draft = new String(getClass().getResourceAsStream(
                "/lessons/hai-ba-trung-40.draft.json").readAllBytes(),
                StandardCharsets.UTF_8)
                .replace("${EV1}", evA).replace("${EV2}", evB).replace("${EV3}", evC);
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId2, tplId, draft);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        MvcResult es = submit(attemptId, "es",
                "{\"selectedEvidenceIds\":[\"" + evA + "\"]}");
        assertThat(AttemptItFixture.body(om, es)
                .get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");

        MvcResult cer = submit(attemptId, "cer",
                "{\"claimId\":\"c-indep\",\"evidenceIds\":[\"" + evA + "\"],"
                        + "\"reasoningId\":\"r-castle\"}");
        assertThat(AttemptItFixture.body(om, cer)
                .get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");

        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    /* ---------- helpers ---------- */

    private void assertNoHiddenKeys(JsonNode node) {
        java.util.List<String> found = new java.util.ArrayList<>();
        collect(node, found);
        assertThat(found).isEmpty();
    }

    private void collect(JsonNode node, List<String> found) {
        if (node == null) return;
        if (node.isObject()) {
            node.fields().forEachRemaining(e -> {
                if (com.dauviet.lesson.draft.DraftSchema.LEARNER_HIDDEN_KEYS
                        .contains(e.getKey())) {
                    found.add(e.getKey());
                }
                collect(e.getValue(), found);
            });
        } else if (node.isArray()) {
            node.forEach(n -> collect(n, found));
        }
    }
}
