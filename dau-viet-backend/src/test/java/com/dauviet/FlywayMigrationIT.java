package com.dauviet;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Verifies Flyway migrations apply cleanly on a fresh Postgres and the
 * flyway_schema_history table records them. Requires Docker.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class FlywayMigrationIT extends AbstractPostgresIT {

    @Autowired
    private JdbcTemplate jdbc;

    @BeforeEach
    void cleanTables() {
        // This suite shares the Postgres container with the other ITs; rows
        // left behind (e.g. slug 'e1' events, 'tpl' templates) would collide
        // with the fixed fixtures below. Clear authoring dependents first so
        // the events/templates delete is FK-safe.
        clearAuthoringTables(jdbc);
        jdbc.update("delete from lesson_templates");
        jdbc.update("delete from historical_events");
        jdbc.update("delete from auth_refresh_tokens");
        jdbc.update("delete from users");
    }

    @Test
    void flywayV1Applied() {
        Integer count = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '1' AND success",
                Integer.class);
        assertThat(count).isEqualTo(1);
    }

    @Test
    void flywayV2ToV4Applied() {
        Integer count = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history "
              + "WHERE version IN ('2','3','4') AND success",
                Integer.class);
        assertThat(count).isEqualTo(3);
    }

    @Test
    void flywayV5Applied_rowVersionPresent() {
        Integer applied = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '5' AND success",
                Integer.class);
        assertThat(applied).isEqualTo(1);
        Integer col = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.columns "
              + "WHERE table_name='historical_events' AND column_name='row_version'",
                Integer.class);
        assertThat(col).isEqualTo(1);
    }

    @Test
    void authoringAndRuntimeTablesExist() {
        Integer count = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.tables "
              + "WHERE table_name IN ('users','auth_refresh_tokens','assets',"
              + "'evidences','lesson_templates','lessons','lesson_versions',"
              + "'learner_attempts','activity_attempts','idempotency_records',"
              + "'lesson_results','user_evidence','reward_transactions',"
              + "'event_completion_policies','user_event_progress',"
              + "'historical_dossiers','event_dossiers','user_dossier_unlocks')",
                Integer.class);
        assertThat(count).isEqualTo(18);
    }

    @Test
    void lessonVersionsAreImmutable() {
        // Seed a full chain: user -> event -> template -> lesson -> version.
        // The BEFORE UPDATE trigger fires per-row, so a real row must exist.
        jdbc.execute(
                "INSERT INTO users (id, email, password_hash) "
              + "VALUES ('11111111-1111-1111-1111-111111111111', 't@t.vn', 'x')");
        jdbc.execute(
                "INSERT INTO historical_events (id, slug, title, summary, status) "
              + "VALUES ('22222222-2222-2222-2222-222222222222', "
              + "'flyway-it-event', 't', 's', 'PUBLISHED')");
        jdbc.execute(
                "INSERT INTO lesson_templates (id, code, name, schema_version, preset_json) "
              + "VALUES ('33333333-3333-3333-3333-333333333333', 'tpl', 't', 1, '{}'::jsonb)");
        jdbc.execute(
                "INSERT INTO lessons (id, event_id, template_id, title, central_question) "
              + "VALUES ('44444444-4444-4444-4444-444444444444', "
              + "'22222222-2222-2222-2222-222222222222', "
              + "'33333333-3333-3333-3333-333333333333', 'l', 'q?')");
        jdbc.execute(
                "INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, "
              + "snapshot_json, published_by) "
              + "VALUES ('55555555-5555-5555-5555-555555555555', "
              + "'44444444-4444-4444-4444-444444444444', 1, 1, '{}'::jsonb, "
              + "'11111111-1111-1111-1111-111111111111')");
        // The trigger RAISE EXCEPTION surfaces as UncategorizedSQLException
        // (a DataAccessException), not a constraint DataIntegrityViolation.
        org.junit.jupiter.api.Assertions.assertThrows(
                org.springframework.dao.DataAccessException.class,
                () -> jdbc.execute(
                        "UPDATE lesson_versions SET snapshot_json = '{\"a\":1}'::jsonb "
                      + "WHERE id = '55555555-5555-5555-5555-555555555555'"));
    }

    @Test
    void historicalEventsTableHasExpectedShape() {
        Integer cols = jdbc.queryForObject(
                "SELECT count(*) FROM information_schema.columns "
              + "WHERE table_name = 'historical_events' "
              + "AND column_name IN ('id','slug','title','era','period','start_year',"
              + "'summary','description','location','cover_asset_key','tags','status',"
              + "'created_at','updated_at')",
                Integer.class);
        assertThat(cols).isEqualTo(14);
    }

    /**
     * TASK-0022 §1 — đường nâng cấp legacy trước V10. Mô phỏng DB cũ:
     * drop ux_user_evidence_user_evidence, seed duplicate
     * (user_id, evidence_id) như V4 cho phép, rồi chạy đúng script
     * beforeEachMigrate.sql (Flyway callback chạy trước mọi migration —
     * trong đó có V10). Kỳ vọng:
     *   - duplicate rows được archive vào bảng bền vững, KHÔNG mất dữ liệu;
     *   - canonical = collected_at sớm nhất (deterministic);
     *   - user_evidence chỉ còn 1 row/(user, evidence);
     *   - unique index tạo lại được (V10 sẽ pass);
     *   - chạy lại callback → no-op, không nhân đôi archive.
     */
    @Test
    void legacyDuplicates_preV10Callback_archivesThenDedups() throws Exception {
        // --- seed full FK chain (user → event/template → lesson/version
        //     → attempt, evidence) ---
        jdbc.execute("INSERT INTO users (id, email, password_hash) "
                + "VALUES ('11111111-1111-1111-1111-111111111111','t@t.vn','x')");
        jdbc.execute("INSERT INTO historical_events (id, slug, title, summary, status) "
                + "VALUES ('22222222-2222-2222-2222-222222222222','cb-ev','t','s','PUBLISHED')");
        jdbc.execute("INSERT INTO lesson_templates (id, code, name, schema_version, preset_json) "
                + "VALUES ('33333333-3333-3333-3333-333333333333','cb-tpl','t',1,'{}'::jsonb)");
        jdbc.execute("INSERT INTO lessons (id, event_id, template_id, title, central_question) "
                + "VALUES ('44444444-4444-4444-4444-444444444444',"
                + "'22222222-2222-2222-2222-222222222222',"
                + "'33333333-3333-3333-3333-333333333333','l','q?')");
        // Hai lesson_versions (republish) — dupes legacy thực tế đến từ
        // các version/attempt khác nhau; ux_attempt_active_user_version
        // chỉ cho 1 IN_PROGRESS/(user, version).
        jdbc.execute("INSERT INTO lesson_versions (id, lesson_id, version_no, schema_version, "
                + "snapshot_json, published_by) VALUES "
                + "('55555555-5555-5555-5555-555555555555',"
                + "'44444444-4444-4444-4444-444444444444',1,1,'{}'::jsonb,"
                + "'11111111-1111-1111-1111-111111111111'),"
                + "('55555555-5555-5555-5555-555555555556',"
                + "'44444444-4444-4444-4444-444444444444',2,1,'{}'::jsonb,"
                + "'11111111-1111-1111-1111-111111111111')");
        jdbc.execute("INSERT INTO learner_attempts (id, user_id, lesson_version_id) VALUES "
                + "('66666666-6666-6666-6666-666666666666',"
                + "'11111111-1111-1111-1111-111111111111',"
                + "'55555555-5555-5555-5555-555555555555'),"
                + "('77777777-7777-7777-7777-777777777777',"
                + "'11111111-1111-1111-1111-111111111111',"
                + "'55555555-5555-5555-5555-555555555556')");
        jdbc.execute("INSERT INTO evidences (id, event_id, title, evidence_type, "
                + "source_title, source_author, description, status) VALUES "
                + "('88888888-8888-8888-8888-888888888888',"
                + "'22222222-2222-2222-2222-222222222222','E1','ARTIFACT',"
                + "'s','a','d','APPROVED'),"
                + "('99999999-9999-9999-9999-999999999999',"
                + "'22222222-2222-2222-2222-222222222222','E2','DOCUMENT',"
                + "'s','a','d','APPROVED')");

        // --- mô phỏng legacy: bỏ unique index, seed 2 rows trùng
        //     (user, ev1) qua 2 attempts + 1 row ev2 ---
        jdbc.execute("DROP INDEX ux_user_evidence_user_evidence");
        try {
            jdbc.execute("INSERT INTO user_evidence "
                    + "(id, user_id, learner_attempt_id, evidence_id, collected_at) VALUES "
                    + "('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',"
                    + "'11111111-1111-1111-1111-111111111111',"
                    + "'66666666-6666-6666-6666-666666666666',"
                    + "'88888888-8888-8888-8888-888888888888','2026-01-01T00:00:00Z'),"
                    + "('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',"
                    + "'11111111-1111-1111-1111-111111111111',"
                    + "'77777777-7777-7777-7777-777777777777',"
                    + "'88888888-8888-8888-8888-888888888888','2026-02-01T00:00:00Z'),"
                    + "('cccccccc-cccc-cccc-cccc-cccccccccccc',"
                    + "'11111111-1111-1111-1111-111111111111',"
                    + "'77777777-7777-7777-7777-777777777777',"
                    + "'99999999-9999-9999-9999-999999999999','2026-01-15T00:00:00Z')");

            // Chạy đúng script callback như Flyway sẽ chạy trước V10.
            // ScriptUtils không hiểu dollar-quoting của DO $$ → đọc file
            // thô và execute nguyên chuỗi qua JDBC.
            String script = new String(
                    new org.springframework.core.io.ClassPathResource(
                            "db/migration/beforeEachMigrate.sql")
                            .getInputStream().readAllBytes(),
                    java.nio.charset.StandardCharsets.UTF_8);
            jdbc.execute(script);

            // Canonical = row sớm nhất (aaaa…, 2026-01-01); bbbb… vào archive.
            List<String> active = jdbc.queryForList(
                    "SELECT id::text FROM user_evidence ORDER BY id",
                    String.class);
            assertThat(active).containsExactlyInAnyOrder(
                    "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                    "cccccccc-cccc-cccc-cccc-cccccccccccc");

            List<java.util.Map<String, Object>> archived = jdbc.queryForList(
                    "SELECT id::text AS id, canonical_id::text AS canon "
                  + "FROM user_evidence_legacy_archive "
                  + "WHERE user_id = '11111111-1111-1111-1111-111111111111'");
            assertThat(archived).hasSize(1);
            assertThat(archived.get(0).get("id"))
                    .isEqualTo("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
            assertThat(archived.get(0).get("canon"))
                    .isEqualTo("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

            // Index tạo lại được → V10 pass trên DB đã dọn.
            jdbc.execute("CREATE UNIQUE INDEX ux_user_evidence_user_evidence "
                    + "ON user_evidence(user_id, evidence_id)");

            // Chạy lại callback → guard theo index → no-op, archive không đổi.
            jdbc.execute(script);
            Integer archiveCount = jdbc.queryForObject(
                    "SELECT count(*) FROM user_evidence_legacy_archive "
                  + "WHERE user_id = '11111111-1111-1111-1111-111111111111'",
                    Integer.class);
            assertThat(archiveCount).isEqualTo(1);
        } finally {
            // Trả lại index cho các test khác dùng chung container
            // (an toàn nếu đã recreate trong try — IF NOT EXISTS).
            jdbc.execute("CREATE UNIQUE INDEX IF NOT EXISTS "
                    + "ux_user_evidence_user_evidence "
                    + "ON user_evidence(user_id, evidence_id)");
        }
    }

    @Test
    void checkConstraintRejectsInvalidStatus() {
        org.junit.jupiter.api.Assertions.assertThrows(
                org.springframework.dao.DataIntegrityViolationException.class,
                () -> jdbc.execute(
                        "INSERT INTO historical_events (id, slug, title, summary, status) "
                      + "VALUES (gen_random_uuid(), 'x', 't', 's', 'BOGUS')"));
    }
}
