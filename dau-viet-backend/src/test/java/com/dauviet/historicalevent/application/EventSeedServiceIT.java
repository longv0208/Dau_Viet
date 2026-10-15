package com.dauviet.historicalevent.application;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;

import com.dauviet.AbstractPostgresIT;
import com.dauviet.historicalevent.domain.EventStatus;
import com.dauviet.historicalevent.domain.HistoricalEvent;
import com.dauviet.historicalevent.infrastructure.persistence.HistoricalEventRepository;

import org.junit.jupiter.api.BeforeEach;

/**
 * Insert-only seed: first run inserts, second run is a no-op and must not
 * overwrite local edits made to the seeded row.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(EventSeedService.class)
class EventSeedServiceIT extends AbstractPostgresIT {

    @Autowired
    private EventSeedService seedService;

    @Autowired
    private HistoricalEventRepository repository;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbc;

    @BeforeEach
    void cleanTable() {
        // Other ITs on the shared container leave rows behind; isolate so
        // count() assertions stay deterministic. Clear authoring dependents
        // (lessons/evidences/assets) first so the events delete is FK-safe.
        clearAuthoringTables(jdbc);
        jdbc.update("delete from historical_events");
    }

    @Test
    void seedInsertsOnce_thenSecondRunIsNoop() {
        HistoricalEvent first = seedService.upsertBachDang();
        assertThat(repository.count()).isEqualTo(1);
        assertThat(first.getId()).isEqualTo(EventSeedService.BACH_DANG_ID);
        assertThat(first.getStatus()).isEqualTo(EventStatus.PUBLISHED);

        // Second run: no duplicate, same instance returned.
        HistoricalEvent second = seedService.upsertBachDang();
        assertThat(repository.count()).isEqualTo(1);
        assertThat(second.getId()).isEqualTo(first.getId());
    }

    @Test
    void seedDoesNotOverwriteLocalEdits() {
        seedService.upsertBachDang();

        // Developer edits the row locally, then the seed runs again — the edit
        // must be preserved because the seed is insert-only.
        HistoricalEvent e = repository.findBySlug(EventSeedService.BACH_DANG_SLUG).orElseThrow();
        e.setTitle("DEV EDITED TITLE");
        e.setSummary("locally modified summary");
        repository.save(e);

        HistoricalEvent after = seedService.upsertBachDang();
        assertThat(after.getTitle()).isEqualTo("DEV EDITED TITLE");
        assertThat(after.getSummary()).isEqualTo("locally modified summary");
        assertThat(repository.count()).isEqualTo(1);
    }
}
