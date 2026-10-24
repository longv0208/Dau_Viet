package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.EventDossier;

/**
 * Persistence cho event_dossiers (GAME-04). Quan hệ chính thức duy nhất
 * sinh unlock — fan-out theo unlock_on='EVENT_COMPLETED'.
 */
public interface EventDossierRepository
        extends JpaRepository<EventDossier, EventDossier.PK> {

    /** Dossier ids link tới event theo trigger EVENT_COMPLETED, sort ổn định. */
    @Query("select ed.dossierId from EventDossier ed "
         + "where ed.eventId = :eventId and ed.unlockOn = 'EVENT_COMPLETED' "
         + "order by ed.sortOrder asc, ed.dossierId asc")
    List<UUID> findEventCompletedDossierIds(@Param("eventId") UUID eventId);
}
