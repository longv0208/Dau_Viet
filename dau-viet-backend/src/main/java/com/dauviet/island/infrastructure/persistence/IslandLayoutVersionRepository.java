package com.dauviet.island.infrastructure.persistence;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.island.domain.IslandLayoutVersion;

/**
 * Layout version catalog (V43). Tối đa 1 PUBLISHED version/definition tại
 * một thời điểm — đảm bảo bởi partial unique index ux_island_layout_version_published.
 */
public interface IslandLayoutVersionRepository
        extends JpaRepository<IslandLayoutVersion, UUID> {

    /**
     * Lấy version PUBLISHED của một definition. Dùng khi cần default version
     * để tạo đảo mới hoặc để Flutter fetch layout.
     */
    @Query("SELECT v FROM IslandLayoutVersion v "
         + "WHERE v.definitionId = :definitionId AND v.status = 'PUBLISHED'")
    Optional<IslandLayoutVersion> findPublishedByDefinitionId(
            @Param("definitionId") UUID definitionId);

    /**
     * Lấy version PUBLISHED của definition có layout_key cho sẵn.
     * Dùng để resolve 'heritage-village' → UUID version không cần hard-code UUID.
     */
    @Query(value = """
            SELECT v.* FROM island_layout_versions v
            JOIN island_layout_definitions d ON d.id = v.definition_id
            WHERE d.layout_key = :layoutKey AND v.status = 'PUBLISHED'
            LIMIT 1
            """, nativeQuery = true)
    Optional<IslandLayoutVersion> findPublishedByLayoutKey(
            @Param("layoutKey") String layoutKey);

    /** Tất cả version của một definition — dùng khi admin xem lịch sử. */
    List<IslandLayoutVersion> findByDefinitionIdOrderByVersionNumberAsc(
            UUID definitionId);
}
