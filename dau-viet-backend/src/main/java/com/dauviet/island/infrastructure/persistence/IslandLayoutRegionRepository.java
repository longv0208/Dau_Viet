package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.island.domain.IslandLayoutRegion;

/**
 * Vùng đất của layout (V43) — read-only sau publish.
 */
public interface IslandLayoutRegionRepository
        extends JpaRepository<IslandLayoutRegion, UUID> {

    /**
     * Danh sách vùng của một layout version, sắp theo sort_order ASC.
     * Dùng để include trong IslandResponse để Flutter vẽ region overlay.
     */
    List<IslandLayoutRegion> findByLayoutVersionIdOrderBySortOrderAsc(
            UUID layoutVersionId);
}
