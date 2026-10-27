package com.dauviet.map.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.map.domain.MapLocationEvent;

@Repository
public interface MapLocationEventRepository extends JpaRepository<MapLocationEvent, MapLocationEvent.Id> {

    List<MapLocationEvent> findByIdLocationIdInOrderBySortOrderAsc(Collection<UUID> locationIds);

    List<MapLocationEvent> findByIdLocationIdOrderBySortOrderAsc(UUID locationId);

    List<MapLocationEvent> findByIdEventId(UUID eventId);

    @Modifying
    @Query("delete from MapLocationEvent e where e.id.locationId = :locationId")
    void deleteByLocationId(@Param("locationId") UUID locationId);
}
