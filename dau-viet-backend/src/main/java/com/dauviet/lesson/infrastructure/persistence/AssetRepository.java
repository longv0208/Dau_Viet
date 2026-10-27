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
}
