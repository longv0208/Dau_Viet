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
        jdbc.update("delete from animation_scene_asset_refs");
        jdbc.update("delete from animation_scene_versions");
        jdbc.update("delete from animation_scenes");
        jdbc.update("delete from animation_templates");
        jdbc.update("delete from user_inventory");
        jdbc.update("delete from reward_transactions");
        // GAME-02: energy tables — xoá trước learner_attempts/users để FK
        // không chặn cleanup của IT khác khi nó wipe bảng users.
        jdbc.update("delete from energy_transactions");
        jdbc.update("delete from user_energy");
        // V31: streak tables — xoá trước learner_attempts/users để FK
        // user_learning_streaks_user_id_fkey / _days_learner_attempt_fkey
        // không chặn cleanup của IT khác khi nó wipe bảng users.
        jdbc.update("delete from user_learning_streak_days");
        jdbc.update("delete from user_learning_streaks");
        jdbc.update("delete from map_locations");
        // V32: island/wallet — user-scoped tables (placements FK tới users+inventory+slots,
        // user_islands/wallet FK tới users); xoá trước khi IT khác wipe users.
        // Chú ý: island_slots, island_shop_items, island_tier_policies là SEEDED config (V32),
        // KHÔNG xoá trong clearAuthoringTables để không làm hỏng fixture migration cho các IT chạy sau.
        jdbc.update("delete from user_island_placements");
        jdbc.update("delete from user_islands");
        jdbc.update("delete from wallet_transactions");
        jdbc.update("delete from wallet_accounts");
        // GAME-04/06: dossier/event-progress tables — trước users/events wipe.
        jdbc.update("delete from user_dossier_unlocks");
        jdbc.update("delete from event_dossiers");
        jdbc.update("delete from user_event_progress");
        // V28: version snapshots phai xoa truoc historical_dossiers.
        jdbc.update("delete from historical_dossier_versions");
        jdbc.update("delete from historical_dossiers");
        jdbc.update("delete from event_completion_policies");
        jdbc.update("delete from user_evidence");
        jdbc.update("delete from activity_attempts");
        jdbc.update("delete from lesson_results");
        jdbc.update("delete from idempotency_records");
        jdbc.update("delete from learner_attempts");
        jdbc.update("update lessons set status = 'DRAFT', current_version_id = null");
        jdbc.update("delete from lesson_versions");
        jdbc.update("delete from lessons");
        jdbc.update("delete from evidences");
        jdbc.update("delete from assets");
        jdbc.update("set session_replication_role = origin");
    }
}
