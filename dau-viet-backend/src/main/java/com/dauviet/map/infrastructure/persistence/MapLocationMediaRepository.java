package com.dauviet.map.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.dauviet.map.domain.MapLocationMedia;

@Repository
public interface MapLocationMediaRepository extends JpaRepository<MapLocationMedia, UUID> {

    List<MapLocationMedia> findByLocationIdOrderBySortOrderAsc(UUID locationId);

    List<MapLocationMedia> findByLocationIdInOrderBySortOrderAsc(Collection<UUID> locationIds);

    @Modifying
    @Query("delete from MapLocationMedia m where m.locationId = :locationId")
    void deleteByLocationId(@Param("locationId") UUID locationId);
}
