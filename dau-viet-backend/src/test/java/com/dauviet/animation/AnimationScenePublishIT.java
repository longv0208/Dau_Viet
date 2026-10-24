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
import com.fasterxml.jackson.databind.JsonNode;
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

    /** Manifest v1 — JOURNEY_MAP tối thiểu (không v2 keys), đủ field
     *  bắt buộc: locations[].name, sourceReferences, disclaimer,
     *  targetState.focusedLocationId. */
    private String manifestV1() {
        return """
                {"schemaVersion":1,"rendererCode":"JOURNEY_MAP",
                 "rendererVersion":1,"title":"Hành trình v1",
                 "disclaimer":"Sơ đồ minh họa, không phải bản đồ địa lý chính xác.",
                 "sourceReferences":[{"title":"Đại Việt sử ký toàn thư"}],
                 "canvas":{"aspectRatio":1.6},
                 "map":{"locations":[
                   {"id":"a","x":0.3,"y":0.4,"name":"A"},
                   {"id":"b","x":0.7,"y":0.6,"name":"B"}]},
                 "steps":[{"id":"s1","title":"S1","durationMs":800,
                           "targetState":{"focusedLocationId":"a"}}]}
                """;
    }

    /** Manifest v2 — thêm camera + tracks (whitelist v2 keys). */
    private String manifestV2() {
        return """
                {"schemaVersion":2,"rendererCode":"JOURNEY_MAP",
                 "rendererVersion":1,"title":"Hành trình v2",
                 "disclaimer":"Sơ đồ minh họa, không phải bản đồ địa lý chính xác.",
                 "sourceReferences":[{"title":"Đại Việt sử ký toàn thư"}],
                 "canvas":{"aspectRatio":1.6},
                 "map":{"locations":[
                   {"id":"a","x":0.3,"y":0.4,"name":"A"},
                   {"id":"b","x":0.7,"y":0.6,"name":"B"}]},
                 "objects":[{"id":"boat","type":"BOAT",
                   "position":{"x":0.2,"y":0.5},"scale":0.14,"layer":1}],
                 "camera":{"initial":{"x":0.5,"y":0.5,"zoom":1.0},
                   "steps":[{"target":{"x":0.3,"y":0.4,"zoom":1.4}}]},
                 "tracks":[{"objectId":"boat","property":"position",
                   "keyframes":[{"tMs":0,"value":{"x":0.2,"y":0.5}},
                                {"tMs":800,"value":{"x":0.6,"y":0.4}}]}],
                 "steps":[{"id":"s1","title":"S1","durationMs":800,
                           "targetState":{"focusedLocationId":"a"}}]}
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

    @Test
    void publishedVersion_isImmutable() throws Exception {
        // Trigger trg_animation_scene_versions_immutable (V14) reject
        // UPDATE/DELETE trên snapshot đã publish — sửa trực tiếp phải fail.
        String sceneId = createScene(manifestV2());
        String versionId = publishScene(sceneId);
        org.assertj.core.api.Assertions.assertThatThrownBy(() ->
                jdbc.update("update animation_scene_versions "
                          + "set snapshot_json = '{\"tampered\":true}'::jsonb "
                          + "where id = ?::uuid", versionId))
                .hasMessageContaining("immutable");
    }

    /* ---------- lesson publish pin + attempt pinning (FIX-01.7/8) ---- */

    /** lesson_templates row — schema_version=1 khớp DraftSchema.CURRENT_VERSION. */
    private String newLessonTemplate() {
        String id = UUID.randomUUID().toString();
        jdbc.update(
                "insert into lesson_templates "
              + "(id, code, name, description, schema_version, preset_json, enabled) "
              + "values (?::uuid, ?, 'T', 'd', 1, '{}'::jsonb, true)",
                id, "tpl-" + UUID.randomUUID().toString().substring(0, 8));
        return id;
    }

    /** Draft lesson hợp lệ theo DraftSchema.STAGE_ALLOWED_ACTIVITIES:
     *  CONTEXT chỉ chứa READ/VIEW_IMAGE — MULTIPLE_CHOICE phải nằm trong
     *  VERIFICATION. Hai stage: ctx (READ pin animation) → verify (MC). */
    private String lessonDraft(String sceneVersionId) {
        return """
                {"schemaVersion":1,
                 "stages":[
                   {"id":"ctx","type":"CONTEXT","required":true,
                    "nextStageIds":["verify"],
                    "activities":[
                      {"id":"read1","type":"READ","required":false,
                       "config":{"text":"Đọc.",
                         "animationSceneVersionId":"%s"}}]},
                   {"id":"verify","type":"VERIFICATION","required":true,
                    "nextStageIds":[],
                    "activities":[
                      {"id":"mc1","type":"MULTIPLE_CHOICE","required":true,
                       "config":{"question":"Q?",
                         "options":[{"id":"o1","label":"A"},
                                    {"id":"o2","label":"B"}],
                         "correctOptionIds":["o1"]}}]}],
                 "completion":{"requireAllRequiredStages":true}}
                """.formatted(sceneVersionId);
    }

    private String createLesson(String lessonTemplateId, String draftJson)
            throws Exception {
        Map<String, Object> req = new LinkedHashMap<>();
        req.put("templateId", lessonTemplateId);
        req.put("eventId", eventId);
        req.put("title", "L");
        req.put("centralQuestion", "Q?");
        // draftJson là raw JSONB object STRING trong create request.
        req.put("draftJson", draftJson);
        MvcResult res = mvc.perform(post("/api/v1/admin/lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isCreated()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("id").asText();
    }

    private String publishLesson(String lessonId) throws Exception {
        MvcResult res = mvc.perform(post(
                        "/api/v1/admin/lessons/" + lessonId + "/publish")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk()).andReturn();
        return om.readTree(res.getResponse().getContentAsString())
                .get("lessonVersionId").asText();
    }

    @Test
    void lessonPublish_pinsAnimationSceneVersion() throws Exception {
        String sceneId = createScene(manifestV2());
        String sceneVersionId = publishScene(sceneId);
        String lessonTpl = newLessonTemplate();
        String lessonId = createLesson(lessonTpl, lessonDraft(sceneVersionId));
        String lessonVersionId = publishLesson(lessonId);

        // Snapshot phải embed animationManifest có sceneVersionId đúng —
        // pin immutable, không resolve lại current version khi render.
        String snap = jdbc.queryForObject(
                "select snapshot_json::text from lesson_versions "
              + "where id = ?::uuid",
                String.class, lessonVersionId);
        JsonNode sv = om.readTree(snap)
                .path("stages").get(0).path("activities").get(0)
                .path("config").path("animationManifest");
        assertThat(sv.path("sceneVersionId").asText()).isEqualTo(sceneVersionId);
        assertThat(sv.path("manifest").path("schemaVersion").asInt()).isEqualTo(2);
    }

    @Test
    void existingAttempt_unchangedWhenScenePublishesNewVersion() throws Exception {
        // Scene v1 → publish → lesson pin version đó → learner attempt
        // (insert trực tiếp vì cần user + lesson_version). Sau đó publish
        // scene version mới — attempt vẫn pin lesson_version cũ → không
        // drift.
        String sceneId = createScene(manifestV1());
        String sceneVersionId = publishScene(sceneId);
        String lessonTpl = newLessonTemplate();
        String lessonId = createLesson(lessonTpl, lessonDraft(sceneVersionId));
        String lessonVersionId = publishLesson(lessonId);

        // Learner + attempt pin lesson_version_id (snapshot-level pinning).
        String learnerId = UUID.randomUUID().toString();
        jdbc.update("insert into users (id, email, password_hash, role, status) "
                  + "values (?::uuid, ?, '$2a$10$dummyhashplaceholderfortestonly',"
                  + " 'LEARNER'::varchar, 'ACTIVE'::varchar)",
                learnerId, "learner-anim@it.test");
        String attemptId = UUID.randomUUID().toString();
        jdbc.update("insert into learner_attempts "
                  + "(id, user_id, lesson_version_id, status, state_json) "
                  + "values (?::uuid, ?::uuid, ?::uuid, 'IN_PROGRESS', '{}'::jsonb)",
                attemptId, learnerId, lessonVersionId);

        // Publish scene version 2 (draft đổi title) — version cũ + lesson
        // snapshot + attempt không đổi.
        jdbc.update("update animation_scenes set draft_json = ?::jsonb "
                  + "where id = ?::uuid",
                manifestV1().replace("Hành trình v1", "Hành trình v1.1"),
                sceneId);
        String sceneV2 = publishScene(sceneId);
        assertThat(sceneV2).isNotEqualTo(sceneVersionId);

        String attemptVersion = jdbc.queryForObject(
                "select lesson_version_id::text from learner_attempts "
              + "where id = ?::uuid",
                String.class, attemptId);
        assertThat(attemptVersion).isEqualTo(lessonVersionId);
        String snap = jdbc.queryForObject(
                "select snapshot_json::text from lesson_versions "
              + "where id = ?::uuid",
                String.class, lessonVersionId);
        // Snapshot pin v1 → manifest.schemaVersion phải vẫn là 1.
        assertThat(om.readTree(snap).path("stages").get(0)
                .path("activities").get(0).path("config")
                .path("animationManifest").path("manifest")
                .path("schemaVersion").asInt()).isEqualTo(1);
    }
}
