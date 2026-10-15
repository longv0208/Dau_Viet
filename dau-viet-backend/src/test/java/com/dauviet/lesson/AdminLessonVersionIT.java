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

/** GET /admin/lessons/{id}/versions* — read side of the immutable history. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonVersionIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
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
        admin.setEmail("ver@t.vn");
        admin.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        adminToken = "Bearer " + jwt.createAccessToken(admin);

        eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'DRAFT')", eventId);
        tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't', 'T', 1, '{}'::jsonb, true)", tplId);
    }

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
                    "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                   "config":{"visibleEvidenceIds":["%s"]},
                                   "evidenceRefs":["%s"]}],
                    "nextStageIds":[]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(evId, evId);
    }

    private String publishAndGetVersionId(String lessonId) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("lessonVersionId").asText();
    }

    @Test
    void list_emptyUntilFirstPublish_thenNewestFirst() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));

        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0))
                .andExpect(jsonPath("$.totalElements").value(0));

        publishAndGetVersionId(id);
        publishAndGetVersionId(id);

        MvcResult res = mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        assertThat(body.get("totalElements").asLong()).isEqualTo(2);
        assertThat(body.get("content").size()).isEqualTo(2);
        // newest first: versionNo 2 then 1
        assertThat(body.at("/content/0/versionNo").asInt()).isEqualTo(2);
        assertThat(body.at("/content/1/versionNo").asInt()).isEqualTo(1);
        assertThat(body.at("/content/0/publishedBy").isTextual()).isTrue();
        assertThat(body.at("/content/0/schemaVersion").asInt()).isEqualTo(1);
    }

    @Test
    void get_returnsFullSnapshotIncludingServerOnlyKeys() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        String versionId = publishAndGetVersionId(id);

        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions/" + versionId)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(versionId))
                .andExpect(jsonPath("$.lessonId").value(id))
                .andExpect(jsonPath("$.versionNo").value(1))
                .andExpect(jsonPath("$.snapshot.stages").isArray())
                .andExpect(jsonPath("$.snapshot.evidence").isArray())
                .andExpect(jsonPath("$.snapshot.title").value("L"));
    }

    @Test
    void get_wrongLesson_404() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        String versionId = publishAndGetVersionId(id);
        String otherLesson = createLesson("{}");

        mvc.perform(get("/api/v1/admin/lessons/" + otherLesson + "/versions/" + versionId)
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("VERSION_NOT_FOUND"));
    }

    @Test
    void getCurrent_beforePublish_404_afterPublish_200() throws Exception {
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));

        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions/current")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("VERSION_NOT_FOUND"));

        String versionId = publishAndGetVersionId(id);
        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions/current")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(versionId));
    }

    @Test
    void versions_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("ver-learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String id = createLesson("{}");
        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/lessons/" + id + "/versions")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void list_missingLesson_404() throws Exception {
        mvc.perform(get("/api/v1/admin/lessons/" + UUID.randomUUID() + "/versions")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_FOUND"));
    }
}
