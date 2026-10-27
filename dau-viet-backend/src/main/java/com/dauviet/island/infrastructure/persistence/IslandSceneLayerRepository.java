package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.island.domain.IslandSceneLayer;

/**
 * Scene layers của layout (V43) — read-only sau publish.
 */
public interface IslandSceneLayerRepository
        extends JpaRepository<IslandSceneLayer, UUID> {

    /**
     * Danh sách layers của một layout version, sắp theo render_order ASC.
     * Flutter render từng layer theo thứ tự này.
     */
    List<IslandSceneLayer> findByLayoutVersionIdOrderByRenderOrderAsc(
            UUID layoutVersionId);
}
