package com.dauviet.learning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
 * FR-35..38 learner surface + admin config: visibility gates, publish gate,
 * optimistic locking, cross-event lesson rejection, coordinate validation,
 * and the server-authoritative unlock rule (>=1 COMPLETED attempt on any
 * version of the linked lesson). Requires Docker.
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

    private Map<String, Object> locationRequest(String title, double lat, double lng,
                                                String lessonId) {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("title", title);
        req.put("description", "Mo ta");
        req.put("latitude", lat);
        req.put("longitude", lng);
        if (lessonId != null) req.put("unlockLessonId", lessonId);
        return req;
    }

    private String createDraft(String event, String lessonId) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/admin/events/" + event + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(
                                locationRequest("Dia diem", 20.9, 106.8, lessonId))))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
    }

    private long rowVersion(String event, String locId) throws Exception {
        MvcResult res = mvc.perform(get("/api/v1/admin/events/" + event
                        + "/map-locations")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode rows = om.readTree(res.getResponse().getContentAsString());
        for (JsonNode row : rows) {
            if (locId.equals(row.get("id").asText())) {
                return row.get("rowVersion").asLong();
            }
        }
        throw new AssertionError("location not in admin list: " + locId);
    }

    private void setStatus(String event, String locId, String status,
                           long expectedRowVersion) throws Exception {
        mvc.perform(post("/api/v1/admin/events/" + event
                        + "/map-locations/" + locId + "/status?status=" + status
                        + "&expectedRowVersion=" + expectedRowVersion)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }

    private String createPublished(String event, String lessonId) throws Exception {
        String id = createDraft(event, lessonId);
        setStatus(event, id, "PUBLISHED", rowVersion(event, id));
        return id;
    }

    /**
     * Finish whatever required activities remain. startAttempt may RESUME an
     * in-progress attempt (partial progress earlier in the test), so submit
     * only the activities still pending per currentStageId/currentActivityId.
     * Returns the attempt id used.
     */
    private String driveToCompletion(String token, String lessonId) throws Exception {
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
        return attemptId;
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

    /* ================= learner surface ================= */

    @Test
    void publishedLocation_noLessonLink_isAvailable() throws Exception {
        createPublished(eventId, null);
        mvc.perform(get("/api/v1/map/locations")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].unlockState").value("AVAILABLE"))
                .andExpect(jsonPath("$[0].latitude").value(20.9))
                .andExpect(jsonPath("$[0].eventTitle").exists())
                .andExpect(jsonPath("$[0].requiredLesson").doesNotExist());
    }

    @Test
    void draftAndInactiveLocations_hiddenFromLearner() throws Exception {
        createDraft(eventId, null);
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
    void archivedLocation_hiddenFromLearner() throws Exception {
        String locId = createPublished(eventId, null);
        setStatus(eventId, locId, "ARCHIVED", rowVersion(eventId, locId));
        mvc.perform(get("/api/v1/map/locations")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    /* ================= admin validation ================= */

    @Test
    void invalidCoordinates_rejected() throws Exception {
        mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(
                                locationRequest("Sai toa do", 95.0, 106.0, null))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void nonExistentLessonLink_rejected() throws Exception {
        mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(locationRequest(
                                "Link ao", 20.0, 105.0,
                                UUID.randomUUID().toString()))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void crossEventLessonLink_rejected() throws Exception {
        String otherEvent = AttemptItFixture.newEvent(jdbc, "e-map-2");
        String lessonOnOther = AttemptItFixture.publishLesson(
                mvc, om, adminToken, otherEvent, tplId,
                AttemptItFixture.draftTwoStage(
                        AttemptItFixture.newEvidence(jdbc, otherEvent), MC_CONFIG));
        MvcResult res = mvc.perform(post("/api/v1/admin/events/" + eventId + "/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(locationRequest(
                                "Link sai event", 20.0, 105.0, lessonOnOther))))
                .andExpect(status().isBadRequest()).andReturn();
        assertThat(om.readTree(res.getResponse().getContentAsString()).toString())
                .contains("sự kiện");
    }

    /* ================= publish gate (FR-36) ================= */

    @Test
    void publishBlocked_whenLinkedLessonNotPublished() throws Exception {
        String draftLesson = createDraftLesson();
        String locId = createDraft(eventId, draftLesson);
        long version = rowVersion(eventId, locId);
        mvc.perform(post("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId + "/status?status=PUBLISHED"
                        + "&expectedRowVersion=" + version)
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.details.reason").value(
                        org.hamcrest.Matchers.containsString("xuất bản")));
    }

    @Test
    void publishBlocked_whenLinkedLessonArchived() throws Exception {
        String lessonId = publishLesson();
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        String locId = createDraft(eventId, lessonId);
        long version = rowVersion(eventId, locId);
        mvc.perform(post("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId + "/status?status=PUBLISHED"
                        + "&expectedRowVersion=" + version)
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());
    }

    @Test
    void archivedLinkedLesson_keepsUnlockAndMarksCtaInaccessible() throws Exception {
        String lessonId = publishLesson();
        String locId = createPublished(eventId, lessonId);
        String otherLocId = createPublished(eventId, lessonId);
        driveToCompletion(learnerToken, lessonId);

        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());

        // Earned UNLOCKED survives; CTA hidden via accessible=false.
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"))
                .andExpect(jsonPath("$.requiredLesson.accessible").value(false));
        // Other learner stays LOCKED, also sees accessible=false.
        mvc.perform(get("/api/v1/map/locations/" + otherLocId)
                        .header("Authorization", otherToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlockState").value("LOCKED"))
                .andExpect(jsonPath("$.requiredLesson.accessible").value(false));
    }

    /* ================= optimistic locking ================= */

    @Test
    void missingExpectedRowVersion_rejectedOnUpdateAndStatus() throws Exception {
        String locId = createDraft(eventId, null);
        mvc.perform(patch("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(
                                locationRequest("Sua", 10.0, 106.0, null))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.details.reason").value(
                        org.hamcrest.Matchers.containsString("expectedRowVersion")));

        mvc.perform(post("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId + "/status?status=ARCHIVED")
                        .header("Authorization", adminToken))
                .andExpect(status().isBadRequest());
    }

    @Test
    void staleExpectedRowVersion_conflicts() throws Exception {
        String locId = createDraft(eventId, null);
        long fresh = rowVersion(eventId, locId);
        mvc.perform(post("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId + "/status?status=PUBLISHED"
                        + "&expectedRowVersion=" + fresh)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        // Replaying the same (now stale) version must 409.
        mvc.perform(post("/api/v1/admin/events/" + eventId
                        + "/map-locations/" + locId + "/status?status=ARCHIVED"
                        + "&expectedRowVersion=" + fresh)
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict());
    }

    /* ================= unlock semantics ================= */

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
                .andExpect(jsonPath("$.requiredLesson.lessonId").value(lessonId))
                .andExpect(jsonPath("$.requiredLesson.accessible").value(true));

        driveToCompletion(learnerToken, lessonId);
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"));

        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", otherToken))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"));
    }

    /**
     * Republish must rotate the SAME lesson to a new version — the earlier
     * version of this test called publishLesson() which CREATES a different
     * lesson, proving nothing about republish. Complete on V1 → republish
     * same lesson as V2 → unlock survives (completed on ANY pinned version),
     * other learner stays LOCKED, attempt stays pinned to its own version.
     */
    @Test
    void unlockSurvivesLessonRepublish_andRequiresAuth() throws Exception {
        String lessonId = publishLesson();
        String locId = createPublished(eventId, lessonId);
        String attemptId = driveToCompletion(learnerToken, lessonId);

        String pinnedVersion = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts where id = ?::uuid",
                String.class, attemptId);
        String v1 = jdbc.queryForObject(
                "select current_version_id::text from lessons where id = ?::uuid",
                String.class, lessonId);
        assertThat(pinnedVersion).isEqualTo(v1);

        republishSameLesson(lessonId);
        String v2 = jdbc.queryForObject(
                "select current_version_id::text from lessons where id = ?::uuid",
                String.class, lessonId);
        assertThat(v2).isNotEqualTo(v1);

        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"))
                .andExpect(jsonPath("$.requiredLesson.lessonId").value(lessonId));
        mvc.perform(get("/api/v1/map/locations/" + locId)
                        .header("Authorization", otherToken))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"));

        String stillPinned = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts where id = ?::uuid",
                String.class, attemptId);
        assertThat(stillPinned).isEqualTo(v1);

        mvc.perform(get("/api/v1/map/locations"))
                .andExpect(status().isUnauthorized());
    }

    /** Completing a lesson that also unlocks another location unlocks all of them. */
    @Test
    void sharedUnlockLesson_unlocksAllLinkedLocations() throws Exception {
        String lessonId = publishLesson();
        String locA = createPublished(eventId, lessonId);
        String locB = createPublished(eventId, lessonId);

        driveToCompletion(learnerToken, lessonId);

        mvc.perform(get("/api/v1/map/locations")
                        .header("Authorization", learnerToken))
                .andExpect(jsonPath("$.length()").value(2));
        for (String id : new String[]{locA, locB}) {
            mvc.perform(get("/api/v1/map/locations/" + id)
                            .header("Authorization", learnerToken))
                    .andExpect(jsonPath("$.unlockState").value("UNLOCKED"));
            mvc.perform(get("/api/v1/map/locations/" + id)
                            .header("Authorization", otherToken))
                    .andExpect(jsonPath("$.unlockState").value("LOCKED"));
        }
    }

    /** DRAFT lesson (no publish) — valid for draft link, rejected at publish. */
    private String createDraftLesson() throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("eventId", eventId);
        req.put("templateId", tplId);
        req.put("title", "Draft L");
        req.put("centralQuestion", "Q?");
        req.put("draftJson", AttemptItFixture.draftTwoStage(evId, MC_CONFIG));
        MvcResult created = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(created.getResponse().getContentAsString())
                .get("id").asText();
    }

    /** PUT a (trivially changed) draft on the same lesson then publish again → V2. */
    private void republishSameLesson(String lessonId) throws Exception {
        mvc.perform(put("/api/v1/admin/lessons/" + lessonId + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(Map.of("draftJson",
                                AttemptItFixture.draftTwoStage(evId, MC_CONFIG)))))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }
}
