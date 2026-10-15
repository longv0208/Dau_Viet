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
