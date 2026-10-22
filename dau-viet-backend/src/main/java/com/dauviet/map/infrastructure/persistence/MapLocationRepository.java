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

    /**
     * All PUBLISHED locations of PUBLISHED events — learner map surface.
     * Single query, no N+1 (event join filter only).
     */
    @Query("select m from MapLocation m, HistoricalEvent e "
         + "where m.eventId = e.id and e.status = 'PUBLISHED' "
         + "and m.status = :status order by m.displayOrder asc, m.title asc")
    List<MapLocation> findVisibleForLearner(@Param("status") MapLocationStatus status);

    @Query("select m from MapLocation m "
         + "where m.id = :id and m.status = :status "
         + "and m.eventId in (select e.id from HistoricalEvent e "
         + "                  where e.status = 'PUBLISHED')")
    Optional<MapLocation> findVisibleForLearnerById(
            @Param("id") UUID id, @Param("status") MapLocationStatus status);
}
