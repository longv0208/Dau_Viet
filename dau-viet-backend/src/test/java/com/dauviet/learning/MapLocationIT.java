package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.LinkedHashMap;
import java.util.Map;
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
 * FR-35..38 learner surface + admin config: visibility gates, cross-event
 * lesson rejection, coordinate validation, and the server-authoritative
 * unlock rule (>=1 COMPLETED attempt on any version of the linked lesson).
 * Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class MapLocationIT extends AbstractPostgresIT {

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

        adminToken = AttemptItFixture.token(users, jwt, "a@map.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "l@map.vn", UserRole.LEARNER);
        otherToken = AttemptItFixture.token(users, jwt, "o@map.vn", UserRole.LEARNER);
        eventId = AttemptItFixture.newEvent(jdbc, "e-map");
        tplId = AttemptItFixture.newTemplate(jdbc, "t-map");
        evId = AttemptItFixture.newEvidence(jdbc, eventId);
    }

    private String publishLesson() throws Exception {
        return AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
    }

    private String createPublished(String event, String lessonId) throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("title", "Ben Bach Dang");
        req.put("description", "Bai coc ngam");
        req.put("latitude", 20.9);
        req.put("longitude", 106.8);
        if (lessonId != null) req.put("unlockLessonId", lessonId);
        MvcResult res = mvc.perform(post("/api/v1/admin/events/" + event + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        String id = om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
        mvc.perform(post("/api/v1/admin/events/" + event
                        + "/map-locations/" + id + "/status?status=PUBLISHED")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        return id;
    }

    /**
     * Finish whatever required activities remain. startAttempt may RESUME an
     * in-progress attempt (partial progress earlier in the test), so submit
     * only the activities still pending per currentStageId/currentActivityId.
     */
    private void driveToCompletion(String token, String lessonId) throws Exception {
        MvcResult started = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", token))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(started.getResponse().getContentAsString());
        String attemptId = body.get("attemptId").asText();
        String currentActivity = body.hasNonNull("currentActivityId")
                ? body.get("currentActivityId").asText() : null;
        if ("r1".equals(currentActivity)) {
            submit(token, attemptId, "r1", "{\"answer\":{}}");
            currentActivity = "mc";
        }
        if ("mc".equals(currentActivity)) {
            submit(token, attemptId, "mc",
                    "{\"answer\":{\"selectedOptionIds\":[\"o1\"]}}");
        }
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", token))
                .andExpect(status().isOk());
    }

    private void submit(String token, String attemptId, String activityId,
                        String json) throws Exception {
        mvc.perform(post("/api/v1/attempts/" + attemptId
                        + "/activities/" + activityId + "/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isOk());
    }

    @Test
    void publishedLocation_noLessonLink_isAvailable() throws Exception {
        createPublished(eventId, null);
        mvc.perform(get("/api/v1/map/locations")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].unlockState").value("AVAILABLE"))
                .andExpect(jsonPath("$[0].latitude").value(20.9))
                .andExpect(jsonPath("$[0].requiredLesson").doesNotExist());
    }

    @Test
    void draftAndInactiveLocations_hiddenFromLearner() throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("title", "Nhap");
        req.put("latitude", 10.0);
        req.put("longitude", 106.0);
        mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated());
        String draftEvent = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'draft-ev', 'D', 's', 'DRAFT')", draftEvent);
        createPublished(draftEvent, null);

        mvc.perform(get("/api/v1/map/locations")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void invalidCoordinates_rejected() throws Exception {
        Map<String, Object> bad = new LinkedHashMap<>();
        bad.put("title", "Sai toa do");
        bad.put("latitude", 95.0);
        bad.put("longitude", 106.0);
        mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(bad)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void crossEventLessonLink_rejected() throws Exception {
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-map-2");
        String lessonOnOther = AttemptItFixture.publishLesson(
                mvc, om, adminToken, otherEvent, tplId,
                AttemptItFixture.draftTwoStage(
                        AttemptItFixture.newEvidence(jdbc, otherEvent), MC_CONFIG));
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("title", "Link sai event");
        req.put("latitude", 20.0);
        req.put("longitude", 105.0);
        req.put("unlockLessonId", lessonOnOther);
        MvcResult res = mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isBadRequest()).andReturn();
        JsonNode parsed = om.readTree(res.getResponse().getContentAsString());
        assertThat(parsed.toString()).contains("sự kiện");
    }

    @Test
    void locked_thenUnlocked_onlyAfterCompletedAttempt() throws Exception {
        String lessonId = publishLesson();
        String locId = createPublished(eventId, lessonId);

        String attemptId = AttemptItFixture.startAttempt(mvc, om, learnerToken, lessonId);
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/activities/r1/submissions")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":{}}"))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"))
                .andExpect(jsonPath("$.requiredLesson.lessonId").value(lessonId));

        driveToCompletion(learnerToken, lessonId);
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"));

        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", otherToken))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"));
    }

    @Test
    void unlockSurvivesLessonRepublish_andRequiresAuth() throws Exception {
        String lessonId = publishLesson();
        String locId = createPublished(eventId, lessonId);
        driveToCompletion(learnerToken, lessonId);

        AttemptItFixture.publishLesson(mvc, om, adminToken, eventId, tplId,
                AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"));

        mvc.perform(get("/api/v1/map/locations"))
                .andExpect(status().isUnauthorized());
    }
}
