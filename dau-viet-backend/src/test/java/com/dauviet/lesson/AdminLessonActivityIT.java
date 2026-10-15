package com.dauviet.lesson;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
import com.fasterxml.jackson.databind.ObjectMapper;

/** Activity sub-resource endpoints on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonActivityIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String lessonId;

    @BeforeEach
    void setUp() throws Exception {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail("act@t.vn");
        admin.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        adminToken = "Bearer " + jwt.createAccessToken(admin);

        String eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'DRAFT')", eventId);
        String tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't', 'T', 1, '{}'::jsonb, true)", tplId);
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","templateId":"%s","title":"L","centralQuestion":"Q?"}
                                """.formatted(eventId, tplId)))
                .andExpect(status().isCreated()).andReturn();
        lessonId = om.readTree(res.getResponse().getContentAsString()).get("id").asText();
        // one REASONING stage to host MATCHING/REASONING_CONNECT/READ
        mvc.perform(post(url("/stages"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"rs\",\"type\":\"REASONING\"}"))
                .andExpect(status().isCreated());
    }

    private String url(String suffix) {
        return "/api/v1/admin/lessons/" + lessonId + "/draft" + suffix;
    }

    @Test
    void addActivity_201_inAllowedStage() throws Exception {
        mvc.perform(post(url("/stages/rs/activities"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"READ\",\"config\":{\"text\":\"Hello\"}}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value("act"))
                .andExpect(jsonPath("$.type").value("READ"));
    }

    @Test
    void addActivity_mismatchedType_422() throws Exception {
        // EVIDENCE_SELECT is not allowed inside a REASONING stage
        mvc.perform(post(url("/stages/rs/activities"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"EVIDENCE_SELECT\",\"config\":{}}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.details.errors[0].code").value("STAGE_ACTIVITY_MISMATCH"));
    }

    @Test
    void addActivity_missingStage_404() throws Exception {
        mvc.perform(post(url("/stages/nope/activities"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"READ\",\"config\":{\"text\":\"x\"}}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("STAGE_NOT_FOUND"));
    }

    @Test
    void updateAndRemoveActivity() throws Exception {
        mvc.perform(post(url("/stages/rs/activities"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"ma\",\"type\":\"MATCHING\",\"config\":{\"pairs\":["
                                + "{\"left\":{\"id\":\"l1\"},\"right\":{\"id\":\"r1\"}},"
                                + "{\"left\":{\"id\":\"l2\"},\"right\":{\"id\":\"r2\"}}]}}"))
                .andExpect(status().isCreated());
        mvc.perform(patch(url("/stages/rs/activities/ma"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"instruction\":\"Match them\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.instruction").value("Match them"));
        mvc.perform(delete(url("/stages/rs/activities/ma"))
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities.length()").value(0));
        mvc.perform(delete(url("/stages/rs/activities/ma"))
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ACTIVITY_NOT_FOUND"));
    }

    @Test
    void reorderActivities_200() throws Exception {
        mvc.perform(post(url("/stages/rs/activities")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"a1\",\"type\":\"READ\",\"config\":{\"text\":\"1\"}}"))
                .andExpect(status().isCreated());
        mvc.perform(post(url("/stages/rs/activities")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"a2\",\"type\":\"READ\",\"config\":{\"text\":\"2\"}}"))
                .andExpect(status().isCreated());
        mvc.perform(put(url("/stages/rs/activities/order"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"orderedIds\":[\"a2\",\"a1\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activities[0].id").value("a2"));
    }
}


