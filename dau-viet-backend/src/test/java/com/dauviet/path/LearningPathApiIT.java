package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
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
@DisplayName("PATH-01 — Learning Path 2.0 Integration Tests")
class LearningPathApiIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper om;
    @Autowired UserRepository users;
    @Autowired JwtTokenService jwt;

    @BeforeEach
    void setUp() {
        LearningPathItFixture.ensureDefaultPathSeeded(jdbc);
    }

    @Test
    @DisplayName("GET /api/v1/learning-path trả đúng cấu trúc 5 chương và thứ tự chuẩn")
    void getPublishedPathHistoryMainSuccess() throws Exception {
        MvcResult result = mvc.perform(get("/api/v1/learning-path"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathCode").value("HISTORY_MAIN"))
                .andExpect(jsonPath("$.pathVersion").value(1))
                .andExpect(jsonPath("$.title").value("Hành trình Lịch sử Việt Nam"))
                .andExpect(jsonPath("$.chapters.length()").value(5))
                .andExpect(jsonPath("$.chapters[0].code").value("FOUNDING_ERA"))
                .andExpect(jsonPath("$.chapters[0].sortOrder").value(1))
                .andExpect(jsonPath("$.chapters[0].startYear").value(-700))
                .andExpect(jsonPath("$.chapters[0].endYear").value(-179))
                .andExpect(jsonPath("$.chapters[1].code").value("NORTHERN_DOMINATION"))
                .andExpect(jsonPath("$.chapters[1].sortOrder").value(2))
                .andExpect(jsonPath("$.chapters[2].code").value("EARLY_INDEPENDENCE"))
                .andExpect(jsonPath("$.chapters[2].sortOrder").value(3))
                .andExpect(jsonPath("$.chapters[3].code").value("LY_DYNASTY"))
                .andExpect(jsonPath("$.chapters[3].sortOrder").value(4))
                .andExpect(jsonPath("$.chapters[4].code").value("ANTI_FRENCH_RESISTANCE"))
                .andExpect(jsonPath("$.chapters[4].sortOrder").value(5))
                .andReturn();

        JsonNode root = om.readTree(result.getResponse().getContentAsString());
        assertThat(root.path("chapters").size()).isEqualTo(5);
    }

    @Test
    @DisplayName("Hai Bà Trưng chỉ xuất hiện duy nhất 1 lần trong lộ trình chính (không trùng alias)")
    void haiBaTrungAppearsExactlyOnceInPath() throws Exception {
        MvcResult result = mvc.perform(get("/api/v1/learning-path"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode root = om.readTree(result.getResponse().getContentAsString());
        List<String> eventSlugs = new ArrayList<>();
        for (JsonNode chapter : root.path("chapters")) {
            for (JsonNode event : chapter.path("events")) {
                eventSlugs.add(event.path("slug").asText());
            }
        }

        long haiBaTrungCount = eventSlugs.stream()
                .filter(slug -> slug.contains("hai-ba-trung"))
                .count();

        assertThat(haiBaTrungCount)
                .as("Sự kiện Hai Bà Trưng chỉ được xuất hiện đúng 1 lần trong lộ trình chính")
                .isEqualTo(1);
    }

    @Test
    @DisplayName("Định dạng mốc năm hiển thị đúng chuẩn TCN và SCN (không có năm 0)")
    void yearFormattingAndLabels() throws Exception {
        MvcResult result = mvc.perform(get("/api/v1/learning-path"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode root = om.readTree(result.getResponse().getContentAsString());
        JsonNode chapters = root.path("chapters");

        // Chương 1: Hùng Vương (-700) -> Khoảng thế kỷ VII TCN
        JsonNode ch1Events = chapters.get(0).path("events");
        assertThat(ch1Events.size()).isGreaterThanOrEqualTo(1);
        assertThat(ch1Events.get(0).path("startYear").asInt()).isEqualTo(-700);
        assertThat(ch1Events.get(0).path("yearLabel").asText()).isEqualTo("Khoảng thế kỷ VII TCN");

        // Chương 2: Hai Bà Trưng (40) -> Năm 40
        JsonNode ch2Events = chapters.get(1).path("events");
        assertThat(ch2Events.size()).isEqualTo(1);
        assertThat(ch2Events.get(0).path("startYear").asInt()).isEqualTo(40);
        assertThat(ch2Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 40");

        // Chương 3: Bạch Đằng (938) -> Năm 938
        JsonNode ch3Events = chapters.get(2).path("events");
        assertThat(ch3Events.size()).isEqualTo(1);
        assertThat(ch3Events.get(0).path("startYear").asInt()).isEqualTo(938);
        assertThat(ch3Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 938");

        // Chương 4: Nhà Lý (1010, 1077)
        JsonNode ch4Events = chapters.get(3).path("events");
        assertThat(ch4Events.size()).isEqualTo(2);
        assertThat(ch4Events.get(0).path("slug").asText()).isEqualTo("ly-thai-to-1010");
        assertThat(ch4Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 1010");
        assertThat(ch4Events.get(1).path("slug").asText()).isEqualTo("chien-thang-nhu-nguyet-1077");
        assertThat(ch4Events.get(1).path("yearLabel").asText()).isEqualTo("Năm 1077");

        // Chương 5: Điện Biên Phủ (1954)
        JsonNode ch5Events = chapters.get(4).path("events");
        assertThat(ch5Events.size()).isEqualTo(1);
        assertThat(ch5Events.get(0).path("slug").asText()).isEqualTo("chien-dich-dien-bien-phu-1954");
        assertThat(ch5Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 1954");
    }

    @Test
    @DisplayName("ContentStatus phản ánh trung thực trạng thái biên tập nội dung")
    void contentStatusReflectsAuthoringTruth() throws Exception {
        MvcResult result = mvc.perform(get("/api/v1/learning-path"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode root = om.readTree(result.getResponse().getContentAsString());
        JsonNode chapters = root.path("chapters");

        // Chương 1 (Hùng Vương): 0 bài học -> NO_PUBLISHED_LESSON
        JsonNode ch1Events = chapters.get(0).path("events");
        assertThat(ch1Events.size()).isGreaterThanOrEqualTo(1);
        assertThat(ch1Events.get(0).path("contentStatus").asText()).isEqualTo("NO_PUBLISHED_LESSON");
        assertThat(ch1Events.get(0).path("lessons").size()).isEqualTo(0);

        // Chương 3 (Bạch Đằng 938): có bài + policy -> PLAYABLE
        JsonNode ch3Events = chapters.get(2).path("events");
        assertThat(ch3Events.size()).isEqualTo(1);
        assertThat(ch3Events.get(0).path("contentStatus").asText()).isEqualTo("PLAYABLE");
        assertThat(ch3Events.get(0).path("lessons").size()).isEqualTo(1);
        assertThat(ch3Events.get(0).path("lessons").get(0).path("sortOrder").asInt()).isEqualTo(1);
    }

    @Test
    @DisplayName("Lộ trình không tồn tại trả về lỗi 404 NOT_FOUND")
    void notFoundWhenPathCodeDoesNotExist() throws Exception {
        mvc.perform(get("/api/v1/learning-path?code=UNKNOWN_PATH"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("No published learning path found for code: UNKNOWN_PATH"));
    }

    @Test
    @DisplayName("Security: Endpoint admin audit kiểm soát quyền chặt chẽ (401, 403, 200)")
    void adminAuditSecurityGates() throws Exception {
        // 1. Không có token -> 401 Unauthorized
        mvc.perform(get("/api/v1/admin/learning-path/audit"))
                .andExpect(status().isUnauthorized());

        // 2. Token role LEARNER -> 403 Forbidden
        String learnerToken = AttemptItFixture.token(users, jwt, "learner.path@test.vn", UserRole.LEARNER);
        mvc.perform(get("/api/v1/admin/learning-path/audit")
                .header("Authorization", learnerToken))
                .andExpect(status().isForbidden());

        // 3. Token role CONTENT_ADMIN -> 200 OK
        String adminToken = AttemptItFixture.token(users, jwt, "admin.path@test.vn", UserRole.CONTENT_ADMIN);
        mvc.perform(get("/api/v1/admin/learning-path/audit")
                .header("Authorization", adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathCode").value("HISTORY_MAIN"))
                .andExpect(jsonPath("$.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.totalChapters").value(5))
                .andExpect(jsonPath("$.totalEvents").value(6))
                .andExpect(jsonPath("$.contentStatusCounts").isMap());
    }
}
