package com.dauviet.lesson.infrastructure.persistence;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.lesson.domain.Asset;

public interface AssetRepository extends JpaRepository<Asset, UUID> {

    @Query("select a.id from Asset a where a.state = 'ACTIVE'")
    List<UUID> findActiveIds();

    boolean existsByIdAndState(UUID id, String state);

    Page<Asset> findAllByStateIn(Collection<String> states, Pageable pageable);

    @Query("""
            SELECT a FROM Asset a
            WHERE a.state IN :states
              AND (:qPattern IS NULL
                   OR LOWER(COALESCE(a.originalFilename, '')) LIKE :qPattern
                   OR LOWER(COALESCE(a.altText, '')) LIKE :qPattern)
            """)
    Page<Asset> searchActive(
            @Param("states") Collection<String> states,
            @Param("qPattern") String qPattern,
            Pageable pageable);

    @Query(value = """
            SELECT (
                EXISTS (
                    SELECT 1
                    FROM island_scene_layers isl
                    JOIN island_layout_versions ilv ON ilv.id = isl.layout_version_id
                    WHERE isl.asset_ref IN (
                        CAST(:assetId AS text),
                        CONCAT('/api/v1/assets/', CAST(:assetId AS text), '/content'),
                        CONCAT('/api/v1/admin/assets/', CAST(:assetId AS text), '/content')
                    )
                      AND (
                          ilv.status = 'PUBLISHED'
                          OR (
                              ilv.status = 'ARCHIVED'
                              AND EXISTS (
                                  SELECT 1
                                  FROM user_islands ui
                                  WHERE ui.user_id = :userId
                                    AND ui.layout_version_id = ilv.id
                              )
                          )
                      )
                )
                OR EXISTS (
                    SELECT 1
                    FROM item_catalog ic
                    WHERE ic.asset_id = :assetId
                      AND (
                          ic.active = TRUE
                          OR EXISTS (
                              SELECT 1
                              FROM user_inventory uinv
                              WHERE uinv.item_id = ic.id
                                AND uinv.user_id = :userId
                          )
                          OR EXISTS (
                              SELECT 1
                              FROM user_island_placements uip
                              WHERE uip.item_id = ic.id
                                AND uip.user_id = :userId
                          )
                      )
                )
                OR EXISTS (
                    SELECT 1
                    FROM lessons l
                    WHERE l.cover_asset_id = :assetId
                      AND l.status = 'PUBLISHED'
                )
                OR EXISTS (
                    SELECT 1
                    FROM lesson_versions lv
                    WHERE CAST(lv.snapshot_json AS text) LIKE CONCAT('%', CAST(:assetId AS text), '%')
                      AND (
                          EXISTS (
                              SELECT 1
                              FROM lessons l
                              WHERE l.id = lv.lesson_id
                                AND l.status = 'PUBLISHED'
                          )
                          OR EXISTS (
                              SELECT 1
                              FROM learner_attempts la
                              WHERE la.lesson_version_id = lv.id
                                AND la.user_id = :userId
                          )
                      )
                )
                OR EXISTS (
                    SELECT 1
                    FROM animation_scene_asset_refs asar
                    WHERE asar.asset_id = :assetId
                )
                OR EXISTS (
                    SELECT 1
                    FROM animation_templates atpl
                    WHERE atpl.thumbnail_asset_id = :assetId
                      AND atpl.enabled = TRUE
                )
                OR EXISTS (
                    SELECT 1
                    FROM evidences ev
                    WHERE ev.asset_id = :assetId
                      AND ev.status = 'APPROVED'
                )
                OR EXISTS (
                    SELECT 1
                    FROM user_evidence ue
                    WHERE ue.user_id = :userId
                      AND ue.snapshot_json IS NOT NULL
                      AND CAST(ue.snapshot_json AS text) LIKE CONCAT('%', CAST(:assetId AS text), '%')
                )
                OR EXISTS (
                    SELECT 1
                    FROM historical_dossiers hd
                    WHERE hd.asset_id = :assetId
                      AND hd.status = 'PUBLISHED'
                )
                OR EXISTS (
                    SELECT 1
                    FROM historical_dossier_versions hdv
                    WHERE hdv.asset_id = :assetId
                      AND hdv.status = 'PUBLISHED'
                )
                OR EXISTS (
                    SELECT 1
                    FROM map_locations ml
                    WHERE ml.cover_asset_id = :assetId
                      AND ml.status = 'PUBLISHED'
                )
                OR EXISTS (
                    SELECT 1
                    FROM map_location_media mlm
                    JOIN map_locations ml ON ml.id = mlm.location_id
                    WHERE mlm.asset_id = :assetId
                      AND ml.status = 'PUBLISHED'
                      AND mlm.visibility IN ('PUBLIC', 'UNLOCKED_ONLY')
                )
            )
            """, nativeQuery = true)
    boolean isAccessibleToLearner(
            @Param("assetId") UUID assetId,
            @Param("userId") UUID userId);
}
