package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@DisplayName("F1 (Issue #26) — End-to-End Period Learning Flow & Heritage Map Integration Tests")
class LearningFlowHeritageEndToEndIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper om;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;

    private static final String MC_CONFIG =
            "{\"question\":\"Vì sao Ngô Quyền đóng cọc trên sông Bạch Đằng?\","
            + "\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
            + "\"correctOptionIds\":[\"o1\"]}";

    private String adminToken;
    private String learnerToken;

    private UUID evtHungVuongId;
    private UUID evtBachDangId;
    private UUID evtLyThaiToId;
    private UUID evtNhuNguyetId;
    private String tplId;

    private String lessonBachDangId;
    private String lessonLyThaiToId;
    private String lessonNhuNguyetId;
    private String outOfPathLessonId;

    private UUID nodeBachDangId;
    private UUID nodeLyThaiToId;
    private UUID nodeNhuNguyetId;
    private UUID locBachDangId;

    @BeforeEach
    void setUp() throws Exception {
        clearAuthoringTables(jdbc);
        LearningPathItFixture.ensureDefaultPathSeeded(jdbc);

        String suffix = UUID.randomUUID().toString().substring(0, 8);
        adminToken = AttemptItFixture.token(users, jwt, "admin.f1." + suffix + "@test.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "learner.f1." + suffix + "@test.vn", UserRole.LEARNER);

        evtHungVuongId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'hung-vuong-van-lang'", UUID.class);
        evtBachDangId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'bach-dang-938'", UUID.class);
        evtLyThaiToId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'ly-thai-to-1010'", UUID.class);
        evtNhuNguyetId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'chien-thang-nhu-nguyet-1077'", UUID.class);
        tplId = jdbc.queryForObject(
                "SELECT id::text FROM lesson_templates WHERE code = 'HISTORY_DEFAULT'", String.class);

        String evBd = AttemptItFixture.newEvidence(jdbc, evtBachDangId.toString());
        String evLt = AttemptItFixture.newEvidence(jdbc, evtLyThaiToId.toString());
        String evNn = AttemptItFixture.newEvidence(jdbc, evtNhuNguyetId.toString());

        lessonBachDangId = AttemptItFixture.publishLesson(
                mvc, om, adminToken, evtBachDangId.toString(), tplId, AttemptItFixture.draftTwoStage(evBd, MC_CONFIG));
        lessonLyThaiToId = AttemptItFixture.publishLesson(
                mvc, om, adminToken, evtLyThaiToId.toString(), tplId, AttemptItFixture.draftTwoStage(evLt, MC_CONFIG));
        lessonNhuNguyetId = AttemptItFixture.publishLesson(
                mvc, om, adminToken, evtNhuNguyetId.toString(), tplId, AttemptItFixture.draftTwoStage(evNn, MC_CONFIG));
        outOfPathLessonId = AttemptItFixture.publishLesson(
                mvc, om, adminToken, evtBachDangId.toString(), tplId, AttemptItFixture.draftTwoStage(evBd, MC_CONFIG));

        // Ensure published completion policies reference the playable lessons
        jdbc.update("DELETE FROM event_completion_policies WHERE event_id IN (?::uuid, ?::uuid, ?::uuid)",
                evtBachDangId.toString(), evtLyThaiToId.toString(), evtNhuNguyetId.toString());
        jdbc.update("""
                INSERT INTO event_completion_policies (id, event_id, policy_version, status, required_lesson_ids, mastery_threshold, published_at)
                VALUES (gen_random_uuid(), ?::uuid, 1, 'PUBLISHED', jsonb_build_array(?::text), 70, now()),
                       (gen_random_uuid(), ?::uuid, 1, 'PUBLISHED', jsonb_build_array(?::text), 70, now()),
                       (gen_random_uuid(), ?::uuid, 1, 'PUBLISHED', jsonb_build_array(?::text), 70, now())
                """,
                evtBachDangId.toString(), lessonBachDangId,
                evtLyThaiToId.toString(), lessonLyThaiToId,
                evtNhuNguyetId.toString(), lessonNhuNguyetId);

        // Build hierarchical HISTORY_MAIN v2 (ERA -> PERIOD -> EVENT -> LESSON)
        jdbc.execute("TRUNCATE TABLE learning_path_lesson_nodes, learning_path_event_nodes, "
                + "learning_path_chapters, learning_path_versions CASCADE");

        UUID v2Id = UUID.randomUUID();
        UUID eraAncientId = UUID.randomUUID();
        UUID eraFeudalId = UUID.randomUUID();
        UUID periodFoundingId = UUID.randomUUID();
        UUID periodEarlyIndepId = UUID.randomUUID();
        UUID periodLyId = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO learning_path_versions (id, path_code, version_no, title, description, status, published_at, created_at, updated_at)
                VALUES (?::uuid, 'HISTORY_MAIN', 2, 'Hành trình Lịch sử Việt Nam', 'Lộ trình phân cấp ERA -> PERIOD', 'DRAFT', NULL, now(), now())
                """, v2Id.toString());

        jdbc.update("""
                INSERT INTO learning_path_chapters (id, path_version_id, parent_id, node_type, code, title, description, start_year, end_year, period_label, sort_order, theme_key)
                VALUES (?::uuid, ?::uuid, NULL, 'ERA', 'ERA_ANCIENT', 'Thời đại Dựng nước', 'Văn minh sông Hồng', -700, -179, 'TK VII TCN - 179 TCN', 1, 'FOUNDING_ERA'),
                       (?::uuid, ?::uuid, NULL, 'ERA', 'ERA_FEUDAL', 'Thời kỳ Phong kiến Độc lập', 'Kỷ nguyên tự chủ', 938, 1858, '938 - 1858', 2, 'EARLY_INDEPENDENCE'),
                       (?::uuid, ?::uuid, ?::uuid, 'PERIOD', 'FOUNDING_ERA', 'Buổi đầu dựng nước', 'Thời Hùng Vương', -700, -179, 'TK VII TCN - 179 TCN', 1, 'FOUNDING_ERA'),
                       (?::uuid, ?::uuid, ?::uuid, 'PERIOD', 'EARLY_INDEPENDENCE', 'Buổi đầu độc lập tự chủ', 'Chiến thắng Bạch Đằng', 938, 1009, '938 - 1009', 1, 'EARLY_INDEPENDENCE'),
                       (?::uuid, ?::uuid, ?::uuid, 'PERIOD', 'LY_DYNASTY', 'Thời nhà Lý', 'Thăng Long & Như Nguyệt', 1009, 1225, '1009 - 1225', 2, 'LY_DYNASTY')
                """,
                eraAncientId.toString(), v2Id.toString(),
                eraFeudalId.toString(), v2Id.toString(),
                periodFoundingId.toString(), v2Id.toString(), eraAncientId.toString(),
                periodEarlyIndepId.toString(), v2Id.toString(), eraFeudalId.toString(),
                periodLyId.toString(), v2Id.toString(), eraFeudalId.toString());

        UUID nodeHungVuongId = UUID.randomUUID();
        nodeBachDangId = UUID.randomUUID();
        nodeLyThaiToId = UUID.randomUUID();
        nodeNhuNguyetId = UUID.randomUUID();

        jdbc.update("""
                INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order, participation_type)
                VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, 1, 'EXPLORATION_ONLY'),
                       (?::uuid, ?::uuid, ?::uuid, ?::uuid, 1, 'REQUIRED'),
                       (?::uuid, ?::uuid, ?::uuid, ?::uuid, 1, 'REQUIRED'),
                       (?::uuid, ?::uuid, ?::uuid, ?::uuid, 2, 'REQUIRED')
                """,
                nodeHungVuongId.toString(), periodFoundingId.toString(), v2Id.toString(), evtHungVuongId.toString(),
                nodeBachDangId.toString(), periodEarlyIndepId.toString(), v2Id.toString(), evtBachDangId.toString(),
                nodeLyThaiToId.toString(), periodLyId.toString(), v2Id.toString(), evtLyThaiToId.toString(),
                nodeNhuNguyetId.toString(), periodLyId.toString(), v2Id.toString(), evtNhuNguyetId.toString());

        jdbc.update("""
                INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order)
                VALUES (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, 1),
                       (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, 1),
                       (gen_random_uuid(), ?::uuid, ?::uuid, ?::uuid, 1)
                """,
                nodeBachDangId.toString(), evtBachDangId.toString(), lessonBachDangId,
                nodeLyThaiToId.toString(), evtLyThaiToId.toString(), lessonLyThaiToId,
                nodeNhuNguyetId.toString(), evtNhuNguyetId.toString(), lessonNhuNguyetId);

        jdbc.update("UPDATE learning_path_versions SET status = 'PUBLISHED', published_at = now() WHERE id = ?::uuid",
                v2Id.toString());

        // Create and publish heritage location linked to Bạch Đằng 938 with ANY unlock rule + PUBLIC_PREVIEW & UNLOCKED_ONLY media
        MvcResult createLocRes = mvc.perform(post("/api/v1/admin/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "slug": "bai-coc-bach-dang-e2e",
                                  "title": "Bãi cọc Bạch Đằng (Yên Giang)",
                                  "shortSummary": "Trận địa cọc gỗ lim năm 938",
                                  "description": "Di tích trận địa cọc ngầm trên sông Bạch Đằng",
                                  "kind": "BATTLEFIELD",
                                  "latitude": 20.9392,
                                  "longitude": 106.7631,
                                  "coordinatePrecision": "EXACT",
                                  "visibility": "ALWAYS_VISIBLE",
                                  "unlockRuleMode": "ANY",
                                  "displayOrder": 1
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        locBachDangId = UUID.fromString(
                om.readTree(createLocRes.getResponse().getContentAsString()).get("id").asText());

        mvc.perform(put("/api/v1/admin/map-locations/" + locBachDangId + "/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                [{"eventId": "%s", "role": "PRIMARY", "sortOrder": 0}]
                                """.formatted(evtBachDangId)))
                .andExpect(status().isOk());

        mvc.perform(put("/api/v1/admin/map-locations/" + locBachDangId + "/unlock-lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"unlockRuleMode": "ANY", "lessonIds": ["%s"]}
                                """.formatted(lessonBachDangId)))
                .andExpect(status().isOk());

        mvc.perform(put("/api/v1/admin/map-locations/" + locBachDangId + "/media")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                [
                                  {
                                    "mediaType": "IMAGE_2D",
                                    "title": "Toàn cảnh sông Bạch Đằng",
                                    "caption": "Ảnh xem trước công khai",
                                    "externalUrl": "https://example.com/bach-dang-preview.jpg",
                                    "visibility": "PUBLIC_PREVIEW",
                                    "sortOrder": 0
                                  },
                                  {
                                    "mediaType": "PANORAMA_360",
                                    "title": "Toàn cảnh 360 bãi cọc Yên Giang",
                                    "caption": "Tư liệu mở khóa sau khi hoàn thành bài học",
                                    "externalUrl": "https://example.com/bach-dang-360.jpg",
                                    "visibility": "UNLOCKED_ONLY",
                                    "sortOrder": 1
                                  }
                                ]
                                """))
                .andExpect(status().isOk());

        long locRowVer = om.readTree(mvc.perform(get("/api/v1/admin/map-locations/" + locBachDangId)
                        .header("Authorization", adminToken))
                .andReturn().getResponse().getContentAsString()).get("rowVersion").asLong();

        mvc.perform(post("/api/v1/admin/map-locations/" + locBachDangId + "/status?status=PUBLISHED&expectedRowVersion=" + locRowVer)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());
    }

    private JsonNode completeLesson(String token, String lessonId) throws Exception {
        MvcResult started = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andReturn();
        String attemptId = om.readTree(started.getResponse().getContentAsString()).get("attemptId").asText();

        mvc.perform(get("/api/v1/attempts/" + attemptId + "/current")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activity.id").value("r1"));

        mvc.perform(post("/api/v1/attempts/" + attemptId + "/activities/r1/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":{}}"))
                .andExpect(status().isOk());

        mvc.perform(post("/api/v1/attempts/" + attemptId + "/activities/mc/submissions")
                        .header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"answer\":{\"selectedOptionIds\":[\"o1\"]}}"))
                .andExpect(status().isOk());

        MvcResult completeRes = mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", token))
                .andExpect(status().isOk())
                .andReturn();
        return om.readTree(completeRes.getResponse().getContentAsString());
    }

    @Test
    @DisplayName("AC-1: Luồng Trang chủ -> Thời kỳ -> Sự kiện -> Bài -> Kết quả có địa điểm -> Bản đồ chạy trên backend thật")
    void fullJourney_homeToPeriodToEventToLessonToUnlockedLocationAndMap() throws Exception {
        // 1. Trang chủ: GET /api/v1/me/learning-path
        mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathCode").value("HISTORY_MAIN"))
                .andExpect(jsonPath("$.pathVersion").value(2))
                .andExpect(jsonPath("$.enrolled").value(true))
                .andExpect(jsonPath("$.periodProgress.length()").value(3))
                .andExpect(jsonPath("$.currentByPeriod.EARLY_INDEPENDENCE.eventNodeId").value(nodeBachDangId.toString()))
                .andExpect(jsonPath("$.currentByPeriod.EARLY_INDEPENDENCE.lessonId").value(lessonBachDangId));

        // 2. Chọn thời kỳ: POST /api/v1/me/learning-path/periods/EARLY_INDEPENDENCE/touch
        mvc.perform(post("/api/v1/me/learning-path/periods/EARLY_INDEPENDENCE/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.periodCode").value("EARLY_INDEPENDENCE"));

        // 3. Sự kiện: GET /api/v1/events/{id}, /lessons, /me/events/{id}/progress
        mvc.perform(get("/api/v1/events/" + evtBachDangId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slug").value("bach-dang-938"));

        mvc.perform(get("/api/v1/events/" + evtBachDangId + "/lessons")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/me/events/" + evtBachDangId + "/progress")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.requiredLessonsCompleted").value(0))
                .andExpect(jsonPath("$.requiredLessonsTotal").value(1));

        // Trước khi học xong bài: địa điểm trên Bản đồ đang LOCKED, chỉ hiển thị 1 media PUBLIC_PREVIEW
        mvc.perform(get("/api/v1/map/locations/" + locBachDangId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(false))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"))
                .andExpect(jsonPath("$.media.length()").value(1))
                .andExpect(jsonPath("$.media[0].visibility").value("PUBLIC_PREVIEW"));

        // 4 & 5. Bài -> Kết quả có địa điểm vừa mở khóa (newlyUnlockedLocations)
        JsonNode completeBody = completeLesson(learnerToken, lessonBachDangId);
        assertThat(completeBody.path("status").asText()).isEqualTo("COMPLETED");
        JsonNode newlyUnlocked = completeBody.path("newlyUnlockedLocations");
        assertThat(newlyUnlocked.size()).isEqualTo(1);
        assertThat(newlyUnlocked.get(0).path("locationId").asText()).isEqualTo(locBachDangId.toString());
        assertThat(newlyUnlocked.get(0).path("slug").asText()).isEqualTo("bai-coc-bach-dang-e2e");
        assertThat(newlyUnlocked.get(0).path("title").asText()).isEqualTo("Bãi cọc Bạch Đằng (Yên Giang)");

        // Replay complete idempotent -> newlyUnlockedLocations rỗng (không phát lại banner)
        String attemptId = completeBody.get("attemptId").asText();
        mvc.perform(post("/api/v1/attempts/" + attemptId + "/complete")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.alreadyCompleted").value(true))
                .andExpect(jsonPath("$.newlyUnlockedLocations.length()").value(0));

        // 6. Bản đồ Di sản: địa điểm đã UNLOCKED và mở khóa đầy đủ media UNLOCKED_ONLY
        mvc.perform(get("/api/v1/map/locations")
                        .param("periodCode", "EARLY_INDEPENDENCE")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.id == '%s')].unlocked".formatted(locBachDangId)).value(true))
                .andExpect(jsonPath("$[?(@.id == '%s')].unlockState".formatted(locBachDangId)).value("UNLOCKED"));

        mvc.perform(get("/api/v1/map/locations/" + locBachDangId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(true))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"))
                .andExpect(jsonPath("$.media.length()").value(2));
    }

    @Test
    @DisplayName("AC-2: Đủ trạng thái rỗng (NOT_READY), khóa (409 LESSON_LOCKED_BY_PATH), ngoài lộ trình (200 OK), lỗi (401/404)")
    void uxStates_emptyNotReady_lockedLesson409_invalidPeriod404_unauthenticated401() throws Exception {
        // 1. Unauthenticated -> 401
        mvc.perform(get("/api/v1/me/learning-path"))
                .andExpect(status().isUnauthorized());

        // 2. Trạng thái rỗng (FOUNDING_ERA có sự kiện chưa có bài học -> NO_PUBLISHED_LESSON / NOT_READY, lessons=[])
        //    và trạng thái khóa (LY_DYNASTY sự kiện 2 đang LOCKED khi chưa hoàn thành sự kiện 1)
        MvcResult pathRes = mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode root = om.readTree(pathRes.getResponse().getContentAsString());

        boolean checkedFoundingEmpty = false;
        boolean checkedLyLocked = false;
        for (JsonNode ch : root.path("chapters")) {
            String code = ch.path("code").asText();
            if ("FOUNDING_ERA".equals(code)) {
                JsonNode ev = ch.path("events").get(0);
                assertThat(ev.path("contentStatus").asText()).isEqualTo("NO_PUBLISHED_LESSON");
                assertThat(ev.path("status").asText()).isEqualTo("NOT_READY");
                assertThat(ev.path("lessons").size()).isZero();
                checkedFoundingEmpty = true;
            }
            if ("LY_DYNASTY".equals(code)) {
                JsonNode ev1 = ch.path("events").get(0);
                JsonNode ev2 = ch.path("events").get(1);
                assertThat(ev1.path("status").asText()).isEqualTo("AVAILABLE");
                assertThat(ev1.path("lessons").get(0).path("status").asText()).isEqualTo("AVAILABLE");
                assertThat(ev2.path("status").asText()).isEqualTo("LOCKED");
                assertThat(ev2.path("lessons").get(0).path("status").asText()).isEqualTo("LOCKED");
                checkedLyLocked = true;
            }
        }
        assertThat(checkedFoundingEmpty).isTrue();
        assertThat(checkedLyLocked).isTrue();

        // 3. Mở bài học đang LOCKED -> 403 LESSON_LOCKED_BY_PATH
        mvc.perform(post("/api/v1/lessons/" + lessonNhuNguyetId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("LESSON_LOCKED_BY_PATH"));

        // 4. Bài học PUBLISHED ngoài lộ trình -> học tự do 200 OK
        mvc.perform(post("/api/v1/lessons/" + outOfPathLessonId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());

        // 5. Touch thời kỳ không tồn tại hoặc touch nhầm node ERA -> 404
        mvc.perform(post("/api/v1/me/learning-path/periods/UNKNOWN_PERIOD/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());

        mvc.perform(post("/api/v1/me/learning-path/periods/ERA_FEUDAL/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("AC-3: Đổi thời kỳ và quay lại không mất tiến độ (bảo toàn completedEvents, currentByPeriod và bài IN_PROGRESS)")
    void switchPeriodsAndReturn_preservesProgressAndCurrentPointers() throws Exception {
        // 1. Chọn thời kỳ LY_DYNASTY và hoàn thành sự kiện 1 (Lý Thái Tổ dời đô)
        mvc.perform(post("/api/v1/me/learning-path/periods/LY_DYNASTY/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());

        completeLesson(learnerToken, lessonLyThaiToId);

        // Kiểm tra LY_DYNASTY đã đạt 1/2 sự kiện (50%) và con trỏ chuyển sang sự kiện 2 (Như Nguyệt)
        mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastPeriodCode").value("LY_DYNASTY"))
                .andExpect(jsonPath("$.current.eventNodeId").value(nodeNhuNguyetId.toString()))
                .andExpect(jsonPath("$.current.lessonId").value(lessonNhuNguyetId))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].completedEvents").value(1))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].requiredEvents").value(2))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].percent").value(50));

        // 2. Đổi sang thời kỳ EARLY_INDEPENDENCE và bắt đầu học dở bài Bạch Đằng (IN_PROGRESS)
        mvc.perform(post("/api/v1/me/learning-path/periods/EARLY_INDEPENDENCE/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.periodCode").value("EARLY_INDEPENDENCE"));

        mvc.perform(post("/api/v1/lessons/" + lessonBachDangId + "/attempts")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastPeriodCode").value("EARLY_INDEPENDENCE"))
                .andExpect(jsonPath("$.current.eventNodeId").value(nodeBachDangId.toString()))
                // Tiến độ LY_DYNASTY vẫn giữ nguyên 50% khi đang ở thời kỳ khác
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].completedEvents").value(1))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].percent").value(50))
                .andExpect(jsonPath("$.currentByPeriod.LY_DYNASTY.eventNodeId").value(nodeNhuNguyetId.toString()));

        // 3. Quay lại thời kỳ LY_DYNASTY -> tiếp tục ngay tại sự kiện 2 (Như Nguyệt), không mất tiến độ ở cả 2 thời kỳ
        mvc.perform(post("/api/v1/me/learning-path/periods/LY_DYNASTY/touch")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.periodCode").value("LY_DYNASTY"));

        MvcResult returnRes = mvc.perform(get("/api/v1/me/learning-path")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lastPeriodCode").value("LY_DYNASTY"))
                .andExpect(jsonPath("$.current.eventNodeId").value(nodeNhuNguyetId.toString()))
                .andExpect(jsonPath("$.current.lessonId").value(lessonNhuNguyetId))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].completedEvents").value(1))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].completedLessons").value(1))
                .andExpect(jsonPath("$.periodProgress[?(@.code == 'LY_DYNASTY')].percent").value(50))
                .andReturn();

        JsonNode afterReturn = om.readTree(returnRes.getResponse().getContentAsString());
        for (JsonNode ch : afterReturn.path("chapters")) {
            if ("EARLY_INDEPENDENCE".equals(ch.path("code").asText())) {
                // Bài học đang làm dở ở EARLY_INDEPENDENCE vẫn giữ trạng thái IN_PROGRESS
                assertThat(ch.path("events").get(0).path("lessons").get(0).path("status").asText())
                        .isEqualTo("IN_PROGRESS");
            }
            if ("LY_DYNASTY".equals(ch.path("code").asText())) {
                assertThat(ch.path("events").get(0).path("status").asText()).isIn("COMPLETED", "MASTERED");
                assertThat(ch.path("events").get(1).path("status").asText()).isEqualTo("AVAILABLE");
            }
        }
    }
}
