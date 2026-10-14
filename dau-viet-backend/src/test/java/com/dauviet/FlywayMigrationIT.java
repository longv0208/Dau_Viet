package com.dauviet;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Verifies Flyway V1 applies cleanly on a fresh Postgres and the
 * flyway_schema_history table records it. Requires Docker.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class FlywayMigrationIT extends AbstractPostgresIT {

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void flywayV1Applied() {
        Integer count = jdbc.queryForObject(
                "SELECT count(*) FROM flyway_schema_history WHERE version = '1' AND success",
                Integer.class);
        assertThat(count).isEqualTo(1);
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
