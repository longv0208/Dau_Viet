package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.learning.AttemptItFixture;
import com.dauviet.path.domain.PathNodeType;
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@DisplayName("PATH-02 — Learning Path Hierarchy & Per-Period Progression Integration Tests")
class LearningPathHierarchyAndPeriodIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper om;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;

    private String adminToken;
    private String learnerToken;

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        LearningPathItFixture.ensureDefaultPathSeeded(jdbc);
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        adminToken = AttemptItFixture.token(users, jwt, "admin.hierarchy." + suffix + "@test.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "learner.hierarchy." + suffix + "@test.vn", UserRole.LEARNER);
    }

    @Test
    @DisplayName("Admin tạo cây ERA -> PERIOD -> PHASE hợp lệ; chặn gắn sai cha hoặc gắn event vào ERA với 422 PATH_NODE_INVALID_PARENT")
    void adminHierarchyValidationRules() throws Exception {
        // 1. Tạo bản nháp mới
        MvcResult createDraftRes = mvc.perform(post("/api/v1/admin/learning-path/versions")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "pathCode": "HISTORY_TREE_TEST",
                                  "title": "Lộ trình phân cấp",
                                  "description": "Kiểm thử cây ERA-PERIOD-PHASE"
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode draftJson = om.readTree(createDraftRes.getResponse().getContentAsString());
        UUID versionId = UUID.fromString(draftJson.path("version").path("id").asText());
        long rev = draftJson.path("version").path("revision").asLong();

        // 2. Tạo ERA ở gốc (parentId = null) -> 200 OK
        MvcResult eraRes = mvc.perform(post("/api/v1/admin/learning-path/versions/" + versionId + "/chapters")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedRevision": %d,
                                  "parentId": null,
                                  "nodeType": "ERA",
                                  "code": "ERA_FEUDAL",
                                  "title": "Thời kỳ Phong kiến Độc lập",
                                  "description": "Đại thời kỳ phong kiến",
                                  "startYear": 938,
                                  "endYear": 1858,
                                  "periodLabel": "938 - 1858",
                                  "themeKey": "EARLY_INDEPENDENCE"
                                }
                                """.formatted(rev)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.chapters[0].chapter.nodeType").value("ERA"))
                .andReturn();
        JsonNode afterEra = om.readTree(eraRes.getResponse().getContentAsString());
        UUID eraId = UUID.fromString(afterEra.path("chapters").get(0).path("chapter").path("id").asText());
        rev = afterEra.path("version").path("revision").asLong();

        // 3. Tạo ERA có parentId != null -> 422 PATH_NODE_INVALID_PARENT
        mvc.perform(post("/api/v1/admin/learning-path/versions/" + versionId + "/chapters")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedRevision": %d,
                                  "parentId": "%s",
                                  "nodeType": "ERA",
                                  "code": "ERA_NESTED_BAD",
                                  "title": "ERA lồng sai",
                                  "startYear": 938,
                                  "endYear": 1009,
                                  "periodLabel": "938 - 1009",
                                  "themeKey": "EARLY_INDEPENDENCE"
                                }
                                """.formatted(rev, eraId)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PATH_NODE_INVALID_PARENT"));

        // 4. Tạo PERIOD dưới ERA -> 200 OK
        MvcResult periodRes = mvc.perform(post("/api/v1/admin/learning-path/versions/" + versionId + "/chapters")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedRevision": %d,
                                  "parentId": "%s",
                                  "nodeType": "PERIOD",
                                  "code": "PERIOD_LY",
                                  "title": "Thời nhà Lý",
                                  "startYear": 1009,
                                  "endYear": 1225,
                                  "periodLabel": "1009 - 1225",
                                  "themeKey": "LY_DYNASTY"
                                }
                                """.formatted(rev, eraId)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode afterPeriod = om.readTree(periodRes.getResponse().getContentAsString());
        rev = afterPeriod.path("version").path("revision").asLong();
        UUID periodId = null;
        for (JsonNode chWrapper : afterPeriod.path("chapters")) {
            JsonNode ch = chWrapper.path("chapter");
            if ("PERIOD_LY".equals(ch.path("code").asText())) {
                periodId = UUID.fromString(ch.path("id").asText());
                assertThat(ch.path("parentId").asText()).isEqualTo(eraId.toString());
                assertThat(ch.path("nodeType").asText()).isEqualTo(PathNodeType.PERIOD.name());
            }
        }
        assertThat(periodId).isNotNull();

        // 5. Gắn event trực tiếp vào ERA -> 422 PATH_NODE_INVALID_PARENT
        UUID bachDangId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'bach-dang-938'", UUID.class);
        mvc.perform(post("/api/v1/admin/learning-path/versions/" + versionId + "/chapters/" + eraId + "/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedRevision": %d,
                                  "eventId": "%s",
                                  "participationType": "REQUIRED"
                                }
                                """.formatted(rev, bachDangId)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PATH_NODE_INVALID_PARENT"));

        // 6. Xóa ERA khi vẫn còn PERIOD con -> 422 PATH_NODE_INVALID_PARENT
        mvc.perform(delete("/api/v1/admin/learning-path/versions/" + versionId + "/chapters/" + eraId)
                        .param("expectedRevision", String.valueOf(rev))
                        .header("Authorization", adminToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PATH_NODE_INVALID_PARENT"));
    }

    @Test
    @DisplayName("Mở khóa độc lập theo từng PERIOD, endpoint touch cập nhật lastPeriodCode và tự nâng cấp version")
    void perPeriodProgressionAndTouchAndAutoVersionUpgrade() throws Exception {
        UUID evtLt = jdbc.queryForObject("SELECT id FROM historical_events WHERE slug = 'ly-thai-to-1010'", UUID.class);
        UUID evtNn = jdbc.queryForObject("SELECT id FROM historical_events WHERE slug = 'chien-thang-nhu-nguyet-1077'", UUID.class);
        UUID tplId = jdbc.queryForObject("SELECT id FROM lesson_templates WHERE code = 'HISTORY_DEFAULT'", UUID.class);
        UUID publisherId = jdbc.queryForObject("SELECT id FROM users WHERE email = 'path-fixture@dauviet.test'", UUID.class);

        UUID lesLt = UUID.randomUUID();
        UUID verLt = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO lessons (id, event_id, template_id, title, central_question, objectives_json, draft_json, status, current_version_id)
                VALUES (?::uuid, ?::uuid, ?::uuid, 'Dời đô Thăng Long', 'Câu hỏi?', '[]'::jsonb, '{"schemaVersion":1,"stages":[]}'::jsonb, 'DRAFT', NULL)
                """, lesLt.toString(), evtLt.toString(), tplId.toString());
        jdbc.update("""
                INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_by, published_at)
                VALUES (?::uuid, ?::uuid, 1, 1, '{"schemaVersion":1,"stages":[]}'::jsonb, ?::uuid, now())
                """, verLt.toString(), lesLt.toString(), publisherId.toString());
        jdbc.update("UPDATE lessons SET status = 'PUBLISHED', current_version_id = ?::uuid WHERE id = ?::uuid",
                verLt.toString(), lesLt.toString());
        jdbc.update("""
                INSERT INTO event_completion_policies (id, event_id, policy_version, status, required_lesson_ids, mastery_threshold, published_at)
                VALUES (gen_random_uuid(), ?::uuid, 1, 'PUBLISHED', jsonb_build_array(?::text), 70, now())
                """, evtLt.toString(), lesLt.toString());

        UUID lesNn = UUID.randomUUID();
        UUID verNn = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO lessons (id, event_id, template_id, title, central_question, objectives_json, draft_json, status, current_version_id)
                VALUES (?::uuid, ?::uuid, ?::uuid, 'Phòng tuyến Như Nguyệt', 'Câu hỏi?', '[]'::jsonb, '{"schemaVersion":1,"stages":[]}'::jsonb, 'DRAFT', NULL)
                """, lesNn.toString(), evtNn.toString(), tplId.toString());
        jdbc.update("""
                INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_by, published_at)
                VALUES (?::uuid, ?::uuid, 1, 1, '{"schemaVersion":1,"stages":[]}'::jsonb, ?::uuid, now())
                """, verNn.toString(), lesNn.toString(), publisherId.toString());
        jdbc.update("UPDATE lessons SET status = 'PUBLISHED', current_version_id = ?::uuid WHERE id = ?::uuid",
                verNn.toString(), lesNn.toString());
        jdbc.update("""
                INSERT INTO event_completion_policies (id, event_id, policy_version, status, required_lesson_ids, mastery_threshold, published_at)
                VALUES (gen_random_uuid(), ?::uuid, 1, 'PUBLISHED', jsonb_build_array(?::text), 70, now())
                """, evtNn.toString(), lesNn.toString());

        // Clone version 1 của HISTORY_MAIN sang version 2 DRAFT
        UUID v1Id = jdbc.queryForObject(
                "SELECT id FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND version_no = 1", UUID.class);
        MvcResult cloneRes = mvc.perform(post("/api/v1/admin/learning-path/versions/" + v1Id + "/clone")
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode clonedJson = om.readTree(cloneRes.getResponse().getContentAsString());
        UUID v2Id = UUID.fromString(clonedJson.path("version").path("id").asText());
        long v2Rev = clonedJson.path("version").path("revision").asLong();

        UUID evtBd = jdbc.queryForObject("SELECT id FROM historical_events WHERE slug = 'bach-dang-938'", UUID.class);
        UUID nodeBd = jdbc.queryForObject(
                "SELECT id FROM learning_path_event_nodes WHERE path_version_id = ?::uuid AND event_id = ?::uuid",
                UUID.class, v2Id.toString(), evtBd.toString());
        UUID nodeLt = jdbc.queryForObject(
                "SELECT id FROM learning_path_event_nodes WHERE path_version_id = ?::uuid AND event_id = ?::uuid",
                UUID.class, v2Id.toString(), evtLt.toString());
        UUID nodeNn = jdbc.queryForObject(
                "SELECT id FROM learning_path_event_nodes WHERE path_version_id = ?::uuid AND event_id = ?::uuid",
                UUID.class, v2Id.toString(), evtNn.toString());
        jdbc.update("UPDATE learning_path_event_nodes SET participation_type = 'REQUIRED' WHERE id IN (?::uuid, ?::uuid, ?::uuid)",
                nodeBd.toString(), nodeLt.toString(), nodeNn.toString());
        jdbc.update("INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order) VALUES (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, 1)",
                nodeLt.toString(), evtLt.toString(), lesLt.toString());
        jdbc.update("INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order) VALUES (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, 1)",
                nodeNn.toString(), evtNn.toString(), lesNn.toString());

        // Learner đọc lộ trình khi v1 đang PUBLISHED -> enroll vào v1
        mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathVersion").value(1));

        // Publish v2 -> learner đọc lại tự động nâng cấp lên v2!
        mvc.perform(post("/api/v1/admin/learning-path/versions/" + v2Id + "/publish")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"expectedRevision\": " + v2Rev + "}"))
                .andExpect(status().isOk());

        MvcResult meRes = mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathVersion").value(2))
                .andExpect(jsonPath("$.periodProgress.length()").value(5))
                .andExpect(jsonPath("$.currentByPeriod.EARLY_INDEPENDENCE").isNotEmpty())
                .andExpect(jsonPath("$.currentByPeriod.LY_DYNASTY").isNotEmpty())
                .andReturn();

        JsonNode root = om.readTree(meRes.getResponse().getContentAsString());
        for (JsonNode ch : root.path("chapters")) {
            if ("LY_DYNASTY".equals(ch.path("code").asText())) {
                assertThat(ch.path("events").get(0).path("status").asText()).isEqualTo("AVAILABLE");
                assertThat(ch.path("events").get(1).path("status").asText()).isEqualTo("LOCKED");
            }
            if ("EARLY_INDEPENDENCE".equals(ch.path("code").asText())) {
                assertThat(ch.path("events").get(0).path("status").asText()).isEqualTo("AVAILABLE");
            }
        }

        // Touch LY_DYNASTY -> lastPeriodCode cập nhật sang LY_DYNASTY
        mvc.perform(post("/api/v1/me/learning-path/periods/LY_DYNASTY/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.periodCode").value("LY_DYNASTY"));

        mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastPeriodCode").value("LY_DYNASTY"))
                .andExpect(jsonPath("$.current.eventNodeId").value(nodeLt.toString()));
    }
}
