package com.dauviet.historicalevent.infrastructure.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class HistoricalEventRepositoryIT extends AbstractPostgresIT {

    @Autowired
    private HistoricalEventRepository repository;

    @Autowired
    private JdbcTemplate jdbc;

    @BeforeEach
    void cleanTable() {
        // Shared container: events left by other ITs would break count-based
        // assertions (e.g. findByStatus total). Clear dependents first.
        clearAuthoringTables(jdbc);
        jdbc.update("delete from historical_events");
    }

    private HistoricalEvent event(UUID id, String slug, EventStatus status) {
        HistoricalEvent e = new HistoricalEvent();
        e.setId(id);
        e.setSlug(slug);
        e.setTitle("t-" + slug);
        e.setSummary("s");
        e.setTags(List.of("x", "y"));
        e.setStatus(status);
        return e;
    }

    @Test
    void findByStatus_returnsOnlyPublished() {
        repository.save(event(UUID.randomUUID(), "pub", EventStatus.PUBLISHED));
        repository.save(event(UUID.randomUUID(), "draft", EventStatus.DRAFT));
        repository.save(event(UUID.randomUUID(), "arch", EventStatus.ARCHIVED));

        Page<HistoricalEvent> page = repository.findByStatus(EventStatus.PUBLISHED, PageRequest.of(0, 10));
        assertThat(page.getTotalElements()).isEqualTo(1);
        assertThat(page.getContent().get(0).getSlug()).isEqualTo("pub");
    }

    @Test
    void findByIdAndStatus_hidesDraft() {
        UUID id = UUID.randomUUID();
        repository.save(event(id, "hidden", EventStatus.DRAFT));
        Optional<HistoricalEvent> found = repository.findByIdAndStatus(id, EventStatus.PUBLISHED);
        assertThat(found).isEmpty();
    }

    @Test
    void tagsArrayRoundTrips() {
        UUID id = UUID.randomUUID();
        repository.save(event(id, "tags", EventStatus.PUBLISHED));
        HistoricalEvent loaded = repository.findById(id).orElseThrow();
        assertThat(loaded.getTags()).containsExactly("x", "y");
    }
}
