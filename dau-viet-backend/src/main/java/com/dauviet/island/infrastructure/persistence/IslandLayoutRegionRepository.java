package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandLayoutRegion;

/**
 * Vùng đất của layout (V44).
 */
public interface IslandLayoutRegionRepository
        extends JpaRepository<IslandLayoutRegion, UUID> {

    List<IslandLayoutRegion> findByLayoutVersionIdOrderBySortOrderAsc(
            UUID layoutVersionId);

    @Modifying
    @Query("DELETE FROM IslandLayoutRegion r WHERE r.layoutVersionId = :versionId")
    void deleteByLayoutVersionId(@Param("versionId") UUID versionId);
}
