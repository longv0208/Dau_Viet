package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandLayoutVersion;

import jakarta.persistence.LockModeType;

/**
 * Layout version catalog (V44).
 */
public interface IslandLayoutVersionRepository
        extends JpaRepository<IslandLayoutVersion, UUID> {

    @Query("SELECT v FROM IslandLayoutVersion v "
         + "WHERE v.definitionId = :definitionId AND v.status = 'PUBLISHED'")
    Optional<IslandLayoutVersion> findPublishedByDefinitionId(
            @Param("definitionId") UUID definitionId);

    @Query(value = """
            SELECT v.* FROM island_layout_versions v
            JOIN island_layout_definitions d ON d.id = v.definition_id
            WHERE d.layout_key = :layoutKey AND v.status = 'PUBLISHED'
            LIMIT 1
            """, nativeQuery = true)
    Optional<IslandLayoutVersion> findPublishedByLayoutKey(
            @Param("layoutKey") String layoutKey);

    @Query(value = """
            SELECT v.* FROM island_layout_versions v
            JOIN island_layout_definitions d ON d.id = v.definition_id
            WHERE d.is_default = true AND v.status = 'PUBLISHED'
            LIMIT 1
            """, nativeQuery = true)
    Optional<IslandLayoutVersion> findDefaultPublishedVersion();

    List<IslandLayoutVersion> findByDefinitionIdOrderByVersionNumberDesc(
            UUID definitionId);

    List<IslandLayoutVersion> findByDefinitionIdOrderByVersionNumberAsc(
            UUID definitionId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT v FROM IslandLayoutVersion v WHERE v.id = :id")
    Optional<IslandLayoutVersion> findLockedById(@Param("id") UUID id);

    boolean existsByDefinitionIdAndStatusIn(UUID definitionId, List<String> statuses);
}
