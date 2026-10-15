package com.dauviet.historicalevent.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
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
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Admin event CRUD + status transitions on a real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminEventIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired HistoricalEventRepository events;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;

    @BeforeEach
    void setUp() {
        // Clear authoring dependents before events/users (FK-safe order).
        clearAuthoringTables(jdbc);
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();
        adminToken = bearer("a@t.vn", UserRole.CONTENT_ADMIN);
        learnerToken = bearer("l@t.vn", UserRole.LEARNER);
    }

    private String bearer(String email, UserRole role) {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail(email);
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(role);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        return "Bearer " + jwt.createAccessToken(u);
    }

    private MvcResult createEvent(String slug) throws Exception {
        return mvc.perform(post("/api/v1/admin/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"slug":"%s","title":"T","summary":"S"}
                                """.formatted(slug)))
                .andReturn();
    }

    private String createEventId(String slug) throws Exception {
        MvcResult res = createEvent(slug);
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("id").asText();
    }

    @Test
    void create_201_admin_andListShowsDraft() throws Exception {
        mvc.perform(post("/api/v1/admin/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slug\":\"admin-create-ev\",\"title\":\"T\",\"summary\":\"S\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.slug").value("admin-create-ev"))
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.rowVersion").value(0));
        // Public API must NOT see the draft
        mvc.perform(get("/api/v1/events"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isEmpty());
        // Admin list sees it
        mvc.perform(get("/api/v1/admin/events").header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void create_invalidSlug_400() throws Exception {
        mvc.perform(post("/api/v1/admin/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slug\":\"Bad Slug!\",\"title\":\"T\",\"summary\":\"S\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void create_duplicateSlug_400() throws Exception {
        createEvent("dup-event");
        mvc.perform(post("/api/v1/admin/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slug\":\"dup-event\",\"title\":\"T2\",\"summary\":\"S2\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    void list_filterByStatusAndQ() throws Exception {
        createEvent("ev-draft");
        String publishedId = createEventId("ev-pub");
        mvc.perform(post("/api/v1/admin/events/" + publishedId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/admin/events?status=DRAFT")
                        .header("Authorization", adminToken))
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].slug").value("ev-draft"));
        mvc.perform(get("/api/v1/admin/events?status=PUBLISHED")
                        .header("Authorization", adminToken))
                .andExpect(jsonPath("$.totalElements").value(1));
        mvc.perform(get("/api/v1/admin/events?q=ev-pub")
                        .header("Authorization", adminToken))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void publishThenArchive_flow_andRejectsInvalid() throws Exception {
        String id = createEventId("flow-ev");
        // DRAFT -> ARCHIVED allowed
        // PUBLISHED -> ARCHIVED allowed
        // PUBLISHED -> DRAFT forbidden (no such endpoint; publish twice -> 409)
        mvc.perform(post("/api/v1/admin/events/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PUBLISHED"));
        // Double publish -> 409
        mvc.perform(post("/api/v1/admin/events/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
        // Public now sees it
        mvc.perform(get("/api/v1/events/" + id)).andExpect(status().isOk());
        // Archive
        mvc.perform(post("/api/v1/admin/events/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));
        // Public no longer sees it
        mvc.perform(get("/api/v1/events/" + id)).andExpect(status().isNotFound());
    }

    @Test
    void archive_eventWithActiveLesson_409() throws Exception {
        String eventId = createEventId("ev-with-lesson");
        // Need a lesson referencing it — create template + lesson directly via JDBC.
        String tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 'tpl', 't', 1, '{}'::jsonb, true)", tplId);
        jdbc.update("insert into lessons (id, event_id, template_id, title, central_question) "
                  + "values (?::uuid, ?::uuid, ?::uuid, 'l', 'q?')",
                UUID.randomUUID().toString(), eventId, tplId);

        mvc.perform(post("/api/v1/admin/events/" + eventId + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVENT_IN_USE"));
    }

    @Test
    void update_draftAllowsSlugChange_publishedForbids() throws Exception {
        String id = createEventId("draft-ev");
        // Draft: slug change ok
        mvc.perform(patch("/api/v1/admin/events/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slug\":\"new-slug\",\"title\":\"New Title\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slug").value("new-slug"));
        // Publish then try slug change -> 409
        mvc.perform(post("/api/v1/admin/events/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        mvc.perform(patch("/api/v1/admin/events/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slug\":\"other\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
    }

    @Test
    void update_staleRowVersion_409() throws Exception {
        String id = createEventId("ol-ev");
        // Bump the row by an update
        mvc.perform(patch("/api/v1/admin/events/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"v1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rowVersion").value(1));
        // Client holding stale expectedRowVersion=0 -> 409
        mvc.perform(patch("/api/v1/admin/events/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"v2\",\"expectedRowVersion\":0}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void auth_anon401_learner403() throws Exception {
        mvc.perform(get("/api/v1/admin/events"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/events")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void update_archivedEvent_409() throws Exception {
        String id = createEventId("arch-ev");
        mvc.perform(post("/api/v1/admin/events/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));
        mvc.perform(patch("/api/v1/admin/events/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"post-archive edit\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INVALID_STATUS_TRANSITION"));
    }

    @Test
    void publicApi_backwardCompatible() throws Exception {
        // Seed a PUBLISHED event directly via admin flow, then hit public API.
        String id = createEventId("public-ev");
        mvc.perform(post("/api/v1/admin/events/" + id + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/events"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].slug").value("public-ev"));
    }
}
