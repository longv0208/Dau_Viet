package com.dauviet.map.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.map.domain.MapLocation;
import com.dauviet.map.domain.MapLocationStatus;

@Repository
public interface MapLocationRepository extends JpaRepository<MapLocation, UUID> {

    List<MapLocation> findByEventIdOrderByDisplayOrderAscTitleAsc(UUID eventId);

    Optional<MapLocation> findByIdAndEventId(UUID id, UUID eventId);

    Optional<MapLocation> findBySlug(String slug);

    @Query("select m from MapLocation m order by m.displayOrder asc, m.title asc")
    List<MapLocation> findAllOrderedForAdmin();

    @Query("select m from MapLocation m left join HistoricalEvent e on m.eventId = e.id "
         + "where m.status = :status "
         + "and ((m.eventId is not null and e.status = 'PUBLISHED') "
         + "  or (m.eventId is null and ("
         + "        not exists (select 1 from MapLocationEvent mle where mle.id.locationId = m.id) "
         + "     or exists (select 1 from MapLocationEvent mle, HistoricalEvent he "
         + "                where mle.id.locationId = m.id and mle.id.eventId = he.id and he.status = 'PUBLISHED')"
         + "  ))) "
         + "order by coalesce(e.startYear, 0) asc, m.displayOrder asc, m.title asc")
    List<MapLocation> findVisibleForLearner(@Param("status") MapLocationStatus status);

    @Query("select m from MapLocation m left join HistoricalEvent e on m.eventId = e.id "
         + "where m.id = :id and m.status = :status "
         + "and ((m.eventId is not null and e.status = 'PUBLISHED') "
         + "  or (m.eventId is null and ("
         + "        not exists (select 1 from MapLocationEvent mle where mle.id.locationId = m.id) "
         + "     or exists (select 1 from MapLocationEvent mle, HistoricalEvent he "
         + "                where mle.id.locationId = m.id and mle.id.eventId = he.id and he.status = 'PUBLISHED')"
         + "  )))")
    Optional<MapLocation> findVisibleForLearnerById(
            @Param("id") UUID id, @Param("status") MapLocationStatus status);
}
