package com.dauviet.animation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * §8 — `AnimationScenePublishService` phải ghi đúng `schema_version` THỰC
 * của manifest (v1 → 1, v2 → 2), không phải `CURRENT_SCHEMA_VERSION`.
 * IT chạy Postgres Testcontainers + Flyway — đọc trực tiếp
 * `animation_scene_versions.schema_version` sau publish.
 */
@SpringBootTest
@AutoConfigureMockMvc
class AnimationScenePublishIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String eventId;
    private String templateId;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = adminToken();
        eventId = newEvent("anim-it");
        templateId = newAnimationTemplate("JOURNEY_MAP");
    }

    private String adminToken() {
        User u = new User();
        u.setId(UUID.randomUUID());
        u.setEmail("admin-anim@it.test");
        u.setPasswordHash("$2a$10$dummyhashplaceholderfortestonly");
        u.setRole(UserRole.CONTENT_ADMIN);
        u.setStatus(UserStatus.ACTIVE);
        users.save(u);
        return "Bearer " + jwt.createAccessToken(u);
    }

    private String newEvent(String slug) {
        String id = UUID.randomUUID().toString();
        jdbc.update("insert into historical_events "
                  + "(id, slug, title, summary, status) "
                  + "values (?::uuid, ?, 'E', 's', 'PUBLISHED')",
                id, slug);
        return id;
    }

    /** Animation template (khác lesson_templates) — renderer JOURNEY_MAP. */
    private String newAnimationTemplate(String rendererCode) {
        String id = UUID.randomUUID().toString();
        jdbc.update(
                "insert into animation_templates "
              + "(id, code, name, renderer_code, renderer_version, "
              + " schema_version, capabilities_json, default_config_json, enabled) "
              + "values (?::uuid, ?, 'T', ?, 1, 1, '{}'::jsonb, '{}'::jsonb, true)",
                id, "tpl-" + rendererCode.toLowerCase(), rendererCode);
        return id;
    }

    /** Manifest v1 — JOURNEY_MAP tối thiểu (không v2 keys). */
    private String manifestV1() {
        return """
                {"schemaVersion":1,"rendererCode":"JOURNEY_MAP",
                 "rendererVersion":1,"title":"Hành trình v1",
                 "canvas":{"aspectRatio":1.6},
                 "map":{"locations":[
                   {"id":"a","x":0.3,"y":0.4,"label":"A"},
                   {"id":"b","x":0.7,"y":0.6,"label":"B"}]},
                 "steps":[{"id":"s1","title":"S1","durationMs":800,
                           "targetState":{"focusLocationId":"a"}}]}
                """;
    }

    /** Manifest v2 — thêm camera + tracks (whitelist v2 keys). */
    private String manifestV2() {
        return """
                {"schemaVersion":2,"rendererCode":"JOURNEY_MAP",
                 "rendererVersion":1,"title":"Hành trình v2",
                 "canvas":{"aspectRatio":1.6},
                 "map":{"locations":[
                   {"id":"a","x":0.3,"y":0.4,"label":"A"},
                   {"id":"b","x":0.7,"y":0.6,"label":"B"}]},
                 "objects":[{"id":"boat","type":"BOAT",
                   "position":{"x":0.2,"y":0.5},"scale":0.14,"layer":1}],
                 "camera":{"initial":{"x":0.5,"y":0.5,"zoom":1.0},
                   "steps":[{"target":{"x":0.3,"y":0.4,"zoom":1.4}}]},
                 "tracks":[{"objectId":"boat","property":"position",
                   "keyframes":[{"tMs":0,"value":{"x":0.2,"y":0.5}},
                                {"tMs":800,"value":{"x":0.6,"y":0.4}}]}],
                 "steps":[{"id":"s1","title":"S1","durationMs":800,
                           "targetState":{"focusLocationId":"a"}}]}
                """;
    }

    private String createScene(String draftJson) throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("templateId", templateId);
        req.put("eventId", eventId);
        req.put("title", "S");
        req.put("draftJson", draftJson);
        MvcResult res = mvc.perform(post("/api/v1/admin/animation-scenes")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
    }

    private String publishScene(String sceneId) throws Exception {
        MvcResult res = mvc.perform(post(
                        "/api/v1/admin/animation-scenes/" + sceneId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("versionId").asText();
    }

    @Test
    void publishV1_recordsSchemaVersion1() throws Exception {
        String sceneId = createScene(manifestV1());
        String versionId = publishScene(sceneId);
        Integer v = jdbc.queryForObject(
                "select schema_version from animation_scene_versions "
              + "where id = ?::uuid",
                Integer.class, versionId);
        assertThat(v).isEqualTo(1);
    }

    @Test
    void publishV2_recordsSchemaVersion2() throws Exception {
        String sceneId = createScene(manifestV2());
        String versionId = publishScene(sceneId);
        Integer v = jdbc.queryForObject(
                "select schema_version from animation_scene_versions "
              + "where id = ?::uuid",
                Integer.class, versionId);
        assertThat(v).isEqualTo(2);
    }

    @Test
    void publishMissingSchemaVersionField_returns422() throws Exception {
        // Thiếu "schemaVersion" → validator MISSING_FIELD → 422; publish
        // không bao giờ chạy tới asInt(1) default. Contract: field bắt buộc.
        String draft = manifestV2().replace("\"schemaVersion\":2,", "");
        String sceneId = createScene(draft);
        mvc.perform(post("/api/v1/admin/animation-scenes/" + sceneId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void publishV1WithV2Keys_returns422OutdatedSchema() throws Exception {
        // v2 keys (camera/tracks) nhưng schemaVersion=1 → validator bắt
        // OUTDATED_SCHEMA → 422 MANIFEST_VALIDATION_FAILED.
        String bad = manifestV2().replace("\"schemaVersion\":2", "\"schemaVersion\":1");
        String sceneId = createScene(bad);
        mvc.perform(post("/api/v1/admin/animation-scenes/" + sceneId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void sceneVersionsEndpoint_listsPublishedSchemaVersion() throws Exception {
        String sceneId = createScene(manifestV2());
        publishScene(sceneId);
        mvc.perform(get("/api/v1/admin/animation-scenes/" + sceneId + "/versions")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].schemaVersion").value(2));
    }
}
