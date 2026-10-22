package com.dauviet.map.application;

import java.util.Collection;
import java.util.Set;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Server-authoritative unlock check (FR-37 MVP): a location's lesson is
 * unlocked when the learner owns >=1 COMPLETED attempt on ANY published
 * version of that lesson — republish does not reset history (TASK-0018/19).
 * One IN-list query for the whole map page — no N+1.
 */
@Component
public class MapLocationUnlockQuery {

    private final JdbcTemplate jdbc;

    public MapLocationUnlockQuery(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Returns the subset of `lessonIds` the learner has completed (any
     * pinned version). Empty input -> empty set, no query.
     */
    public Set<UUID> completedLessonIds(UUID userId, Collection<UUID> lessonIds) {
        if (lessonIds == null || lessonIds.isEmpty()) {
            return Set.of();
        }
        String placeholders = String.join(",",
                java.util.Collections.nCopies(lessonIds.size(), "?"));
        String sql = "select distinct v.lesson_id "
                + "from learner_attempts a "
                + "join lesson_versions v on v.id = a.lesson_version_id "
                + "where a.user_id = ? and a.status = 'COMPLETED' "
                + "and v.lesson_id in (" + placeholders + ")";
        Object[] args = new Object[lessonIds.size() + 1];
        args[0] = userId;
        int i = 1;
        for (UUID id : lessonIds) {
            args[i++] = id;
        }
        return new java.util.HashSet<>(
                jdbc.query(sql, (rs, n) -> rs.getObject(1, UUID.class), args));
    }
}
