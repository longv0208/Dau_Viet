package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandTile;

/**
 * Ô địa hình của board tile-based (V48 ISLAND-09-BE).
 */
public interface IslandTileRepository extends JpaRepository<IslandTile, UUID> {

    List<IslandTile> findByLayoutVersionIdOrderByRowIndexAscColIndexAsc(
            UUID layoutVersionId);

    /** Kiểm tra tileId thuộc đúng version (chống tham chiếu chéo version). */
    boolean existsByIdAndLayoutVersionId(UUID id, UUID layoutVersionId);

    @Modifying
    @Query("DELETE FROM IslandTile t WHERE t.layoutVersionId = :versionId")
    void deleteByLayoutVersionId(@Param("versionId") UUID versionId);
}
