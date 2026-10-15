package com.dauviet.lesson;

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
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Public learner surface: GET /api/v1/events/{id}/lessons, /lessons/{id},
 * /lessons/{id}/content. Learner-safe: answer keys, validation internals and
 * stage requiredEvidenceIds never reach the payload. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class LearnerLessonApiIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String eventId;
    private String tplId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail("lrn@t.vn");
        admin.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        adminToken = "Bearer " + jwt.createAccessToken(admin);

        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("lrn-learner@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        learnerToken = "Bearer " + jwt.createAccessToken(learner);

        eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'PUBLISHED')", eventId);
        tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't', 'T', 1, '{}'::jsonb, true)", tplId);
    }

    /* ---------- fixtures ---------- */

    private String createLesson(String draftJson) throws Exception {
        var req = new java.util.LinkedHashMap<String, Object>();
        req.put("eventId", eventId);
        req.put("templateId", tplId);
        req.put("title", "L");
        req.put("centralQuestion", "Q?");
        req.put("draftJson", draftJson);
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(res.getResponse().getContentAsString()).get("id").asText();
    }

    private String approvedEvidence() {
        String evId = UUID.randomUUID().toString();
        jdbc.update("insert into evidences (id, event_id, title, evidence_type, source_title, status) "
                  + "values (?::uuid, ?::uuid, 'EV', 'DOC', 'src', 'APPROVED')", evId, eventId);
        return evId;
    }

    private String publishableDraft(String evId) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "activities":[{"id":"r1","type":"READ","config":{"text":"hi"}}],
                    "nextStageIds":["ev"]},
                   {"id":"ev","type":"EVIDENCE","required":true,
                    "requiredEvidenceIds":["%s"],
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                   "config":{"visibleEvidenceIds":["%s"]},
                                   "evidenceRefs":["%s"]},
                                  {"id":"mc","type":"MULTIPLE_CHOICE",
                                   "config":{"question":"q",
                                             "options":[{"id":"o1"},{"id":"o2"}],
                                             "correctOptionIds":["o1"],
                                             "answerKey":{"k":"v"}},
                                   "validation":{"kind":"SCORE","pass":80}}],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, evId, evId, evId);
    }

    private String publishLesson(String draftJson) throws Exception {
        String id = createLesson(draftJson);
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        return id;
    }

    /* ---------- tests ---------- */

    @Test
    void listForEvent_returnsOnlyPublishedLessons() throws Exception {
        String published = publishLesson(publishableDraft(approvedEvidence()));
        String draftOnly = createLesson("{}"); // stays DRAFT

        MvcResult res = mvc.perform(get("/api/v1/events/" + eventId + "/lessons")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode arr = om.readTree(res.getResponse().getContentAsString());
        assertThat(arr.isArray()).isTrue();
        assertThat(arr.size()).isEqualTo(1);
        assertThat(arr.get(0).get("id").asText()).isEqualTo(published);
        assertThat(arr.get(0).get("title").asText()).isEqualTo("L");
        assertThat(arr.get(0).get("centralQuestion").asText()).isEqualTo("Q?");
        assertThat(arr.toString()).doesNotContain(draftOnly);
    }

    @Test
    void listForEvent_draftEvent_404() throws Exception {
        String draftEvent = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e2', 'E2', 's', 'DRAFT')", draftEvent);
        mvc.perform(get("/api/v1/events/" + draftEvent + "/lessons")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void metadata_publishedLesson_200() throws Exception {
        String id = publishLesson(publishableDraft(approvedEvidence()));
        mvc.perform(get("/api/v1/lessons/" + id)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.title").value("L"))
                .andExpect(jsonPath("$.centralQuestion").value("Q?"))
                .andExpect(jsonPath("$.eventId").value(eventId))
                .andExpect(jsonPath("$.versionNo").value(1))
                .andExpect(jsonPath("$.currentVersionId").isString())
                .andExpect(jsonPath("$.publishedAt").isString());
    }

    @Test
    void content_stripsAllServerOnlyKeys() throws Exception {
        String evId = approvedEvidence();
        String id = publishLesson(publishableDraft(evId));

        MvcResult res = mvc.perform(get("/api/v1/lessons/" + id + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lessonId").value(id))
                .andExpect(jsonPath("$.versionNo").value(1))
                .andReturn();
        JsonNode content = om.readTree(res.getResponse().getContentAsString())
                .get("content");
        String payload = content.toString();

        // embedded evidence and learner-facing fields survive
        assertThat(payload).contains("visibleEvidenceIds");
        assertThat(payload).contains("\"question\":\"q\"");
        assertThat(content.at("/evidence/0/id").asText()).isEqualTo(evId);

        // server-only keys stripped everywhere
        assertThat(payload).doesNotContain("correctOptionIds");
        assertThat(payload).doesNotContain("answerKey");
        assertThat(payload).doesNotContain("\"answer\"");
        assertThat(payload).doesNotContain("expectedHypothesis");
        // activity validation block removed
        assertThat(content.at("/stages/1/activities/1/validation").isMissingNode()).isTrue();
        // stage-level requiredEvidenceIds removed
        assertThat(content.at("/stages/1/requiredEvidenceIds").isMissingNode()).isTrue();
        // raw payload must not contain a bare "key" leaf either
        assertThat(content.findValues("key")).isEmpty();
    }

    @Test
    void learnerEndpoints_unpublishedLesson_404() throws Exception {
        String draftOnly = createLesson("{}");
        mvc.perform(get("/api/v1/lessons/" + draftOnly)
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_PUBLISHED"));
        mvc.perform(get("/api/v1/lessons/" + draftOnly + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_PUBLISHED"));
    }

    @Test
    void learnerEndpoints_missingLesson_404() throws Exception {
        mvc.perform(get("/api/v1/lessons/" + UUID.randomUUID())
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_FOUND"));
        mvc.perform(get("/api/v1/lessons/" + UUID.randomUUID() + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void learnerEndpoints_anonymous_401() throws Exception {
        // AC-10: learner surface requires authentication — anonymous 401.
        String id = publishLesson(publishableDraft(approvedEvidence()));
        mvc.perform(get("/api/v1/events/" + eventId + "/lessons"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/lessons/" + id))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/lessons/" + id + "/content"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void learnerEndpoints_learnerAndAdmin_200() throws Exception {
        // Any authenticated role may read published learner content.
        String id = publishLesson(publishableDraft(approvedEvidence()));
        mvc.perform(get("/api/v1/events/" + eventId + "/lessons")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/lessons/" + id)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/lessons/" + id + "/content")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());
        // admin can also read the learner surface (superset access)
        mvc.perform(get("/api/v1/lessons/" + id + "/content")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }

    // NOTE: a truly unparseable snapshot_json cannot be injected via SQL —
    // the jsonb column + jsonb_typeof CHECK reject non-JSON at write time.
    // The corrupt-snapshot path is covered by LearnerLessonServiceTest
    // (mocked repository returning invalid JSON -> SnapshotCorruptException).
}
