package com.dauviet.lesson;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

/** Stage sub-resource endpoints on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminLessonStageIT extends AbstractPostgresIT {

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
        admin.setEmail("s@t.vn");
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
    }

    private String url(String suffix) {
        return "/api/v1/admin/lessons/" + lessonId + "/draft" + suffix;
    }

    @Test
    void addStage_201_andList() throws Exception {
        mvc.perform(post(url("/stages"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"CONTEXT\",\"title\":\"Intro\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value("stage"))
                .andExpect(jsonPath("$.type").value("CONTEXT"));
        mvc.perform(get(url("/stages")).header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stages.length()").value(1));
    }

    @Test
    void addStage_invalidType_422() throws Exception {
        mvc.perform(post(url("/stages"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"type\":\"BOGUS\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("DRAFT_SCHEMA_INVALID"))
                .andExpect(jsonPath("$.details.errors[0].code").exists());
    }

    @Test
    void updateStage_200_andPruneOnDelete() throws Exception {
        mvc.perform(post(url("/stages"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"s1\",\"type\":\"CONTEXT\"}"))
                .andExpect(status().isCreated());
        mvc.perform(post(url("/stages"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"s2\",\"type\":\"DISCOVERY\",\"nextStageIds\":[\"s1\"]}"))
                .andExpect(status().isCreated());

        mvc.perform(patch(url("/stages/s2"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Renamed\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Renamed"));

        // Delete s1 -> s2.nextStageIds pruned (else draft has dangling transition)
        mvc.perform(delete(url("/stages/s1")).header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stages.length()").value(1))
                .andExpect(jsonPath("$.stages[0].nextStageIds.length()").value(0));
    }

    @Test
    void updateStage_missing_404() throws Exception {
        mvc.perform(patch(url("/stages/nope"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("STAGE_NOT_FOUND"));
    }

    @Test
    void reorderStages_200_andBadList_400() throws Exception {
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sa\",\"type\":\"CONTEXT\"}"))
                .andExpect(status().isCreated());
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sb\",\"type\":\"DISCOVERY\"}"))
                .andExpect(status().isCreated());

        mvc.perform(put(url("/stages/order"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"orderedIds\":[\"sb\",\"sa\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stages[0].id").value("sb"));

        mvc.perform(put(url("/stages/order"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"orderedIds\":[\"sb\"]}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getStage_200_andGetActivity_200() throws Exception {
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sc\",\"type\":\"CONTEXT\"}"))
                .andExpect(status().isCreated());
        mvc.perform(post(url("/stages/sc/activities")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"ac\",\"type\":\"READ\",\"config\":{\"text\":\"hi\"}}"))
                .andExpect(status().isCreated());

        mvc.perform(get(url("/stages/sc")).header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("sc"))
                .andExpect(jsonPath("$.type").value("CONTEXT"));
        mvc.perform(get(url("/stages/sc/activities/ac")).header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("ac"))
                .andExpect(jsonPath("$.type").value("READ"));
        mvc.perform(get(url("/stages/nope")).header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("STAGE_NOT_FOUND"));
        mvc.perform(get(url("/stages/sc/activities/nope")).header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ACTIVITY_NOT_FOUND"));
    }

    @Test
    void updateStage_staleRowVersion_409() throws Exception {
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sv\",\"type\":\"CONTEXT\"}"))
                .andExpect(status().isCreated());
        MvcResult list = mvc.perform(get(url("/stages")).header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        long rv = om.readTree(list.getResponse().getContentAsString())
                .get("rowVersion").asLong();
        mvc.perform(patch(url("/stages/sv"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\",\"expectedRowVersion\":" + (rv + 9) + "}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void draftEndpoints_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String body = "{\"type\":\"CONTEXT\"}";
        // anonymous -> 401
        mvc.perform(post(url("/stages")).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        mvc.perform(get(url("/stages")))
                .andExpect(status().isUnauthorized());
        // learner -> 403
        mvc.perform(post(url("/stages")).header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mvc.perform(get(url("/stages")).header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void circularTransition_422() throws Exception {
        // nextStageIds pointing at a missing stage -> UNKNOWN_STAGE_ID at SAVE
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sa\",\"type\":\"CONTEXT\",\"nextStageIds\":[\"sb\"]}"))
                .andExpect(status().isUnprocessableEntity());
        // create sa then sb, then point sa->sb while sb->sa already exists => cycle
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sa\",\"type\":\"CONTEXT\"}"))
                .andExpect(status().isCreated());
        mvc.perform(post(url("/stages")).header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"id\":\"sb\",\"type\":\"DISCOVERY\",\"nextStageIds\":[\"sa\"]}"))
                .andExpect(status().isCreated());
        mvc.perform(patch(url("/stages/sa"))
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nextStageIds\":[\"sb\"]}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.details.errors[0].code").value("CIRCULAR_TRANSITION"));
    }
}
