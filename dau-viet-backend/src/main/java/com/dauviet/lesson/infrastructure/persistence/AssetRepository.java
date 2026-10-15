package com.dauviet.lesson.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.lesson.domain.Asset;

public interface AssetRepository extends JpaRepository<Asset, UUID> {

    @Query("select a.id from Asset a where a.state = 'ACTIVE'")
    List<UUID> findActiveIds();

    boolean existsByIdAndState(UUID id, String state);
}
