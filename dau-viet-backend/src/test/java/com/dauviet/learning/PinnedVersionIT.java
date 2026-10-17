package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

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
 * Pinned-version safety: an attempt started on v1 keeps evaluating against
 * the v1 snapshot even after a v2 republish changes the answer key —
 * attempts remain pinned to a published version (product invariant).
 * Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class PinnedVersionIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String eventId;
    private String tplId;
    private String evId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@p.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@p.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-pin");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-pin");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    @Test
    void attemptPinnedToV1_gradesByV1Keys_afterV2Republish() throws Exception {
        // v1: correct answer is o1
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, AttemptItFixture.draftTwoStage(evId,
                        "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
                      + "\"correctOptionIds\":[\"o1\"]}"));
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        String v1Id = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts where id = ?::uuid",
                String.class, attemptId);

        // republish v2 with a DIFFERENT correct option via the draft API
        // (draftJson is a JSON string field -> escape the whole draft)
        var draftReq = new java.util.LinkedHashMap<String, Object>();
        draftReq.put("draftJson", AttemptItFixture.draftTwoStage(evId,
                "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
              + "\"correctOptionIds\":[\"o2\"]}"));
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.put(
                                "/api/v1/admin/lessons/" + lessonId + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(draftReq)))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());

        // lesson now points at v2; attempt still pins v1
        String currentVersion = jdbc.queryForObject(
                "select current_version_id::text from lessons where id = ?::uuid",
                String.class, lessonId);
        assertThat(currentVersion).isNotEqualTo(v1Id);

        // submit READ then the v1-correct MCQ answer on the pinned attempt
        submit(attemptId, "r1", "{}");
        MvcResult res = submit(attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        JsonNode body = AttemptItFixture.body(om, res);
        // o1 is correct under v1 keys (wrong under v2) -> pinned grading wins
        assertThat(body.get("evaluation").get("outcome").asText()).isEqualTo("COMPLETED");
        assertThat(body.get("evaluation").get("output").get("correct").asBoolean()).isTrue();
    }

    /**
     * TASK-0018: GET /attempts/{id}/content serves the PINNED v1 projection
     * after a v2 republish — the mobile player renders the same version its
     * submissions are graded against (evidence[]/assets[]/stage config).
     */
    @org.junit.jupiter.api.Test
    void attemptContent_servesPinnedVersion_afterV2Republish() throws Exception {
        String lessonId = AttemptItFixture.publishLesson(mvc, om, adminToken,
                eventId, tplId, AttemptItFixture.draftTwoStage(evId,
                        "{\"question\":\"q v1\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
                      + "\"correctOptionIds\":[\"o1\"]}"));
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        String v1Id = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts where id = ?::uuid",
                String.class, attemptId);

        // republish v2 — same draft shape, different question text
        var draftReq = new java.util.LinkedHashMap<String, Object>();
        draftReq.put("draftJson", AttemptItFixture.draftTwoStage(evId,
                "{\"question\":\"q v2\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
              + "\"correctOptionIds\":[\"o2\"]}"));
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.put(
                                "/api/v1/admin/lessons/" + lessonId + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(draftReq)))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk());

        // Pinned content must still be v1: matching versionId + v1 question.
        MvcResult res = mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.get(
                                "/api/v1/attempts/" + attemptId + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isOk())
                .andReturn();
        JsonNode body = AttemptItFixture.body(om, res);
        assertThat(body.get("lessonVersionId").asText()).isEqualTo(v1Id);
        assertThat(body.get("versionNo").asInt()).isEqualTo(1);
        String contentJson = body.get("content").toString();
        assertThat(contentJson).contains("q v1");
        assertThat(contentJson).doesNotContain("q v2");
        // owner-only: another learner's token cannot read the pinned content
        String otherToken = AttemptItFixture.token(users, jwt, "o@p.vn", UserRole.LEARNER);
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.get(
                                "/api/v1/attempts/" + attemptId + "/content")
                        .header("Authorization", otherToken))
                .andExpect(org.springframework.test.web.servlet.result
                        .MockMvcResultMatchers.status().isForbidden());
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
}
