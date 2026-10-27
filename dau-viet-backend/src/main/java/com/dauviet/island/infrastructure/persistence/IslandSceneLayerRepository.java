package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandSceneLayer;

/**
 * Scene layers của layout (V44).
 */
public interface IslandSceneLayerRepository
        extends JpaRepository<IslandSceneLayer, UUID> {

    List<IslandSceneLayer> findByLayoutVersionIdOrderByRenderOrderAsc(
            UUID layoutVersionId);

    @Modifying
    @Query("DELETE FROM IslandSceneLayer l WHERE l.layoutVersionId = :versionId")
    void deleteByLayoutVersionId(@Param("versionId") UUID versionId);
}
