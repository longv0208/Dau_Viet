package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

/** End-to-end attempt runtime on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class LearnerAttemptApiIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String otherToken;
    private String eventId;
    private String tplId;
    private String evId;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@t.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@t.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@t.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-att");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-att");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String publish() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
    }

    private MvcResult submit(String token, String attemptId, String activityId,
                             String answerJson) throws Exception {
        return mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":" + answerJson + "}"))
                .andReturn();
    }

    /* ---------- happy path ---------- */

    @Test
    void happyPath_startSubmitAdvanceComplete() throws Exception {
        String lessonId = publish();

        // start attempt — pins to current version, cursor at first required act
        MvcResult start = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.resumed").value(false))
                .andExpect(jsonPath("$.currentStageId").value("ctx"))
                .andExpect(jsonPath("$.currentActivityId").value("r1"))
                .andReturn();
        String attemptId = AttemptItFixture.body(om, start).get("attemptId").asText();

        // resume idempotent: second start returns same attempt
        mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resumed").value(true))
                .andExpect(jsonPath("$.attemptId").value(attemptId));

        // GET current — learner-safe READ activity
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage.id").value("ctx"))
                .andExpect(jsonPath("$.activity.id").value("r1"))
                .andExpect(jsonPath("$.activity.type").value("READ"))
                .andExpect(jsonPath("$.progress.totalRequired").value(2));

        // submit READ -> next is the MCQ in stage ev
        MvcResult s1 = submit(learnerToken, attemptId, "r1", "{}");
        JsonNode s1Body = AttemptItFixture.body(om, s1);
        assertThat(s1.getResponse().getStatus()).isEqualTo(200);
        assertThat(s1Body.get("evaluation").get("completed").asBoolean()).isTrue();
        assertThat(s1Body.get("next").get("stageId").asText()).isEqualTo("ev");
        assertThat(s1Body.get("next").get("activityId").asText()).isEqualTo("mc");
        assertThat(s1Body.get("completion").get("complete").asBoolean()).isFalse();

        // wrong MCQ answer -> INCORRECT, cursor stays (maxAttempts=1 -> exhausted
        // completes the activity though)
        MvcResult s2 = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o2\"]}");
        JsonNode s2Body = AttemptItFixture.body(om, s2);
        assertThat(s2Body.get("evaluation").get("outcome").asText()).isEqualTo("INCORRECT");
        // maxAttempts defaults 1 -> exhausted -> activity counts done
        assertThat(s2Body.get("activityCompleted").asBoolean()).isTrue();

        // completion verdict: required stages done -> complete=true
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.complete").value(true))
                .andExpect(jsonPath("$.reason").value("ALL_REQUIRED_STAGES"));

        // progress view reflects all required done; status still IN_PROGRESS
        mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.progress.completedRequired").value(2))
                .andExpect(jsonPath("$.completion.complete").value(true));
    }

    /* ---------- negative paths ---------- */

    @Test
    void anonymous_401_onEveryEndpoint() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/attempts/" + attemptId))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/current"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/activities/r1/submissions")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"answer\":{}}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void otherUser_cannotReadOrSubmit_403() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ATTEMPT_NOT_OWNER"));
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());
        MvcResult res = submit(otherToken, attemptId, "r1", "{}");
        assertThat(res.getResponse().getStatus()).isEqualTo(403);
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", otherToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void unpublishedLesson_startReturns404() throws Exception {
        // draft lesson never published -> LESSON_NOT_PUBLISHED
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
        // unpublish via direct db flip to DRAFT (API has no unpublish)
        jdbc.update("update lessons set status='DRAFT', current_version_id=null "
                  + "where id=?::uuid", lessonId);

        mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_PUBLISHED"));
    }

    @Test
    void missingLesson_404() throws Exception {
        mvc.perform(post("/api/v1/lessons/" + UUID.randomUUID() + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void staleActivitySubmit_409() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        // submit directly against mc (cursor is at r1) -> ACTIVITY_NOT_AVAILABLE
        MvcResult res = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}");
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        assertThat(AttemptItFixture.body(om, res).get("code").asText())
                .isEqualTo("ACTIVITY_NOT_AVAILABLE");
    }

    @Test
    void retryAfterAdvance_sameActivity_409() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");
        // cursor moved to mc; resubmitting r1 is a stale-cursor write
        MvcResult res = submit(learnerToken, attemptId, "r1", "{}");
        assertThat(res.getResponse().getStatus()).isEqualTo(409);
        assertThat(AttemptItFixture.body(om, res).get("code").asText())
                .isEqualTo("ACTIVITY_NOT_AVAILABLE");
    }

    @Test
    void ghostAttempt_404() throws Exception {
        mvc.perform(get("/api/v1/attempts/" + UUID.randomUUID())
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ATTEMPT_NOT_FOUND"));
    }

    @Test
    void noHiddenKeyLeak_inAnyResponse() throws Exception {
        String lessonId = publish();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        MvcResult cur = mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        assertNoHiddenKeys(AttemptItFixture.body(om, cur));

        submit(learnerToken, attemptId, "r1", "{}");
        MvcResult cur2 = mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = AttemptItFixture.body(om, cur2);
        assertNoHiddenKeys(body);
        // sanity: MCQ config reaches the learner, its correctOptionIds must not
        assertThat(body.at("/activity/config/options").isArray()).isTrue();
    }

    /* ---------- TASK-0011 correctness fixes ---------- */

    private static final String MC_CONFIG_RETRY =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"],\"maxAttempts\":2}";

    private String publishOptional() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftWithOptional(evId, MC_CONFIG_RETRY));
    }

    private JsonNode currentOf(String attemptId) throws Exception {
        MvcResult res = mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        return AttemptItFixture.body(om, res);
    }

    private JsonNode progressOf(String attemptId) throws Exception {
        MvcResult res = mvc.perform(get("/api/v1/attempts/" + attemptId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk()).andReturn();
        return AttemptItFixture.body(om, res);
    }

    @Test
    void requiredFailure_retryStaysThenExhaustionAdvances() throws Exception {
        String lessonId = publishOptional();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        submit(learnerToken, attemptId, "r1", "{}");

        // wrong answer #1 of 2 -> INCORRECT, not completed, cursor stays on mc
        MvcResult w1 = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o2\"]}");
        JsonNode w1Body = AttemptItFixture.body(om, w1);
        assertThat(w1Body.get("evaluation").get("outcome").asText()).isEqualTo("INCORRECT");
        assertThat(w1Body.get("activityCompleted").asBoolean()).isFalse();
        assertThat(w1Body.get("next").get("activityId").asText()).isEqualTo("mc");
        assertThat(currentOf(attemptId).get("activity").get("id").asText()).isEqualTo("mc");
        assertThat(progressOf(attemptId).get("progress").get("completedRequired").asInt())
                .isEqualTo(1);

        // retry is accepted (was soft-locked before the fix)
        MvcResult w2 = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o2\"]}");
        JsonNode w2Body = AttemptItFixture.body(om, w2);
        assertThat(w2Body.get("evaluation").get("output").get("exhausted").asBoolean()).isTrue();
        assertThat(w2Body.get("activityCompleted").asBoolean()).isTrue();

        // exhausted -> advanced; required count now 2/2 -> lesson complete
        JsonNode prog = progressOf(attemptId);
        assertThat(prog.get("progress").get("completedRequired").asInt()).isEqualTo(2);
        assertThat(prog.get("completion").get("complete").asBoolean()).isTrue();
    }

    @Test
    void optionalActivity_submittable_recordsWithoutMovingCursor() throws Exception {
        String lessonId = publishOptional();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        // cursor at r1; opt1/mcOpt are optional in the same stage

        MvcResult o1 = submit(learnerToken, attemptId, "opt1", "{}");
        JsonNode o1Body = AttemptItFixture.body(om, o1);
        assertThat(o1.getResponse().getStatus()).isEqualTo(200);
        assertThat(o1Body.get("activityCompleted").asBoolean()).isTrue();
        // next echoes the unchanged cursor — still r1
        assertThat(o1Body.get("next").get("activityId").asText()).isEqualTo("r1");
        assertThat(currentOf(attemptId).get("activity").get("id").asText()).isEqualTo("r1");
        // progress unchanged — optionals never count
        assertThat(progressOf(attemptId).get("progress").get("totalRequired").asInt())
                .isEqualTo(2);
        assertThat(progressOf(attemptId).get("progress").get("completedRequired").asInt())
                .isEqualTo(0);

        // optional EVIDENCE_SELECT evaluates too — but lives in stage ev,
        // not current stage ctx, so it is NOT accessible yet
        MvcResult notYet = submit(learnerToken, attemptId, "es-opt",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}");
        assertThat(notYet.getResponse().getStatus()).isEqualTo(409);

        // skipping: learner proceeds by submitting the required cursor activity
        submit(learnerToken, attemptId, "r1", "{}");
        assertThat(currentOf(attemptId).get("activity").get("id").asText()).isEqualTo("mc");

        // now inside ev: optional esOpt in CURRENT stage is submittable
        MvcResult o2 = submit(learnerToken, attemptId, "es-opt",
                "{\"selectedEvidenceIds\":[\"" + evId + "\"]}");
        JsonNode o2Body = AttemptItFixture.body(om, o2);
        assertThat(o2.getResponse().getStatus()).isEqualTo(200);
        assertThat(o2Body.get("activityCompleted").asBoolean()).isTrue();
        // cursor still on required mc
        assertThat(currentOf(attemptId).get("activity").get("id").asText()).isEqualTo("mc");

        // activity_attempts rows recorded for optional submits (opt1 + esOpt)
        Integer rows = jdbc.queryForObject(
                "select count(*) from activity_attempts where learner_attempt_id = ?::uuid",
                Integer.class, attemptId);
        assertThat(rows).isEqualTo(3);

        // optional in a PREVIOUS stage is no longer accessible
        MvcResult stale = submit(learnerToken, attemptId, "opt1", "{}");
        assertThat(stale.getResponse().getStatus()).isEqualTo(409);
        // optional submit never leaks hidden keys
        assertNoHiddenKeys(o2Body);
    }

    @Test
    void multiStage_cursorAndProgressConsistentAfterEverySubmit() throws Exception {
        String lessonId = publishOptional();
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);

        // r1 -> mc (ev stage), then correct mc -> nothing left
        submit(learnerToken, attemptId, "r1", "{}");
        JsonNode cur = currentOf(attemptId);
        assertThat(cur.get("activity").get("id").asText()).isEqualTo("mc");
        assertThat(cur.get("stage").get("id").asText()).isEqualTo("ev");

        MvcResult fin = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}");
        JsonNode finBody = AttemptItFixture.body(om, fin);
        assertThat(finBody.get("activityCompleted").asBoolean()).isTrue();
        assertThat(finBody.get("completion").get("complete").asBoolean()).isTrue();

        JsonNode prog = progressOf(attemptId);
        assertThat(prog.get("progress").get("completedRequired").asInt()).isEqualTo(2);
        assertThat(prog.get("progress").get("totalRequired").asInt()).isEqualTo(2);
        // cursor response and progress response agree
        assertThat(prog.get("currentActivityId").isNull()
                || !prog.get("currentActivityId").asText().isBlank()).isTrue();
    }

    @Test
    void duplicateActivityIdAcrossStages_publishRejected422() throws Exception {
        String draft = """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"a"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "activities":[{"id":"r1","type":"READ","required":true,
                                    "config":{"text":"b"}}],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """;
        // create lesson with this draft -> publish must fail DRAFT_SCHEMA_INVALID
        var req = new java.util.LinkedHashMap<String, Object>();
        req.put("eventId", eventId);
        req.put("templateId", tplId);
        req.put("title", "L");
        req.put("centralQuestion", "Q?");
        req.put("draftJson", draft);
        MvcResult created = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        String lessonId = om.readTree(created.getResponse().getContentAsString())
                .get("id").asText();
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("DRAFT_SCHEMA_INVALID"));
    }

    private void assertNoHiddenKeys(JsonNode node) {
        java.util.List<String> found = new java.util.ArrayList<>();
        collect(node, found);
        assertThat(found).isEmpty();
    }

    private void collect(JsonNode node, java.util.List<String> found) {
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
