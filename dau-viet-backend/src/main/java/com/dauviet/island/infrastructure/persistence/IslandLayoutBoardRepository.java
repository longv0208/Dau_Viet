package com.dauviet.island.infrastructure.persistence;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandLayoutBoard;

/**
 * Board config 1:1 với layout version (V48 ISLAND-09-BE).
 * PK = layout_version_id — findById(versionId) trả board hoặc empty (legacy).
 */
public interface IslandLayoutBoardRepository
        extends JpaRepository<IslandLayoutBoard, UUID> {

    @Modifying
    @Query("DELETE FROM IslandLayoutBoard b WHERE b.layoutVersionId = :versionId")
    void deleteByLayoutVersionId(@Param("versionId") UUID versionId);
}
