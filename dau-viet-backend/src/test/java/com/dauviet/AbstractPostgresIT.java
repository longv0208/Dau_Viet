package com.dauviet;

import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Shared Postgres container for all integration tests. One container per JVM
 * (started once via static init) so Spring test-context caching does not
 * collide with per-class container ports.
 */
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
public abstract class AbstractPostgresIT {

    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine")
                    .withDatabaseName("dauviet")
                    .withUsername("dauviet")
                    .withPassword("dauviet_dev");

    static {
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void overrideProps(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.flyway.enabled", () -> "true");
        registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
    }

    /**
     * Clear authoring tables (activity_attempts → learner_attempts →
     * lessons → evidences → assets) so ITs that wipe `users` or
     * `historical_events` do not hit FK violations from rows left behind by
     * the learning/lesson/evidence ITs. Bypasses the immutable
     * lesson_versions trigger + chk_lesson_published_version for cleanup only.
     * Call BEFORE users.deleteAll() / delete from historical_events.
     */
    protected static void clearAuthoringTables(
            org.springframework.jdbc.core.JdbcTemplate jdbc) {
        jdbc.update("set session_replication_role = replica");
        jdbc.update("delete from activity_attempts");
        jdbc.update("delete from learner_attempts");
        jdbc.update("update lessons set status = 'DRAFT', current_version_id = null");
        jdbc.update("delete from lesson_versions");
        jdbc.update("delete from lessons");
        jdbc.update("delete from evidences");
        jdbc.update("delete from assets");
        jdbc.update("set session_replication_role = origin");
    }
}
