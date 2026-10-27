package com.dauviet.path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;

import com.dauviet.AbstractPostgresIT;

@SpringBootTest
@DisplayName("PATH-01 — Learning Path Immutability & Protection Triggers Integration Tests")
class LearningPathImmutabilityIT extends AbstractPostgresIT {

    @Autowired JdbcTemplate jdbc;

    @BeforeEach
    void setUp() {
        LearningPathItFixture.ensureDefaultPathSeeded(jdbc);
    }

    @Test
    @DisplayName("DRAFT version: Cho phép thêm, sửa, xóa version và toàn bộ nodes con")
    void draftVersionAllowsAllMutations() {
        UUID draftVersionId = UUID.randomUUID();
        UUID draftChapterId = UUID.randomUUID();
        UUID draftEventNodeId = UUID.randomUUID();
        UUID draftLessonNodeId = UUID.randomUUID();
        UUID eventId = jdbc.queryForObject(
                "SELECT id FROM historical_events WHERE slug = 'bach-dang-938' LIMIT 1", UUID.class);
        UUID lessonId = jdbc.queryForObject(
                "SELECT id FROM lessons WHERE event_id = ?::uuid LIMIT 1", UUID.class, eventId.toString());

        // 1. Tạo DRAFT version
        assertThatCode(() -> {
            jdbc.update("INSERT INTO learning_path_versions (id, path_code, version_no, title, description, status) "
                    + "VALUES (?::uuid, 'DRAFT_PATH', 99, 'Draft Title', 'Draft Desc', 'DRAFT')",
                    draftVersionId.toString());
        }).doesNotThrowAnyException();

        // 2. Thêm và sửa Chapter trên DRAFT
        assertThatCode(() -> {
            jdbc.update("INSERT INTO learning_path_chapters (id, path_version_id, code, title, period_label, start_year, end_year, sort_order, theme_key) "
                    + "VALUES (?::uuid, ?::uuid, 'CH_DRAFT', 'Chapter Draft', '100 - 200', 100, 200, 1, 'THEME_DRAFT')",
                    draftChapterId.toString(), draftVersionId.toString());
            jdbc.update("UPDATE learning_path_chapters SET title = 'Updated Draft Chapter' WHERE id = ?::uuid",
                    draftChapterId.toString());
        }).doesNotThrowAnyException();

        // 3. Thêm và sửa Event Node trên DRAFT
        assertThatCode(() -> {
            jdbc.update("INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order) "
                    + "VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, 1)",
                    draftEventNodeId.toString(), draftChapterId.toString(), draftVersionId.toString(), eventId.toString());
            jdbc.update("UPDATE learning_path_event_nodes SET sort_order = 2 WHERE id = ?::uuid",
                    draftEventNodeId.toString());
        }).doesNotThrowAnyException();

        // 4. Thêm và xóa Lesson Node trên DRAFT
        assertThatCode(() -> {
            jdbc.update("INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order) "
                    + "VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, 1)",
                    draftLessonNodeId.toString(), draftEventNodeId.toString(), eventId.toString(), lessonId.toString());
            jdbc.update("DELETE FROM learning_path_lesson_nodes WHERE id = ?::uuid", draftLessonNodeId.toString());
            jdbc.update("DELETE FROM learning_path_event_nodes WHERE id = ?::uuid", draftEventNodeId.toString());
            jdbc.update("DELETE FROM learning_path_chapters WHERE id = ?::uuid", draftChapterId.toString());
            jdbc.update("DELETE FROM learning_path_versions WHERE id = ?::uuid", draftVersionId.toString());
        }).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("PUBLISHED version: Bị chặn hoàn toàn các thao tác sửa/thêm/xóa trên version và nodes con")
    void publishedVersionAndChildNodesAreImmutable() {
        UUID publishedVersionId = jdbc.queryForObject(
                "SELECT id FROM learning_path_versions WHERE path_code = 'HISTORY_MAIN' AND version_no = 1",
                UUID.class);
        UUID chapterId = jdbc.queryForObject(
                "SELECT id FROM learning_path_chapters WHERE path_version_id = ?::uuid LIMIT 1",
                UUID.class, publishedVersionId.toString());
        UUID eventNodeId = jdbc.queryForObject(
                "SELECT id FROM learning_path_event_nodes WHERE path_version_id = ?::uuid LIMIT 1",
                UUID.class, publishedVersionId.toString());
        UUID eventId = jdbc.queryForObject(
                "SELECT event_id FROM learning_path_event_nodes WHERE id = ?::uuid",
                UUID.class, eventNodeId.toString());

        // 1. Không thể sửa title version
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_versions SET title = 'Fake Title' WHERE id = ?::uuid", publishedVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("immutable");

        // 2. Không thể chuyển lùi version từ PUBLISHED về DRAFT
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_versions SET status = 'DRAFT' WHERE id = ?::uuid", publishedVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("immutable");

        // 3. Không thể xóa version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("DELETE FROM learning_path_versions WHERE id = ?::uuid", publishedVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot delete learning_path_versions in PUBLISHED status");

        // 4. Không thể thêm chapter mới vào version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("INSERT INTO learning_path_chapters (id, path_version_id, code, title, period_label, start_year, end_year, sort_order, theme_key) "
                    + "VALUES (?::uuid, ?::uuid, 'NEW_CH', 'New Title', 'Period', 100, 200, 99, 'THEME')",
                    UUID.randomUUID().toString(), publishedVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify chapters");

        // 5. Không thể sửa chapter thuộc version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_chapters SET title = 'Hacked Chapter' WHERE id = ?::uuid", chapterId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify chapters");

        // 6. Không thể xóa chapter thuộc version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("DELETE FROM learning_path_chapters WHERE id = ?::uuid", chapterId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify chapters");

        // 7. Không thể thêm event node vào version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("INSERT INTO learning_path_event_nodes (id, chapter_id, path_version_id, event_id, sort_order) "
                    + "VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, 99)",
                    UUID.randomUUID().toString(), chapterId.toString(), publishedVersionId.toString(), eventId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify event nodes");

        // 8. Không thể sửa event node thuộc version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_event_nodes SET sort_order = 99 WHERE id = ?::uuid", eventNodeId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify event nodes");

        // 9. Không thể xóa event node thuộc version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("DELETE FROM learning_path_event_nodes WHERE id = ?::uuid", eventNodeId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify event nodes");

        // 10. Không thể thêm lesson node vào event node của version PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("INSERT INTO learning_path_lesson_nodes (id, event_node_id, event_id, lesson_id, sort_order) "
                    + "VALUES (?::uuid, ?::uuid, ?::uuid, ?::uuid, 99)",
                    UUID.randomUUID().toString(), eventNodeId.toString(), eventId.toString(), UUID.randomUUID().toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot modify lesson nodes");
    }

    @Test
    @DisplayName("Chuyển trạng thái PUBLISHED -> ARCHIVED thành công; ARCHIVED cũng bất biến")
    void transitionToArchivedSucceedsAndArchivedIsProtected() {
        UUID testVersionId = UUID.randomUUID();

        // Tạo một version PUBLISHED riêng để test lưu trữ (ARCHIVED) mà không ảnh hưởng HISTORY_MAIN v1
        jdbc.update("INSERT INTO learning_path_versions (id, path_code, version_no, title, description, status) "
                + "VALUES (?::uuid, 'ARCHIVE_TEST_PATH', 1, 'Archive Test', 'Desc', 'PUBLISHED')",
                testVersionId.toString());

        // 1. Chuyển PUBLISHED -> ARCHIVED (không sửa title/desc) -> Thành công
        assertThatCode(() -> {
            jdbc.update("UPDATE learning_path_versions SET status = 'ARCHIVED' WHERE id = ?::uuid", testVersionId.toString());
        }).doesNotThrowAnyException();

        String status = jdbc.queryForObject("SELECT status FROM learning_path_versions WHERE id = ?::uuid", String.class, testVersionId.toString());
        assertThat(status).isEqualTo("ARCHIVED");

        // 2. Không thể xóa version ARCHIVED
        assertThatThrownBy(() -> {
            jdbc.update("DELETE FROM learning_path_versions WHERE id = ?::uuid", testVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("Cannot delete learning_path_versions in ARCHIVED status");

        // 3. Không thể sửa title version ARCHIVED
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_versions SET title = 'Changed in Archive' WHERE id = ?::uuid", testVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("immutable");

        // 4. Không thể chuyển trạng thái ARCHIVED về DRAFT hoặc PUBLISHED
        assertThatThrownBy(() -> {
            jdbc.update("UPDATE learning_path_versions SET status = 'DRAFT' WHERE id = ?::uuid", testVersionId.toString());
        }).isInstanceOf(DataAccessException.class)
          .hasMessageContaining("immutable");
    }
}
