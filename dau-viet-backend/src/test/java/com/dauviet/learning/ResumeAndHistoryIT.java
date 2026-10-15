package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.LinkedHashMap;
import java.util.Map;

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
 * Resume-across-republish + progress/history APIs (TASK-0012): an
 * IN_PROGRESS attempt pinned to v1 is resumed — never replaced — after a
 * v2 republish; /me/attempts and /me/progress expose only the caller's own
 * attempts with pagination. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ResumeAndHistoryIT extends AbstractPostgresIT {

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

    private static final String MC_V1 =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o1\"]}";
    private static final String MC_V2 =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
          + "\"correctOptionIds\":[\"o2\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "a@r.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@r.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@r.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-res");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-res");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String publish(String mcConfig) throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, mcConfig));
    }

    private void republish(String lessonId, String mcConfig) throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("draftJson", AttemptItFixture.draftTwoStage(evId, mcConfig));
        mvc.perform(org.springframework.test.web.servlet.request
                        .MockMvcRequestBuilders.put(
                                "/api/v1/admin/lessons/" + lessonId + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
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

    @Test
    void resumeAfterRepublish_returnsV1Attempt_notNewV2() throws Exception {
        String lessonId = publish(MC_V1);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        String v1 = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts where id = ?::uuid",
                String.class, attemptId);

        // progress a bit, then republish v2
        submit(learnerToken, attemptId, "r1", "{}");
        republish(lessonId, MC_V2);
        String currentVersion = jdbc.queryForObject(
                "select current_version_id::text from lessons where id = ?::uuid",
                String.class, lessonId);
        assertThat(currentVersion).isNotEqualTo(v1);

        // start again -> resumes the V1 attempt, never creates a v2 attempt
        MvcResult resume = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resumed").value(true))
                .andExpect(jsonPath("$.attemptId").value(attemptId))
                .andExpect(jsonPath("$.lessonVersionId").value(v1))
                .andExpect(jsonPath("$.currentActivityId").value("mc"))
                .andReturn();
        assertThat(AttemptItFixture.body(om, resume).get("attemptId").asText())
                .isEqualTo(attemptId);

        // still exactly one attempt row for this user+lesson
        Integer count = jdbc.queryForObject(
                "select count(*) from learner_attempts a "
              + "join lesson_versions v on a.lesson_version_id = v.id "
              + "where v.lesson_id = ?::uuid", Integer.class, lessonId);
        assertThat(count).isEqualTo(1);

        // and the resumed attempt still grades under v1 keys
        MvcResult res = submit(learnerToken, attemptId, "mc",
                "{\"selectedOptionIds\":[\"o1\"]}");
        assertThat(res.getResponse().getStatus()).isEqualTo(200);
        assertThat(AttemptItFixture.body(om, res)
                .get("evaluation").get("output").get("correct").asBoolean()).isTrue();
    }

    @Test
    void meAttempts_listsOnlyOwn_paged() throws Exception {
        String lessonId = publish(MC_V1);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        AttemptItFixture.startAttempt(mvc, om, otherToken, lessonId);

        MvcResult list = mvc.perform(get("/api/v1/me/attempts?page=0&size=10")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].attemptId").value(attemptId))
                .andExpect(jsonPath("$.content[0].lessonId").value(lessonId))
                .andExpect(jsonPath("$.content[0].status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.content[0].progress.totalRequired").value(2))
                .andReturn();
        assertThat(AttemptItFixture.body(om, list).get("content").size()).isEqualTo(1);

        // status filter
        mvc.perform(get("/api/v1/me/attempts?status=COMPLETED")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0));

        // anonymous -> 401
        mvc.perform(get("/api/v1/me/attempts"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void meProgress_resumeSurface() throws Exception {
        String lessonId = publish(MC_V1);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");

        mvc.perform(get("/api/v1/me/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.inProgress[0].attemptId").value(attemptId))
                .andExpect(jsonPath("$.inProgress[0].currentActivityId").value("mc"))
                .andExpect(jsonPath("$.inProgress[0].progress.completedRequired").value(1))
                .andExpect(jsonPath("$.completedCount").value(0));

        // finish it -> leaves inProgress, completedCount grows
        submit(learnerToken, attemptId, "mc", "{\"selectedOptionIds\":[\"o1\"]}");
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/me/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.inProgress").isEmpty())
                .andExpect(jsonPath("$.completedCount").value(1));
    }

    @Test
    void progressPersistsAcrossRequests_reloadedFromDb() throws Exception {
        String lessonId = publish(MC_V1);
        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        submit(learnerToken, attemptId, "r1", "{}");

        // fresh read (simulates app restart — state comes from DB, not memory)
        mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activity.id").value("mc"))
                .andExpect(jsonPath("$.stage.id").value("ev"));
    }
}
