package com.dauviet.lesson;

import static org.assertj.core.api.Assertions.assertThat;
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
 * POST /admin/lessons/{id}/preview — learner-safe projection of the CURRENT
 * DRAFT without publishing. No lesson_versions row is written. Requires Docker.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonPreviewIT extends AbstractPostgresIT {

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
        admin.setEmail("pv@t.vn");
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

    @Test
    void preview_stripsHiddenKeys_andDoesNotWriteVersion() throws Exception {
        String draft = """
                {"schemaVersion":1,
                 "stages":[{"id":"ctx","type":"CONTEXT","required":true,
                            "activities":[{"id":"r1","type":"READ",
                                           "config":{"text":"hi"}}],
                            "nextStageIds":[]}]}
                """;
        String id = createLesson(draft);

        MvcResult res = mvc.perform(post("/api/v1/admin/lessons/" + id + "/preview")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lessonId").value(id))
                .andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        // preview is draft-based: no version allocated
        assertThat(body.get("lessonVersionId").isNull()).isTrue();
        assertThat(body.get("versionNo").isNull()).isTrue();
        JsonNode content = body.get("content");
        assertThat(content.at("/stages/0/id").asText()).isEqualTo("ctx");
        assertThat(content.at("/stages/0/activities/0/config/text").asText()).isEqualTo("hi");

        Integer versions = jdbc.queryForObject(
                "select count(*) from lesson_versions where lesson_id = ?::uuid",
                Integer.class, id);
        assertThat(versions).isZero();
        // still DRAFT
        assertThat(jdbc.queryForObject(
                "select status from lessons where id = ?::uuid", String.class, id))
                .isEqualTo("DRAFT");
    }

    @Test
    void preview_stripsAnswerKeysFromDraft() throws Exception {
        String draft = """
                {"schemaVersion":1,
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "requiredEvidenceIds":["e1"],
                            "activities":[{"id":"mc","type":"MULTIPLE_CHOICE",
                                           "config":{"question":"q",
                                                     "options":[{"id":"o1"}],
                                                     "correctOptionIds":["o1"],
                                                     "answer":"secret"},
                                           "validation":{"kind":"SCORE","pass":80}}],
                            "nextStageIds":[]}]}
                """;
        String id = createLesson(draft);
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons/" + id + "/preview")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        String payload = om.readTree(res.getResponse().getContentAsString())
                .get("content").toString();
        assertThat(payload).doesNotContain("correctOptionIds");
        assertThat(payload).doesNotContain("\"answer\"");
        assertThat(payload).doesNotContain("requiredEvidenceIds");
        assertThat(payload).doesNotContain("validation");
        assertThat(payload).contains("\"question\":\"q\"");
    }

    @Test
    void preview_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("pv-learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String id = createLesson("{}");
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/preview"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/preview")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void preview_missingLesson_404() throws Exception {
        mvc.perform(post("/api/v1/admin/lessons/" + UUID.randomUUID() + "/preview")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound());
    }
}
