package com.dauviet.lesson;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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

/** Admin lesson + template endpoints on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String adminId;
    private String eventId;
    private String tplId;
    private String disabledTplId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = bearer("a@t.vn", UserRole.CONTENT_ADMIN);
        learnerToken = bearer("l@t.vn", UserRole.LEARNER);

        eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'DRAFT')", eventId);

        tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 'tpl-main', 'Main', 1, '{}'::jsonb, true)", tplId);

        disabledTplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 'tpl-off', 'Off', 1, '{}'::jsonb, false)", disabledTplId);
    }

    private String bearer(String email, UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        if (role == UserRole.CONTENT_ADMIN && adminId == null) {
            adminId = u.getId().toString();
        }
        return "Bearer " + jwt.createAccessToken(u);
    }

    private MvcResult createLesson() throws Exception {
        return mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","templateId":"%s",
                                 "title":"Bạch Đằng","centralQuestion":"Why?",
                                 "objectivesJson":"[\\"o1\\"]","draftJson":"{\\"stages\\":[]}"}
                                """.formatted(eventId, tplId)))
                .andExpect(status().isCreated())
                .andReturn();
    }

    private String lessonIdOf(MvcResult res) throws Exception {
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("id").asText();
    }

    @Test
    void create_201_persistsJsonb() throws Exception {
        MvcResult res = createLesson();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        assertThat(body.get("status").asText()).isEqualTo("DRAFT");
        assertThat(body.get("objectivesJson").asText()).contains("o1");
        assertThat(body.get("draftJson").asText()).contains("stages");
    }

    @Test
    void create_invalidEvent_404() throws Exception {
        mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","templateId":"%s",
                                 "title":"L","centralQuestion":"Q?"}
                                """.formatted(UUID.randomUUID(), tplId)))
                .andExpect(status().isNotFound());
    }

    @Test
    void create_unknownTemplate_404_disabledTemplate_422() throws Exception {
        mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","templateId":"%s",
                                 "title":"L","centralQuestion":"Q?"}
                                """.formatted(eventId, UUID.randomUUID())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("TEMPLATE_NOT_FOUND"));

        mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","templateId":"%s",
                                 "title":"L","centralQuestion":"Q?"}
                                """.formatted(eventId, disabledTplId)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("TEMPLATE_DISABLED"));
    }

    @Test
    void updateDraft_replacesJsonb_preservesVersion() throws Exception {
        String id = lessonIdOf(createLesson());
        MvcResult res = mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"{\\\"schemaVersion\\\":1,\\\"stages\\\":[]}\"}"))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        assertThat(body.get("draftJson").asText()).contains("\"stages\":[]");
        assertThat(body.get("rowVersion").asLong()).isEqualTo(1);
    }

    @Test
    void updateDraft_saveLevelViolations_422WithFieldErrors() throws Exception {
        String id = lessonIdOf(createLesson());
        // Stage id not a string / unknown top-level key -> SAVE errors in details
        mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"{\\\"bogus\\\":1}\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("DRAFT_SCHEMA_INVALID"))
                .andExpect(jsonPath("$.details.errors").isArray());
    }

    @Test
    void updateDraft_invalidJson_422() throws Exception {
        String id = lessonIdOf(createLesson());
        mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"not-json\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("DRAFT_SCHEMA_INVALID"));
        // Non-object JSON also rejected
        mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"[1,2]\"}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void updateDraft_staleRowVersion_409() throws Exception {
        String id = lessonIdOf(createLesson());
        mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"{\\\"a\\\":1}\",\"expectedRowVersion\":99}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void archive_lesson_ok_andDraftEditRejected() throws Exception {
        String id = lessonIdOf(createLesson());
        mvc.perform(post("/api/v1/admin/lessons/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));
        mvc.perform(put("/api/v1/admin/lessons/" + id + "/draft")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"draftJson\":\"{}\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void lessonTemplates_readOnly() throws Exception {
        mvc.perform(get("/api/v1/admin/lesson-templates")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].code").value("tpl-main"));
        mvc.perform(get("/api/v1/admin/lesson-templates/" + tplId)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("tpl-main"));
        mvc.perform(get("/api/v1/admin/lesson-templates/" + UUID.randomUUID())
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void update_templateRebindDraft_ok_publishedRejected() throws Exception {
        // Draft lesson: template rebind is allowed
        String id = lessonIdOf(createLesson());
        String tpl2 = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 'tpl-2', 'T2', 1, '{}'::jsonb, true)", tpl2);
        mvc.perform(patch("/api/v1/admin/lessons/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"templateId\":\"" + tpl2 + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.templateId").value(tpl2));

        // Make the lesson PUBLISHED at DB level (real publish is TASK-0009):
        // insert a lesson_versions snapshot and point current_version_id at it.
        String versionId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_by) "
                  + "values (?::uuid, ?::uuid, 1, 1, '{}'::jsonb, ?::uuid)", versionId, id, adminId);
        jdbc.update("update lessons set current_version_id = ?::uuid, status = 'PUBLISHED' where id = ?::uuid",
                versionId, id);

        // Rebinding template on a PUBLISHED lesson -> 409
        mvc.perform(patch("/api/v1/admin/lessons/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"templateId\":\"" + tplId + "\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
        // But non-template metadata edit on PUBLISHED is still allowed
        mvc.perform(patch("/api/v1/admin/lessons/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Renamed\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Renamed"));
    }

    @Test
    void auth_anon401_learner403() throws Exception {
        mvc.perform(get("/api/v1/admin/lessons")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/lessons").header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/lesson-templates").header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}
