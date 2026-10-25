package com.dauviet.collection.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.collection.domain.EventDossier;

/**
 * Persistence cho event_dossiers (GAME-04). Quan he chinh thuc duy nhat
 * sinh unlock — fan-out theo unlock_on='EVENT_COMPLETED'.
 */
public interface EventDossierRepository
        extends JpaRepository<EventDossier, EventDossier.PK> {

    /** Dossier ids link toi event theo trigger EVENT_COMPLETED, sort on dinh. */
    @Query("select ed.dossierId from EventDossier ed "
         + "where ed.eventId = :eventId and ed.unlockOn = 'EVENT_COMPLETED' "
         + "order by ed.sortOrder asc, ed.dossierId asc")
    List<UUID> findEventCompletedDossierIds(@Param("eventId") UUID eventId);

    /** Full link rows cua event, theo display order — admin link editor. */
    List<EventDossier> findByEventIdOrderBySortOrderAsc(UUID eventId);

    /** So event dang link toi dossier — summary badge trong admin list. */
    long countByDossierId(UUID dossierId);

    /** Tat ca event links cua dossier — admin detail view. */
    List<EventDossier> findByDossierIdOrderBySortOrderAsc(UUID dossierId);

    /** Xoa link cu khong con trong list thay the (PUT replace semantics). */
    void deleteByEventIdAndDossierIdIn(UUID eventId, List<UUID> dossierIds);
}
