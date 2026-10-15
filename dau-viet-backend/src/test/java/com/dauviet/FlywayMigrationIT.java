package com.dauviet;

import static org.assertj.core.api.Assertions.assertThat;

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
              + "'lesson_results','user_evidence','reward_transactions')",
                Integer.class);
        assertThat(count).isEqualTo(13);
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

    @Test
    void checkConstraintRejectsInvalidStatus() {
        org.junit.jupiter.api.Assertions.assertThrows(
                org.springframework.dao.DataIntegrityViolationException.class,
                () -> jdbc.execute(
                        "INSERT INTO historical_events (id, slug, title, summary, status) "
                      + "VALUES (gen_random_uuid(), 'x', 't', 's', 'BOGUS')"));
    }
}
