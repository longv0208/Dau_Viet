package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
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
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import com.dauviet.AbstractPostgresIT;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

@SpringBootTest
@AutoConfigureMockMvc
@DisplayName("PATH-01 — Learning Path 2.0 Integration Tests")
class LearningPathApiIT extends AbstractPostgresIT {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper om;

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
        if (ch1Events.size() > 0) {
            assertThat(ch1Events.get(0).path("startYear").asInt()).isEqualTo(-700);
            assertThat(ch1Events.get(0).path("yearLabel").asText()).isEqualTo("Khoảng thế kỷ VII TCN");
        }

        // Chương 2: Hai Bà Trưng (40) -> Năm 40
        JsonNode ch2Events = chapters.get(1).path("events");
        if (ch2Events.size() > 0) {
            assertThat(ch2Events.get(0).path("startYear").asInt()).isEqualTo(40);
            assertThat(ch2Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 40");
        }

        // Chương 3: Bạch Đằng (938) -> Năm 938
        JsonNode ch3Events = chapters.get(2).path("events");
        if (ch3Events.size() > 0) {
            assertThat(ch3Events.get(0).path("startYear").asInt()).isEqualTo(938);
            assertThat(ch3Events.get(0).path("yearLabel").asText()).isEqualTo("Năm 938");
        }
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
        if (ch1Events.size() > 0) {
            assertThat(ch1Events.get(0).path("contentStatus").asText()).isEqualTo("NO_PUBLISHED_LESSON");
            assertThat(ch1Events.get(0).path("lessons").size()).isEqualTo(0);
        }

        // Chương 3 (Bạch Đằng 938): có bài + policy -> PLAYABLE
        JsonNode ch3Events = chapters.get(2).path("events");
        if (ch3Events.size() > 0) {
            assertThat(ch3Events.get(0).path("contentStatus").asText()).isEqualTo("PLAYABLE");
            assertThat(ch3Events.get(0).path("lessons").size()).isGreaterThanOrEqualTo(1);
        }
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
    @DisplayName("Endpoint audit trả về báo cáo kiểm toán đầy đủ")
    void auditEndpointReturnsCompleteReport() throws Exception {
        mvc.perform(get("/api/v1/learning-path/audit"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pathCode").value("HISTORY_MAIN"))
                .andExpect(jsonPath("$.status").value("PUBLISHED"))
                .andExpect(jsonPath("$.totalChapters").value(5))
                .andExpect(jsonPath("$.totalEvents").isNumber())
                .andExpect(jsonPath("$.contentStatusCounts").isMap());
    }

    @Test
    @DisplayName("Trigger bảo vệ: Không thể sửa tiêu đề phiên bản PUBLISHED trực tiếp")
    void publishedPathIsProtectedFromMutation() {
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_versions SET title = 'Tên giả mạo' WHERE path_code = 'HISTORY_MAIN' AND status = 'PUBLISHED'");
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("immutable");
    }
}
