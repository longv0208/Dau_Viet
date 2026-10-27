package com.dauviet.path.application;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.dauviet.path.domain.LearningPathExceptions.PathValidationException;

/** Historical identity metadata is independent of path order and event IDs. */
@Component
public class PathEventIdentity {
    private final JdbcTemplate jdbc;

    public PathEventIdentity(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    public Map<UUID, UUID> aliases() {
        Map<UUID, UUID> aliases = new HashMap<>();
        jdbc.query("SELECT alias_event_id, canonical_event_id FROM historical_event_canonical_aliases",
                rs -> { aliases.put(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class)); });
        return aliases;
    }

    public UUID canonical(UUID eventId, Map<UUID, UUID> aliases) {
        Set<UUID> visited = new HashSet<>();
        UUID current = eventId;
        while (aliases.containsKey(current)) {
            if (!visited.add(current)) {
                throw new PathValidationException(java.util.List.of("Historical event alias cycle: " + eventId));
            }
            current = aliases.get(current);
        }
        return current;
    }
}
