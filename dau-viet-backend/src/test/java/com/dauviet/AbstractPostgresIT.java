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

    /** Test-only cleanup uses TRUNCATE so immutable rows need no trigger bypass.
     * Seeded island configuration remains intact; callers may then delete users/events. */
    protected static void clearAuthoringTables(org.springframework.jdbc.core.JdbcTemplate jdbc) {
        jdbc.execute("""
            TRUNCATE TABLE animation_scene_asset_refs, animation_scene_versions,
                animation_scenes, animation_templates, user_inventory, reward_transactions,
                energy_transactions, user_energy, user_learning_streak_days, user_learning_streaks,
                map_locations, user_island_placements, user_islands, wallet_transactions, wallet_accounts,
                user_dossier_unlocks, event_dossiers, user_event_progress, historical_dossier_versions,
                historical_dossiers, event_completion_policies, user_evidence, activity_attempts,
                lesson_results, idempotency_records, learner_attempts, learning_path_lesson_nodes,
                learning_path_event_nodes, learning_path_chapters, learning_path_versions,
                historical_event_canonical_aliases, lesson_versions, lessons, evidences CASCADE
            """);
        // TRUNCATE assets CASCADE would also erase item_catalog and seeded island shop config.
        jdbc.execute("""
            DO $$
            BEGIN
                IF to_regclass('public.user_location_unlocks') IS NOT NULL THEN
                    TRUNCATE TABLE user_location_unlocks, map_location_media, map_location_unlock_lessons, map_location_events CASCADE;
                END IF;
                IF to_regclass('public.user_path_period_state') IS NOT NULL THEN
                    TRUNCATE TABLE user_path_period_state CASCADE;
                END IF;
            END $$;
            """);
        jdbc.update("UPDATE item_catalog SET asset_id = NULL WHERE asset_id IS NOT NULL");
        jdbc.update("DELETE FROM assets");
    }
}
