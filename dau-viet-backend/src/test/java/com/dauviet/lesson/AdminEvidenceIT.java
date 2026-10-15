package com.dauviet.lesson;

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
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Admin evidence CRUD on real Postgres. Requires Docker. */
@SpringBootTest
@AutoConfigureMockMvc
class AdminEvidenceIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String eventId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        User admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail("ev@t.vn");
        admin.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        admin.setRole(UserRole.CONTENT_ADMIN);
        admin.setStatus(UserStatus.ACTIVE);
        users.save(admin);
        adminToken = "Bearer " + jwt.createAccessToken(admin);

        eventId = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events (id, slug, title, summary, status) "
                  + "values (?::uuid, 'e1', 'E', 's', 'DRAFT')", eventId);
    }

    private MvcResult createEvidence() throws Exception {
        return mvc.perform(post("/api/v1/admin/evidences")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","title":"Thương dặm ngày xưa",
                                 "evidenceType":"PRIMARY_SOURCE","sourceTitle":"Đại Việt sử ký"}
                                """.formatted(eventId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andReturn();
    }

    private String idOf(MvcResult res) throws Exception {
        JsonNode body = om.readTree(res.getResponse().getContentAsString());
        return body.get("id").asText();
    }

    @Test
    void create_201_get_200_list_filtered() throws Exception {
        String id = idOf(createEvidence());
        mvc.perform(get("/api/v1/admin/evidences/" + id)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Thương dặm ngày xưa"));
        mvc.perform(get("/api/v1/admin/evidences?eventId=" + eventId)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1));
        mvc.perform(get("/api/v1/admin/evidences?status=APPROVED")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(0));
    }

    @Test
    void create_badEvent_404_badAsset_404_badReliability_400() throws Exception {
        mvc.perform(post("/api/v1/admin/evidences")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","title":"x","evidenceType":"DOC","sourceTitle":"s"}
                                """.formatted(UUID.randomUUID())))
                .andExpect(status().isNotFound());

        mvc.perform(post("/api/v1/admin/evidences")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","title":"x","evidenceType":"DOC","sourceTitle":"s",
                                 "assetId":"%s"}
                                """.formatted(eventId, UUID.randomUUID())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ASSET_NOT_FOUND"));

        mvc.perform(post("/api/v1/admin/evidences")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"eventId":"%s","title":"x","evidenceType":"DOC","sourceTitle":"s",
                                 "reliability":"BOGUS"}
                                """.formatted(eventId)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void approve_and_archive_flow() throws Exception {
        String id = idOf(createEvidence());
        mvc.perform(post("/api/v1/admin/evidences/" + id + "/approve")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"));
        // approve again -> 409
        mvc.perform(post("/api/v1/admin/evidences/" + id + "/approve")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict());
        // archive approved is fine
        mvc.perform(post("/api/v1/admin/evidences/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARCHIVED"));
        // archived cannot be edited
        mvc.perform(patch("/api/v1/admin/evidences/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"nope\"}"))
                .andExpect(status().isConflict());
        // and cannot be archived twice
        mvc.perform(post("/api/v1/admin/evidences/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict());
    }

    @Test
    void archive_inUseByPublishedSnapshot_409() throws Exception {
        String id = idOf(createEvidence());
        // Build a published lesson snapshot that mentions the evidence id.
        String tplId = UUID.randomUUID().toString();
        jdbc.update("insert into lesson_templates (id, code, name, schema_version, preset_json, enabled) "
                  + "values (?::uuid, 't', 'T', 1, '{}'::jsonb, true)", tplId);
        String lessonId = UUID.randomUUID().toString();
        String versionId = UUID.randomUUID().toString();
        String adminId = jdbc.queryForObject(
                "select id::text from users limit 1", String.class);
        jdbc.update("insert into lessons (id, event_id, template_id, title, central_question, status, created_by) "
                  + "values (?::uuid, ?::uuid, ?::uuid, 'L', 'Q?', 'DRAFT', ?::uuid)",
                lessonId, eventId, tplId, adminId);
        jdbc.update("insert into lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_by) "
                  + "values (?::uuid, ?::uuid, 1, 1, ?::jsonb, ?::uuid)",
                versionId, lessonId, "{\"refs\":[\"" + id + "\"]}", adminId);
        jdbc.update("update lessons set current_version_id = ?::uuid, status = 'PUBLISHED' where id = ?::uuid",
                versionId, lessonId);

        mvc.perform(post("/api/v1/admin/evidences/" + id + "/archive")
                        .header("Authorization", adminToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EVIDENCE_IN_USE"));
    }

    @Test
    void update_200_andStaleVersion_409() throws Exception {
        MvcResult res = createEvidence();
        String id = idOf(res);
        long rv = om.readTree(res.getResponse().getContentAsString())
                .get("rowVersion").asLong();
        mvc.perform(patch("/api/v1/admin/evidences/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Renamed\",\"expectedRowVersion\":" + rv + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Renamed"));
        mvc.perform(patch("/api/v1/admin/evidences/" + id)
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\",\"expectedRowVersion\":99}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("OPTIMISTIC_LOCK_CONFLICT"));
    }

    @Test
    void get_missing_404() throws Exception {
        mvc.perform(get("/api/v1/admin/evidences/" + UUID.randomUUID())
                        .header("Authorization", adminToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVIDENCE_NOT_FOUND"));
    }

    @Test
    void evidenceEndpoints_anon401_learner403() throws Exception {
        User learner = new User();
        learner.setId(UUID.randomUUID());
        learner.setEmail("ev-learn@t.vn");
        learner.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        learner.setRole(UserRole.LEARNER);
        learner.setStatus(UserStatus.ACTIVE);
        users.save(learner);
        String learnerToken = "Bearer " + jwt.createAccessToken(learner);

        String body = """
                {"eventId":"%s","title":"x","evidenceType":"DOC","sourceTitle":"s"}
                """.formatted(eventId);
        mvc.perform(post("/api/v1/admin/evidences")
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/evidences"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/admin/evidences")
                        .header("Authorization", learnerToken)
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/admin/evidences")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());
    }
}
