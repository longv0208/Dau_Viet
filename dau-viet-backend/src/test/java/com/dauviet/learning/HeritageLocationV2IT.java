package com.dauviet.learning;

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
import com.dauviet.security.jwt.JwtTokenService;
import com.dauviet.user.domain.UserRole;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@DisplayName("MAP-02 — Standalone Heritage Locations V2, ANY/ALL Unlock & Media Filtering Integration Tests")
class HeritageLocationV2IT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;
    @Autowired ObjectMapper om;
    @Autowired JdbcTemplate jdbc;

    private String adminToken;
    private String learnerToken;
    private String event1Id;
    private String event2Id;
    private String tplId;
    private String ev1Id;
    private String ev2Id;

    private static final String MC_CONFIG =
            "{\"question\":\"q\",\"options\":[{\"id\":\"o1\"},{\"id\":\"o2\"}],"
            + "\"correctOptionIds\":[\"o1\"]}";

    @BeforeEach
    void setUp() {
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        users.deleteAll();

        adminToken = AttemptItFixture.token(users, jwt, "admin@heritagev2.vn", UserRole.CONTENT_ADMIN);
        learnerToken = AttemptItFixture.token(users, jwt, "learner@heritagev2.vn", UserRole.LEARNER);
        event1Id = AttemptItFixture.newEvent(jdbc, "evt-bach-dang-938");
        event2Id = AttemptItFixture.newEvent(jdbc, "evt-bach-dang-1288");
        tplId = AttemptItFixture.newTemplate(jdbc, "tpl-heritage");
        ev1Id = AttemptItFixture.newEvidence(jdbc, event1Id);
        ev2Id = AttemptItFixture.newEvidence(jdbc, event2Id);
    }

    private JsonNode completeLessonAndReturnResponse(String token, String lessonId) throws Exception {
        MvcResult started = mvc.perform(post("/api/v1/lessons/" + lessonId + "/attempts")
                        .header("Authorization", token))
                .andExpect(status().isOk()).andReturn();
        JsonNode body = om.readTree(started.getResponse().getContentAsString());
        String attemptId = body.get("attemptId").asText();
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
                .andExpect(status().isOk()).andReturn();
        return om.readTree(completeRes.getResponse().getContentAsString());
    }

    @Test
    @DisplayName("Địa điểm độc lập gắn nhiều sự kiện, mở khóa ANY vs ALL, trả newlyUnlockedLocations và lọc media UNLOCKED_ONLY")
    void standaloneHeritageLocationLifecycleAndAnyAllUnlock() throws Exception {
        String lesson1Id = AttemptItFixture.publishLesson(
                mvc, om, adminToken, event1Id, tplId, AttemptItFixture.draftTwoStage(ev1Id, MC_CONFIG));
        String lesson2Id = AttemptItFixture.publishLesson(
                mvc, om, adminToken, event2Id, tplId, AttemptItFixture.draftTwoStage(ev2Id, MC_CONFIG));

        // 1. Tạo địa điểm 1 (ANY: chỉ cần 1 trong 2 bài học)
        MvcResult createAnyRes = mvc.perform(post("/api/v1/admin/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "slug": "cua-song-bach-dang-any",
                                  "title": "Cửa sông Bạch Đằng (ANY)",
                                  "shortSummary": "Chiến trường sông Bạch Đằng",
                                  "description": "Mô tả chi tiết cửa sông Bạch Đằng",
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
        JsonNode anyNode = om.readTree(createAnyRes.getResponse().getContentAsString());
        UUID locAnyId = UUID.fromString(anyNode.get("id").asText());

        // Gắn 2 sự kiện + 2 bài học (ANY) + Publish
        mvc.perform(put("/api/v1/admin/map-locations/" + locAnyId + "/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                [
                                  {"eventId": "%s", "role": "PRIMARY", "sortOrder": 0},
                                  {"eventId": "%s", "role": "RELATED", "sortOrder": 1}
                                ]
                                """.formatted(event1Id, event2Id)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.events.length()").value(2));

        mvc.perform(put("/api/v1/admin/map-locations/" + locAnyId + "/unlock-lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "unlockRuleMode": "ANY",
                                  "lessonIds": ["%s", "%s"]
                                }
                                """.formatted(lesson1Id, lesson2Id)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlockRuleMode").value("ANY"))
                .andExpect(jsonPath("$.unlockLessons.length()").value(2));

        long anyRowVer = om.readTree(mvc.perform(get("/api/v1/admin/map-locations/" + locAnyId)
                        .header("Authorization", adminToken))
                .andReturn().getResponse().getContentAsString()).get("rowVersion").asLong();

        mvc.perform(post("/api/v1/admin/map-locations/" + locAnyId + "/status?status=PUBLISHED&expectedRowVersion=" + anyRowVer)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PUBLISHED"));

        // 2. Tạo địa điểm 2 (ALL: bắt buộc hoàn thành cả 2 bài học) + Media PUBLIC_PREVIEW & UNLOCKED_ONLY
        MvcResult createAllRes = mvc.perform(post("/api/v1/admin/map-locations")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "slug": "bai-coc-yen-giang-all",
                                  "title": "Bãi cọc Yên Giang (ALL)",
                                  "shortSummary": "Di tích bãi cọc ngầm",
                                  "description": "Mô tả chi tiết bãi cọc",
                                  "kind": "HERITAGE_SITE",
                                  "latitude": 20.9450,
                                  "longitude": 106.7700,
                                  "coordinatePrecision": "EXACT",
                                  "visibility": "ALWAYS_VISIBLE",
                                  "unlockRuleMode": "ALL",
                                  "displayOrder": 2
                                }
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        UUID locAllId = UUID.fromString(
                om.readTree(createAllRes.getResponse().getContentAsString()).get("id").asText());

        mvc.perform(put("/api/v1/admin/map-locations/" + locAllId + "/events")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                [
                                  {"eventId": "%s", "role": "PRIMARY", "sortOrder": 0},
                                  {"eventId": "%s", "role": "RELATED", "sortOrder": 1}
                                ]
                                """.formatted(event1Id, event2Id)))
                .andExpect(status().isOk());

        mvc.perform(put("/api/v1/admin/map-locations/" + locAllId + "/unlock-lessons")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "unlockRuleMode": "ALL",
                                  "lessonIds": ["%s", "%s"]
                                }
                                """.formatted(lesson1Id, lesson2Id)))
                .andExpect(status().isOk());

        mvc.perform(put("/api/v1/admin/map-locations/" + locAllId + "/media")
                        .header("Authorization", adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                [
                                  {
                                    "mediaType": "IMAGE_2D",
                                    "title": "Ảnh toàn cảnh công khai",
                                    "caption": "Ai cũng xem được",
                                    "externalUrl": "https://example.com/public.jpg",
                                    "visibility": "PUBLIC_PREVIEW",
                                    "sortOrder": 0
                                  },
                                  {
                                    "mediaType": "PANORAMA_360",
                                    "title": "Toàn cảnh 360 cọc gỗ lim",
                                    "caption": "Chỉ mở khi đã unlock địa điểm",
                                    "externalUrl": "https://example.com/secret-360.jpg",
                                    "visibility": "UNLOCKED_ONLY",
                                    "sortOrder": 1
                                  }
                                ]
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.media.length()").value(2));

        long allRowVer = om.readTree(mvc.perform(get("/api/v1/admin/map-locations/" + locAllId)
                        .header("Authorization", adminToken))
                .andReturn().getResponse().getContentAsString()).get("rowVersion").asLong();

        mvc.perform(post("/api/v1/admin/map-locations/" + locAllId + "/status?status=PUBLISHED&expectedRowVersion=" + allRowVer)
                        .header("Authorization", adminToken))
                .andExpect(status().isOk());

        // 3. Trước khi học bài nào: cả 2 địa điểm đều LOCKED, chi tiết locAll chỉ trả 1 media PUBLIC_PREVIEW
        mvc.perform(get("/api/v1/map/locations/" + locAllId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(false))
                .andExpect(jsonPath("$.unlockState").value("LOCKED"))
                .andExpect(jsonPath("$.unlockMode").value("ALL"))
                .andExpect(jsonPath("$.media.length()").value(1))
                .andExpect(jsonPath("$.media[0].visibility").value("PUBLIC_PREVIEW"));

        // 4. Learner hoàn thành lesson 1 -> locAny mở khóa ngay trong CompleteAttemptResponse, locAll vẫn LOCKED!
        JsonNode complete1 = completeLessonAndReturnResponse(learnerToken, lesson1Id);
        JsonNode newly1 = complete1.path("newlyUnlockedLocations");
        assertThat(newly1.size()).isEqualTo(1);
        assertThat(newly1.get(0).path("locationId").asText()).isEqualTo(locAnyId.toString());
        assertThat(newly1.get(0).path("slug").asText()).isEqualTo("cua-song-bach-dang-any");

        mvc.perform(get("/api/v1/map/locations/" + locAllId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(false))
                .andExpect(jsonPath("$.media.length()").value(1));

        // 5. Learner hoàn thành lesson 2 -> locAll (ALL) mở khóa và trả về cả 2 media (PUBLIC_PREVIEW + UNLOCKED_ONLY)!
        JsonNode complete2 = completeLessonAndReturnResponse(learnerToken, lesson2Id);
        JsonNode newly2 = complete2.path("newlyUnlockedLocations");
        assertThat(newly2.size()).isEqualTo(1);
        assertThat(newly2.get(0).path("locationId").asText()).isEqualTo(locAllId.toString());
        assertThat(newly2.get(0).path("slug").asText()).isEqualTo("bai-coc-yen-giang-all");

        String attempt2Id = complete2.path("attemptId").asText();
        mvc.perform(get("/api/v1/attempts/" + attempt2Id + "/result")
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.newlyUnlockedLocations.length()").value(1))
                .andExpect(jsonPath("$.newlyUnlockedLocations[0].locationId").value(locAllId.toString()))
                .andExpect(jsonPath("$.newlyUnlockedLocations[0].slug").value("bai-coc-yen-giang-all"));

        mvc.perform(get("/api/v1/map/locations/" + locAllId)
                        .header("Authorization", learnerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlocked").value(true))
                .andExpect(jsonPath("$.unlockState").value("UNLOCKED"))
                .andExpect(jsonPath("$.media.length()").value(2));
    }
}
