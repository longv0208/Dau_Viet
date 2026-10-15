package com.dauviet.lesson;

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
import com.fasterxml.jackson.databind.ObjectMapper;

/** POST /admin/lessons/{id}/validate — publish-readiness probe. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonValidateIT extends AbstractPostgresIT {

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
        admin.setEmail("v@t.vn");
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
    void validate_emptyDraft_notReady_200() throws Exception {
        String id = createLesson("{}");
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(false))
                .andExpect(jsonPath("$.errors").isArray())
                .andExpect(jsonPath("$.summary.stageCount").value(0));
    }

    @Test
    void validate_fullDraft_ready() throws Exception {
        // An APPROVED evidence the activity can reference at publish level.
        String evId = UUID.randomUUID().toString();
        jdbc.update("insert into evidences (id, event_id, title, evidence_type, source_title, status) "
                  + "values (?::uuid, ?::uuid, 'EV', 'DOC', 'src', 'APPROVED')", evId, eventId);

        String draft = """
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
        String id = createLesson(draft);
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(true))
                .andExpect(jsonPath("$.errors.length()").value(0))
                .andExpect(jsonPath("$.summary.stageCount").value(2))
                .andExpect(jsonPath("$.summary.activityCount").value(2));
        // validate must not create any lesson_versions row
        Integer versions = jdbc.queryForObject(
                "select count(*) from lesson_versions where lesson_id = ?::uuid",
                Integer.class, id);
        org.assertj.core.api.Assertions.assertThat(versions).isZero();
    }

    @Test
    void validate_unresolvedEvidenceRef_notReady() throws Exception {
        String draft = """
                {"schemaVersion":1,
                 "stages":[{"id":"ev","type":"EVIDENCE","required":true,
                            "activities":[{"id":"es","type":"EVIDENCE_SELECT","required":true,
                                           "config":{"visibleEvidenceIds":["%s"]}}],
                            "nextStageIds":[]}]}
                """.formatted(UUID.randomUUID());
        String id = createLesson(draft);
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(false))
                .andExpect(jsonPath("$.errors[?(@.code=='EVIDENCE_NOT_FOUND')]").exists());
    }

    @Test
    void validate_disabledTemplate_error() throws Exception {
        String tpl2 = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't2', 'T2', 1, '{}'::jsonb, false)", tpl2);
        String id = createLesson("{}");
        // PATCH rightly refuses a disabled template (422 TEMPLATE_DISABLED);
        // rebind directly so the readiness probe itself can be asserted.
        jdbc.update("update lessons set template_id = ?::uuid where id = ?::uuid", tpl2, id);
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(false))
                .andExpect(jsonPath("$.errors[?(@.code=='TEMPLATE_DISABLED')]").exists());
    }

    @Test
    void validate_draftEvent_warnsNotBlocks() throws Exception {
        // Fixture event is DRAFT — publish readiness warns EVENT_NOT_PUBLISHED
        // but does not add an error (open product question, see plan).
        String evId = approvedEvidence();
        String id = createLesson(publishableDraft(evId));
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(true))
                .andExpect(jsonPath("$.warnings[?(@.code=='EVENT_NOT_PUBLISHED')]").exists());
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

    @Test
    void validate_templateSchemaMismatch_error() throws Exception {
        String tpl2 = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't2', 'T2', 99, '{}'::jsonb, true)", tpl2);
        String id = createLesson("{}");
        // rebind to schema_version 99 template while still DRAFT
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .patch("/api/v1/admin/lessons/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"templateId\":\"" + tpl2 + "\"}"))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ready").value(false))
                .andExpect(jsonPath("$.errors[?(@.code=='TEMPLATE_SCHEMA_MISMATCH')]").exists());
    }

    @Test
    void validate_missingLesson_404() throws Exception {
        mvc.perform(post("/api/v1/admin/lessons/" + UUID.randomUUID() + "/validate")
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("LESSON_NOT_FOUND"));
    }

    @Test
    void validate_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("v-learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String id = createLesson("{}");
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/validate")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}
