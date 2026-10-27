package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandSlot;

/**
 * Catalog ô đất của layout đảo (V32 + V44).
 */
public interface IslandSlotRepository extends JpaRepository<IslandSlot, UUID> {

    List<IslandSlot> findByLayoutCodeOrderBySlotIndex(String layoutCode);

    List<IslandSlot> findByLayoutVersionIdOrderBySlotIndex(UUID layoutVersionId);

    @Modifying
    @Query("DELETE FROM IslandSlot s WHERE s.layoutVersionId = :versionId")
    void deleteByLayoutVersionId(@Param("versionId") UUID versionId);
}
