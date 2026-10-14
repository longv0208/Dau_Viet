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

/**
 * Idempotent seed must insert once and update on subsequent runs —
 * never duplicate rows.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(EventSeedService.class)
class EventSeedServiceIT extends AbstractPostgresIT {

    @Autowired
    private EventSeedService seedService;

    @Autowired
    private HistoricalEventRepository repository;

    @Test
    void seedInsertsOnce_thenUpdates() {
        seedService.upsertBachDang();
        seedService.upsertBachDang(); // second run must not duplicate

        assertThat(repository.findBySlug(EventSeedService.BACH_DANG_SLUG)).isPresent();
        assertThat(repository.count()).isEqualTo(1);

        HistoricalEvent e = repository.findBySlug(EventSeedService.BACH_DANG_SLUG).orElseThrow();
        assertThat(e.getId()).isEqualTo(EventSeedService.BACH_DANG_ID);
        assertThat(e.getStatus()).isEqualTo(EventStatus.PUBLISHED);
        assertThat(e.getStartYear()).isEqualTo(938);
        assertThat(e.getTags()).contains("ngo-quyen", "bach-dang");
    }
}
